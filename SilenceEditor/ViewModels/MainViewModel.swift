import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Core View Model managing the primary application workspace.
/// Coordinates imports, selection states, drag and drop hover statuses, and handles errors.
@Observable
@MainActor
public final class MainViewModel {
    // MARK: - Services
    private let importService = VideoImportService()
    public let projectManager = ProjectManager()
    private let xmlGenerator = FCPXMLGenerator()
    
    // MARK: - UI State
    /// Currently selected video for detailing in the Inspector
    public var selectedVideo: VideoFile? {
        didSet {
            clearAnalysis()
        }
    }
    
    /// Active state representing whether a background load/import operation is in progress
    public var isImporting = false
    
    /// Tracks if a file is currently hovering over the drag-and-drop zone
    public var isHovering = false
    
    /// Formatted error string for presentation in the UI error banner
    public var activeError: String?
    
    // MARK: - Analysis Parameters (Stages 4-7)
    /// Decibel threshold below which audio is considered silent
    public var thresholdDB: Float = -35.0
    
    /// Minimum duration in seconds to consider an interval as silent
    public var minSilenceDuration: Double = 0.5
    
    /// Padding duration in seconds to shrink silence regions at boundaries
    public var paddingDuration: Double = 0.1
    
    /// True if an audio analysis is currently running
    public var isAnalyzing = false
    
    // MARK: - Analysis Results (Stages 4-7)
    /// Calculated decibel levels for every 50ms chunk of the video
    public var rmsValues: [Float] = []
    
    /// Final padded silence regions to cut
    public var silenceRegions: [SilenceRegion] = []
    
    /// Inverse keeps list representing the timeline blueprint
    public var keepSegments: [KeepSegment] = []
    
    // MARK: - Computed Properties
    /// Fetches the reactive array of imported videos from the project manager
    public var importedVideos: [VideoFile] {
        projectManager.importedVideos
    }
    
    public init() {}
    
    // MARK: - Actions
    
    /// Initiates importing of a video file from a given system URL.
    /// Runs on the MainActor, triggering loading states and publishing errors.
    public func importVideo(from url: URL) {
        isImporting = true
        activeError = nil
        
        Task {
            do {
                let video = try await importService.importVideo(from: url)
                projectManager.addVideo(video)
                
                // Automatically select the newly imported video
                selectedVideo = video
            } catch let error as LocalizedError {
                activeError = error.errorDescription ?? error.localizedDescription
            } catch {
                activeError = "An unexpected error occurred: \(error.localizedDescription)"
            }
            isImporting = false
        }
    }
    
    /// Processes drag-and-drop event providers, extracting URL references for video formats.
    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Drag-and-drop URL type identifier
        let fileTypeIdentifier = UTType.fileURL.identifier
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(fileTypeIdentifier) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                    guard let url = url, error == nil else { return }
                    
                    // Dispatch the import action back onto the MainActor
                    Task { @MainActor in
                        self?.importVideo(from: url)
                    }
                }
                return true
            }
        }
        return false
    }
    
    /// Displays a native macOS open panel for manual file imports.
    public func triggerManualImport() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Import Video File"
        openPanel.prompt = "Import"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            importVideo(from: url)
        }
    }
    
    /// Clear the current error banner
    public func dismissError() {
        activeError = nil
    }
    
    /// Exports the timeline keep segments as an FCPXML document using NSSavePanel.
    public func exportFCPXML() {
        guard let video = selectedVideo else { return }
        guard !keepSegments.isEmpty else {
            activeError = "No keep segments found. Please run silence analysis first."
            return
        }
        
        do {
            let xmlString = try xmlGenerator.generateFCPXML(for: video, keepSegments: keepSegments)
            
            let savePanel = NSSavePanel()
            if let fcpxmlType = UTType(filenameExtension: "fcpxml") {
                savePanel.allowedContentTypes = [fcpxmlType]
            } else {
                savePanel.allowedContentTypes = [.xml]
            }
            
            let baseName = (video.filename as NSString).deletingPathExtension
            savePanel.nameFieldStringValue = "\(baseName)_cut.fcpxml"
            savePanel.title = "Export Timeline to Final Cut Pro"
            savePanel.prompt = "Export"
            
            if savePanel.runModal() == .OK, let targetURL = savePanel.url {
                try xmlString.write(to: targetURL, atomically: true, encoding: .utf8)
            }
        } catch let error as LocalizedError {
            activeError = error.errorDescription ?? error.localizedDescription
        } catch {
            activeError = "Failed to export FCPXML: \(error.localizedDescription)"
        }
    }
    
    /// Clears any cached analysis outputs
    public func clearAnalysis() {
        rmsValues = []
        silenceRegions = []
        keepSegments = []
    }
    
    /// Removes a video file from the workspace, clearing the inspector selection if matching.
    public func deleteVideo(_ video: VideoFile) {
        if selectedVideo == video {
            selectedVideo = nil
        }
        projectManager.removeVideo(withId: video.id)
    }
    
    /// Triggers the full audio reading and silence detection processing pipeline.
    /// Runs parsing in a detached task to avoid blocking the main UI thread.
    public func runSilenceAnalysis() {
        guard let video = selectedVideo else { return }
        
        isAnalyzing = true
        activeError = nil
        clearAnalysis()
        
        // Capture parameter constants to pass safely to the detached background task
        let fileURL = video.url
        let totalDuration = video.duration
        let threshold = thresholdDB
        let minDuration = minSilenceDuration
        let padding = paddingDuration
        
        Task {
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    let analyzer = AudioAnalyzer()
                    let detector = SilenceDetector()
                    
                    // 1. Extract audio samples (Mono 44.1 kHz 32-bit Float PCM)
                    let samples = try await analyzer.extractAudioSamples(from: fileURL, targetSampleRate: 44100.0)
                    
                    // 2. Perform RMS calculation (50ms chunks)
                    let rms = detector.computeRMS(samples: samples, sampleRate: 44100.0, chunkSizeMs: 50.0)
                    
                    // 3. Flag silence chunks below decibel threshold
                    let detected = detector.detectSilence(rmsValues: rms, thresholdDB: threshold, minSilenceDuration: minDuration, chunkSizeMs: 50.0)
                    
                    // 4. Merge silences close to each other (gap < 250ms)
                    let merged = detector.mergeRegions(detected, gapThreshold: 0.25)
                    
                    // 5. Pad silences (shrink silence boundaries by padding)
                    let padded = detector.padRegions(merged, padding: padding, maxDuration: totalDuration)
                    
                    // 6. Convert to Keep Segments (timeline blueprint)
                    let keeps = detector.convertToKeepSegments(from: padded, totalDuration: totalDuration)
                    
                    return (rms: rms, silences: padded, keeps: keeps)
                }.value
                
                // Update MainActor state variables
                self.rmsValues = results.rms
                self.silenceRegions = results.silences
                self.keepSegments = results.keeps
            } catch let error as LocalizedError {
                self.activeError = error.errorDescription ?? error.localizedDescription
            } catch {
                self.activeError = "An unexpected error occurred during audio analysis: \(error.localizedDescription)"
            }
            self.isAnalyzing = false
        }
    }
}
