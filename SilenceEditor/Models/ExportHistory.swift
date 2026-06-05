import Foundation

/// Represents a historical record of an XML export action.
/// Used by the Export Manager to track previous projects and configurations.
public struct ExportRecord: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let filename: String
    public let videoURL: URL
    public let fcpxmlURL: URL
    public let presetUsed: String
    public let silenceCount: Int
    public let keepDuration: Double
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        filename: String,
        videoURL: URL,
        fcpxmlURL: URL,
        presetUsed: String,
        silenceCount: Int,
        keepDuration: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.filename = filename
        self.videoURL = videoURL
        self.fcpxmlURL = fcpxmlURL
        self.presetUsed = presetUsed
        self.silenceCount = silenceCount
        self.keepDuration = keepDuration
    }
}
