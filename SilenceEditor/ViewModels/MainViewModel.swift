import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers
import AVFoundation

/// Core View Model managing the primary application workspace.
/// Coordinates imports, selection states, drag and drop hover statuses, and handles errors.
@Observable
@MainActor
public final class MainViewModel {
    // MARK: - Services
    private let importService = VideoImportService()
    public let projectManager = ProjectManager()
    private let exportEngine = ExportEngine()
    private let templateManager = ProjectTemplateManager()
    private let auditionHelper = AudioAuditionHelper()
    public let queueManager = AnalysisQueueManager()
    
    // MARK: - UI State
    /// Currently selected video for detailing in the Inspector
    public var selectedVideo: VideoFile? {
        didSet {
            clearAnalysis()
            triggerAutosave()
        }
    }
    
    /// Bridged player instance from the Viewer for context auditioning (Stage 9)
    public var player: AVPlayer?
    
    /// Active state representing whether a background load/import operation is in progress
    public var isImporting = false
    
    /// Tracks if a file is currently hovering over the drag-and-drop zone
    public var isHovering = false
    
    /// Formatted error string for presentation in the UI error banner
    public var activeError: String?
    
    // MARK: - Analysis Parameters (Stages 4-7, 10)
    /// Decibel threshold below which audio is considered silent
    public var thresholdDB: Float = -35.0 {
        didSet { triggerAutosave() }
    }
    
    /// Minimum duration in seconds to consider an interval as silent
    public var minSilenceDuration: Double = 0.5 {
        didSet { triggerAutosave() }
    }
    
    /// Padding duration in seconds to shrink silence regions at boundaries
    public var paddingDuration: Double = 0.1 {
        didSet { triggerAutosave() }
    }
    
    /// Merge gap distance threshold under which close silences will be merged (Stage 10)
    public var mergeGapThreshold: Double = 0.25 {
        didSet { triggerAutosave() }
    }
    
    /// Currently active dialogue editing preset (Stage 10)
    public var selectedPreset: EditingPreset = .podcast {
        didSet {
            applyPreset(selectedPreset)
        }
    }
    
    /// Currently active timeline formatting mode (Cut Silence or Split at Silence)
    public var timelineMode: TimelineMode = .cutSilence {
        didSet {
            triggerAutosave()
            if !rmsValues.isEmpty {
                runSilenceAnalysis()
            }
        }
    }
    
    /// True if an audio analysis is currently running
    public var isAnalyzing = false
    
    // MARK: - Export Configuration (Stage 12)
    /// Non-Linear Editor target format for export (FCP, Premiere, Resolve)
    public var exportTarget: ExportTarget = .finalCutPro
    
    /// Historical list of previous timeline exports
    public var exportHistory: [ExportRecord] = []
    
    /// Active diagnostics validation verification report (Stage 12)
    public var activeReport: DiagnosticReport?
    
    // MARK: - Cache System (Stage 11)
    /// In-memory cache for storing calculated decibel arrays by source file URLs
    private var rmsCache: [URL: [Float]] = [:]
    
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
    
    // MARK: - Initialization & Autosave Recovery (Stage 11)
    public init() {
        // Attempt crash recovery / autosave loading
        if let state = templateManager.loadState() {
            self.thresholdDB = state.thresholdDB
            self.minSilenceDuration = state.minSilenceDuration
            self.paddingDuration = state.paddingDuration
            self.mergeGapThreshold = state.mergeGapThreshold
            self.timelineMode = state.timelineMode ?? .cutSilence
            
            // Re-import files from recovery URLs
            for url in state.importedVideoURLs {
                self.importVideo(from: url, autoSelect: url == state.selectedVideoURL)
            }
        }
    }
    
    /// Saves the current workspace settings and imports to Application Support
    public func triggerAutosave() {
        let state = AutosaveState(
            importedVideoURLs: projectManager.importedVideos.map { $0.fileURL },
            selectedVideoURL: selectedVideo?.fileURL,
            thresholdDB: thresholdDB,
            minSilenceDuration: minSilenceDuration,
            paddingDuration: paddingDuration,
            mergeGapThreshold: mergeGapThreshold,
            timelineMode: timelineMode,
            timestamp: Date()
        )
        templateManager.saveState(state)
    }
    
