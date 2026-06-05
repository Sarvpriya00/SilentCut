import Foundation

/// Errors encountered during FCPXML generation.
public enum FCPXMLGeneratorError: LocalizedError, Sendable {
    case emptySegments
    
    public var errorDescription: String? {
        switch self {
        case .emptySegments:
            return "No keep segments available to generate an FCPXML timeline."
        }
    }
}

/// Protocol defining the interface for generating FCPXML timelines representing non-silent cuts.
public protocol FCPXMLGeneratorProtocol: Sendable {
    /// Generates an FCPXML timeline string for a video file, using the provided keep segments.
    /// - Parameters:
    ///   - video: The source video file.
    ///   - keepSegments: The segments of the video that are kept.
    /// - Returns: A string representation of the FCPXML document.
    func generateFCPXML(
        for video: VideoFile,
        keepSegments: [KeepSegment]
    ) throws -> String
}

/// Service for generating Final Cut Pro XML (FCPXML v1.9) timelines representing stitched keep segments.
public struct FCPXMLGenerator: FCPXMLGeneratorProtocol, Sendable {
    public init() {}
    
    public func generateFCPXML(
        for video: VideoFile,
        keepSegments: [KeepSegment]
    ) throws -> String {
        guard !keepSegments.isEmpty else {
            throw FCPXMLGeneratorError.emptySegments
        }
        
        let rationalFps = Self.rationalFrameDuration(for: video.frameRate)
        let escapedFilename = Self.escapeXML(video.filename)
        let escapedUrl = Self.escapeXML(video.url.absoluteString)
        let videoDurationStr = String(format: "%.4fs", video.duration)
        
        // Build Spine clips (each keep segment becomes an asset-clip aligned to frame boundaries)
        var spineClips = ""
        var currentOffset = 0.0
        
        for segment in keepSegments {
            // Snap start and end points to exact frame boundaries of target FPS
            let snappedStart = Self.snapToFrameBoundary(time: segment.start, fps: video.frameRate)
            let snappedEnd = Self.snapToFrameBoundary(time: segment.end, fps: video.frameRate)
            let snappedDuration = snappedEnd - snappedStart
            
            // Skip invalid or empty intervals after snapping adjustments
            guard snappedDuration > 0 else { continue }
            
            let offsetStr = String(format: "%.4fs", currentOffset)
            let startStr = String(format: "%.4fs", snappedStart)
            let durationStr = String(format: "%.4fs", snappedDuration)
            
            spineClips += """
                                    <asset-clip ref="r2" offset="\(offsetStr)" name="\(escapedFilename)" start="\(startStr)" duration="\(durationStr)" tcFormat="NDF"/>\n
            """
            currentOffset += snappedDuration
        }
        
        // Trim trailing newline
        if !spineClips.isEmpty {
            spineClips.removeLast()
        }
        
        let totalKeepDurationStr = String(format: "%.4fs", currentOffset)
        let escapedProjectName = Self.escapeXML("Cut_\(video.filename)")
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.9">
            <resources>
                <format id="r1" name="FFVideoFormatCustom" frameDuration="\(rationalFps)"/>
                <asset id="r2" name="\(escapedFilename)" format="r1" start="0s" duration="\(videoDurationStr)" hasVideo="1" hasAudio="1">
                    <media-rep src="\(escapedUrl)" kind="original-media"/>
                </asset>
            </resources>
            <library>
                <event name="SilenceEditor Cuts">
                    <project name="\(escapedProjectName)">
                        <sequence duration="\(totalKeepDurationStr)" format="r1" tcStart="0s" tcFormat="NDF">
                            <spine>
        \(spineClips)
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        
        return xml
    }
    
    // MARK: - Utility Helpers
    
    private static func snapToFrameBoundary(time: Double, fps: Double) -> Double {
        let frameDuration: Double
        let eps = 0.05
        if abs(fps - 23.976) < eps || abs(fps - 23.98) < eps {
            frameDuration = 1001.0 / 24000.0
        } else if abs(fps - 29.97) < eps {
            frameDuration = 1001.0 / 30000.0
        } else if abs(fps - 59.94) < eps {
            frameDuration = 1001.0 / 60000.0
        } else {
            frameDuration = 1.0 / (fps > 0 ? fps : 30.0)
        }
        
        let frameCount = round(time / frameDuration)
        return frameCount * frameDuration
    }
    
    private static func rationalFrameDuration(for fps: Double) -> String {
        let eps = 0.05
        if abs(fps - 23.976) < eps || abs(fps - 23.98) < eps {
            return "1001/24000s"
        } else if abs(fps - 24.0) < eps {
            return "1/24s"
        } else if abs(fps - 25.0) < eps {
            return "1/25s"
        } else if abs(fps - 29.97) < eps {
            return "1001/30000s"
        } else if abs(fps - 30.0) < eps {
            return "1/30s"
        } else if abs(fps - 50.0) < eps {
            return "1/50s"
        } else if abs(fps - 59.94) < eps {
            return "1001/60000s"
        } else if abs(fps - 60.0) < eps {
            return "1/60s"
        } else {
            // Fallback for custom frame rates: round to nearest integer
            let roundedFps = Int(round(fps))
            let finalFps = roundedFps > 0 ? roundedFps : 30
            return "1/\(finalFps)s"
        }
    }
    
    private static func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
