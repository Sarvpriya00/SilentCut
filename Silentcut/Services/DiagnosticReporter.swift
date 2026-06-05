import Foundation

/// Statistics and warnings report produced by the Verification System before exporting.
public struct DiagnosticReport: Sendable, Codable, Hashable {
    public let timestamp: Date
    public let filename: String
    public let issues: [String]
    public let isSuccess: Bool
    
    public let totalCutsCount: Int
    public let originalDuration: Double
    public let removedDuration: Double
    public let finalDuration: Double
}

/// Service that runs timeline validation rules to verify cut boundaries, detect overlapping clips, and generate reports.
public struct DiagnosticReporter: Sendable {
    public init() {}
    
    /// Validates keep segments and silences against video bounds and checks for overlaps.
    /// - Parameters:
    ///   - video: The source video file.
    ///   - keepSegments: The keep segments timeline list.
    ///   - silenceRegions: The silence regions cut list.
    /// - Returns: A complete `DiagnosticReport` containing issues and duration statistics.
    public func runDiagnostics(
        video: VideoFile,
        keepSegments: [KeepSegment],
        silenceRegions: [SilenceRegion]
    ) -> DiagnosticReport {
        var issues: [String] = []
        
        // 1. Check for empty timelines
        if keepSegments.isEmpty {
            issues.append("Timeline Warning: The timeline is empty. Ensure threshold parameters are not too high.")
        }
        
        // 2. Validate keep segments boundary constraints & overlap checks
        var lastTimelineEnd = 0.0
        for segment in keepSegments {
            if segment.start < 0.0 {
                issues.append("Boundary Error: Segment starts before zero (\(segment.start)s).")
            }
            if segment.end > video.duration + 0.01 { // allow minor floating-point tolerances
                issues.append("Boundary Error: Segment end (\(segment.end)s) exceeds video duration (\(video.duration)s).")
            }
            if segment.start >= segment.end {
                issues.append("Duration Error: Segment is empty (start: \(segment.start)s, end: \(segment.end)s).")
            }
            if segment.start < lastTimelineEnd - 0.01 {
                issues.append("Overlap Error: Overlapping clip detected starting at \(segment.start)s (previous end: \(lastTimelineEnd)s).")
            }
            lastTimelineEnd = segment.end
        }
        
        // 3. Validate silence regions boundary constraints
        for silence in silenceRegions {
            if silence.start < 0.0 || silence.end > video.duration + 0.01 || silence.start >= silence.end {
                issues.append("Silence Error: Malformed silence region detected (start: \(silence.start)s, end: \(silence.end)s).")
            }
        }
        
        let originalDuration = video.duration
        let finalDuration = keepSegments.reduce(0.0) { $0 + $1.duration }
        let removedDuration = max(0.0, originalDuration - finalDuration)
        
        return DiagnosticReport(
            timestamp: Date(),
            filename: video.filename,
            issues: issues,
            isSuccess: issues.isEmpty,
            totalCutsCount: silenceRegions.count,
            originalDuration: originalDuration,
            removedDuration: removedDuration,
            finalDuration: finalDuration
        )
    }
}
