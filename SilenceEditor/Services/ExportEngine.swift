import Foundation

/// Supported Target Non-Linear Editors (NLEs) for export.
public enum ExportTarget: String, CaseIterable, Identifiable, Sendable {
    case finalCutPro = "Final Cut Pro (FCPXML)"
    case premierePro = "Premiere Pro (FCP 7 XML)"
    case davinciResolve = "DaVinci Resolve (FCPXML)"
    
    public var id: String { rawValue }
}

public protocol ExportEngineProtocol: Sendable {
    func generateTimelineXML(
        for video: VideoFile,
        keepSegments: [KeepSegment],
        target: ExportTarget
    ) throws -> String
}

/// Dynamic XML compiler supporting multiple professional editing formats (FCPXML, FCP 7 XML).
public struct ExportEngine: ExportEngineProtocol, Sendable {
    private let fcpxmlGenerator = FCPXMLGenerator()
    
    public init() {}
    
    public func generateTimelineXML(
        for video: VideoFile,
        keepSegments: [KeepSegment],
        target: ExportTarget
    ) throws -> String {
        switch target {
        case .finalCutPro, .davinciResolve:
            // FCP and Resolve both natively import FCPXML v1.9 timelines
            return try fcpxmlGenerator.generateFCPXML(for: video, keepSegments: keepSegments)
            
        case .premierePro:
            // Premiere requires classic flat FCP 7 XML formats mapping integer frames
            return try generateFCP7XML(for: video, keepSegments: keepSegments)
        }
    }
    
    // MARK: - Premiere FCP 7 XML Compilation Helper
    
    private func generateFCP7XML(for video: VideoFile, keepSegments: [KeepSegment]) throws -> String {
        let fps = video.frameRate > 0 ? video.frameRate : 30.0
        let timebase = Int(round(fps))
        
        let escapedFilename = Self.escapeXML(video.filename)
        // pathurl needs to be local file URL syntax (e.g. file://localhost/path/to/file)
        let escapedPath = Self.escapeXML(video.url.absoluteString)
        
        // Build video clip items (FCP 7 XML uses exact integer frame indices)
        var clipItemsXML = ""
        var currentTimelineFrame = 0
        
        for (index, segment) in keepSegments.enumerated() {
            let startFrame = Int(round(segment.start * fps))
            let endFrame = Int(round(segment.end * fps))
            let durationFrames = endFrame - startFrame
            
            guard durationFrames > 0 else { continue }
            
            let clipId = "clipitem-\(index + 1)"
            let endTimelineFrame = currentTimelineFrame + durationFrames
            
            clipItemsXML += """
                                    <clipitem id="\(clipId)">
                                        <name>\(escapedFilename)</name>
                                        <duration>\(Int(round(video.duration * fps)))</duration>
                                        <rate>
                                            <timebase>\(timebase)</timebase>
                                            <ntsc>FALSE</ntsc>
                                        </rate>
                                        <in>\(startFrame)</in>
                                        <out>\(endFrame)</out>
                                        <start>\(currentTimelineFrame)</start>
                                        <end>\(endTimelineFrame)</end>
                                        <file id="file-1">
                                            <name>\(escapedFilename)</name>
                                            <pathurl>\(escapedPath)</pathurl>
                                        </file>
                                    </clipitem>\n
            """
            
            currentTimelineFrame = endTimelineFrame
        }
        
        if !clipItemsXML.isEmpty {
            clipItemsXML.removeLast()
        }
        
        let projectName = Self.escapeXML("Cuts_\(video.filename)")
        
        let fcp7xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE xmeml>
        <xmeml version="5">
            <project>
                <name>\(projectName)</name>
                <children>
                    <sequence id="sequence-1">
                        <name>SilenceEditor Timeline</name>
                        <duration>\(currentTimelineFrame)</duration>
                        <rate>
                            <timebase>\(timebase)</timebase>
                            <ntsc>FALSE</ntsc>
                        </rate>
                        <media>
                            <video>
                                <track>
        \(clipItemsXML)
                                </track>
                            </video>
                            <audio>
                                <track>
                                    <!-- Embedded audio channels link directly to primary video asset clips -->
        \(clipItemsXML)
                                </track>
                            </audio>
                        </media>
                    </sequence>
                </children>
            </project>
        </xmeml>
        """
        
        return fcp7xml
    }
    
    // MARK: - XML Escaping Utility
    
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
