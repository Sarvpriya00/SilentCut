import Foundation
import Observation

/// Coordinates a background batch queue for processing multiple media files concurrently or sequentially.
/// Uses `@Observable` and `@MainActor` to safely publish task progress and queue statuses.
@Observable
@MainActor
public final class AnalysisQueueManager {
    /// List of tasks currently registered in the manager queue.
    public private(set) var tasks: [QueueTask] = []
    
    /// True if the manager is actively processing a task in the background.
    public private(set) var isProcessing = false
    
    private let analyzer = AudioAnalyzer()
    private let detector = SilenceDetector()
    
    public init() {}
    
    /// Enqueues a video file for batch background processing.
    public func enqueue(video: VideoFile) {
        guard !tasks.contains(where: { $0.video.id == video.id }) else { return }
        tasks.append(QueueTask(video: video))
        processNextIfNeeded()
    }
    
    /// Clears any finished or failed tasks from the active queue logs.
    public func clearCompleted() {
        tasks.removeAll { $0.status == .completed || $0.status == .failed }
    }
    
    /// Removes a specific task from the queue list.
    public func removeTask(withId id: UUID) {
        tasks.removeAll { $0.id == id }
    }
    
    /// Triggers processing of the next pending task in the sequence.
    private func processNextIfNeeded() {
        guard !isProcessing else { return }
        
        guard let nextIdx = tasks.firstIndex(where: { $0.status == .pending }) else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        tasks[nextIdx].status = .analyzing
        let task = tasks[nextIdx]
        
        let fileURL = task.video.url
        let duration = task.video.duration
        
        // Detached background task for heavy file decoding and math operations
        Task {
            do {
                _ = try await Task.detached(priority: .medium) { [analyzer, detector] in
                    let samples = try await analyzer.extractAudioSamples(from: fileURL, targetSampleRate: 44100.0)
                    let rms = detector.computeRMS(samples: samples, sampleRate: 44100.0)
                    let detected = detector.detectSilence(rmsValues: rms, thresholdDB: -35.0, minSilenceDuration: 0.5)
                    let merged = detector.mergeRegions(detected, gapThreshold: 0.25)
                    let padded = detector.padRegions(merged, padding: 0.1, maxDuration: duration)
                    let keeps = detector.convertToKeepSegments(from: padded, totalDuration: duration)
                    return (rms: rms, silences: padded, keeps: keeps)
                }.value
                
                // Dispatch successes back onto the MainActor
                await MainActor.run {
                    if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[index].status = .completed
                        self.tasks[index].progress = 1.0
                    }
                    self.isProcessing = false
                    self.processNextIfNeeded()
                }
            } catch {
                // Dispatch failures back onto the MainActor
                await MainActor.run {
                    if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[index].status = .failed
                        self.tasks[index].errorDescription = error.localizedDescription
                    }
                    self.isProcessing = false
                    self.processNextIfNeeded()
                }
            }
        }
    }
}