    // MARK: - Actions
    
    /// Initiates importing of a video file from a given system URL.
    /// Runs on the MainActor, triggering loading states and publishing errors.
    public func importVideo(from url: URL, autoSelect: Bool = true) {
        isImporting = true
        activeError = nil
        
        Task {
            do {
                let video = try await importService.importVideo(from: url)
                projectManager.addVideo(video)
                
                if autoSelect {
                    selectedVideo = video
                }
                triggerAutosave()
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
        let fileTypeIdentifier = UTType.fileURL.identifier
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(fileTypeIdentifier) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                    guard let url = url, error == nil else { return }
                    
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
    
    /// Clears any cached analysis outputs
    public func clearAnalysis() {
        rmsValues = []
        silenceRegions = []
        keepSegments = []
        activeReport = nil
    }
    
    /// Removes a video file from the workspace, clearing the inspector selection if matching.
    public func deleteVideo(_ video: VideoFile) {
        if selectedVideo == video {
            selectedVideo = nil
        }
        projectManager.removeVideo(withId: video.id)
        triggerAutosave()
    }
    
    // MARK: - Presets & Auditions (Stage 9-10)
    
    /// Applies values of the selected presets to parameter configurations
    public func applyPreset(_ preset: EditingPreset) {
        guard preset != .custom else { return }
        self.thresholdDB = preset.defaultThresholdDB
        self.minSilenceDuration = preset.defaultMinSilenceDuration
        self.paddingDuration = preset.defaultPaddingDuration
        self.mergeGapThreshold = preset.defaultMergeGapThreshold
        
        triggerAutosave()
        
        // Re-run the silence analysis automatically if file decibels are already loaded
        if !rmsValues.isEmpty {
            runSilenceAnalysis()
        }
    }
    
    /// Contextually auditions a selected silence cut region by playing surrounding audio
    public func auditionSilence(_ silence: SilenceRegion, player: AVPlayer) {
        guard let video = selectedVideo else { return }
        auditionHelper.audition(silence: silence, in: player, videoDuration: video.duration)
    }
    
    /// Automatically estimates and applies an optimal threshold based on noise floor (Stage 9)
    public func applyAdaptiveThreshold() {
        guard !rmsValues.isEmpty else { return }
        let estimator = AdaptiveThreshold()
        self.thresholdDB = estimator.estimateThreshold(rmsValues: rmsValues)
        self.selectedPreset = .custom
        runSilenceAnalysis()
    }
    
    // MARK: - Analysis & Export (Stage 11-12)
    
    /// Triggers the full audio reading and silence detection processing pipeline.
    /// Runs parsing in a detached task to avoid blocking the main UI thread.
    public func runSilenceAnalysis() {
        guard let video = selectedVideo else { return }
        
        isAnalyzing = true
        activeError = nil
        
        let fileURL = video.url
        let totalDuration = video.duration
        let threshold = thresholdDB
        let minDuration = minSilenceDuration
        let padding = paddingDuration
        let mode = timelineMode
        
        // Check if decibel levels are cached in-memory
        let cachedRMS = rmsCache[fileURL]
        
        Task {
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    let analyzer = AudioAnalyzer()
                    let detector = SilenceDetector()
                    
                    // 1. Fetch from cache or extract audio samples
                    let rms: [Float]
                    if let cached = cachedRMS {
                        rms = cached
                    } else {
                        let samples = try await analyzer.extractAudioSamples(from: fileURL, targetSampleRate: 44100.0)
                        rms = detector.computeRMS(samples: samples, sampleRate: 44100.0, chunkSizeMs: 50.0)
                    }
                    
                    // 2. Flags silences below threshold
                    let detected = detector.detectSilence(rmsValues: rms, thresholdDB: threshold, minSilenceDuration: minDuration, chunkSizeMs: 50.0)
                    
                    // 3. Merges silences separated by gaps < mergeGap
                    let merged = detector.mergeRegions(detected, gapThreshold: mergeGap)
                    
                    // 4. Pads silences by shrinking boundaries
                    let padded = detector.padRegions(merged, padding: padding, maxDuration: totalDuration)
                    
                    // 5. Converts to keep segments timeline
                    let keeps = detector.convertToKeepSegments(from: padded, totalDuration: totalDuration)
                    
                    let finalSegments: [KeepSegment]
                    if mode == .splitSilence {
                        // Combine keep segments with mapped silence regions as contiguous clips
                        let silenceSegments = padded.map { KeepSegment(start: $0.start, end: $0.end) }
                        finalSegments = (keeps + silenceSegments).sorted { $0.start < $1.start }
                    } else {
                        finalSegments = keeps
                    }
                    
                    return (rms: rms, silences: padded, keeps: finalSegments)
                }.value
                
                // Cache computed decibels if not already cached
                if cachedRMS == nil {
                    self.rmsCache[fileURL] = results.rms
                }
                
                // Publish results to MainActor
                self.rmsValues = results.rms
                self.silenceRegions = results.silences
                self.keepSegments = results.keeps
                
                // Run verification diagnostics report (Stage 12)
                let reporter = DiagnosticReporter()
                self.activeReport = reporter.runDiagnostics(video: video, keepSegments: results.keeps, silenceRegions: results.silences)
                
                triggerAutosave()
            } catch let error as LocalizedError {
                self.activeError = error.errorDescription ?? error.localizedDescription
            } catch {
                self.activeError = "An unexpected error occurred during audio analysis: \(error.localizedDescription)"
            }
            self.isAnalyzing = false
        }
    }
    
    /// Exports the timeline keep segments using the active ExportTarget (FCPX, Premiere, Resolve).
    /// Performs diagnostics verification before triggering the save panel.
    public func exportTimeline() {
        guard let video = selectedVideo else { return }
        guard !keepSegments.isEmpty else {
            activeError = "No keep segments found. Please run silence analysis first."
            return
        }
        
        do {
            // Run verification diagnostics checks (Stage 12)
            let reporter = DiagnosticReporter()
            let report = reporter.runDiagnostics(video: video, keepSegments: keepSegments, silenceRegions: silenceRegions)
            self.activeReport = report
            
            // Abort export if critical errors are present
            if report.issues.contains(where: { $0.contains("Error") }) {
                activeError = "Timeline validation failed. Check diagnostics report for errors."
                return
            }
            
            // Compile XML according to the target NLE formatting abstraction layer (Stage 12)
            let xmlString = try exportEngine.generateTimelineXML(for: video, keepSegments: keepSegments, target: exportTarget)
            
            let savePanel = NSSavePanel()
            let extensionName: String
            switch exportTarget {
            case .finalCutPro, .davinciResolve:
                extensionName = "fcpxml"
            case .premierePro:
                extensionName = "xml"
            }
            
            if let type = UTType(filenameExtension: extensionName) {
                savePanel.allowedContentTypes = [type]
            } else {
                savePanel.allowedContentTypes = [.xml]
            }
            
            let baseName = (video.filename as NSString).deletingPathExtension
            savePanel.nameFieldStringValue = "\(baseName)_cut.\(extensionName)"
            savePanel.title = "Export Timeline for \(exportTarget.rawValue)"
            savePanel.prompt = "Export"
            
            if savePanel.runModal() == .OK, let targetURL = savePanel.url {
                try xmlString.write(to: targetURL, atomically: true, encoding: .utf8)
                
                // Add to export history logs (Stage 11)
                let record = ExportRecord(
                    filename: video.filename,
                    videoURL: video.fileURL,
                    fcpxmlURL: targetURL,
                    presetUsed: selectedPreset.rawValue,
                    silenceCount: silenceRegions.count,
                    keepDuration: keepSegments.reduce(0.0) { $0 + $1.duration }
                )
                self.exportHistory.append(record)
            }
        } catch let error as LocalizedError {
            activeError = error.errorDescription ?? error.localizedDescription
        } catch {
            activeError = "Failed to export timeline: \(error.localizedDescription)"
        }
    }
}
