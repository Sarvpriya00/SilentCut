import Foundation
import CoreGraphics

/// Represents a video file imported into the SilenceEditor workspace.
/// Conforms to `Identifiable`, `Sendable`, and `Hashable` for safe multi-threaded processing.
public struct VideoFile: Identifiable, Sendable, Hashable, Equatable {
    /// Unique identifier for the imported video record
    public let id: UUID
    
    /// Local file URL of the video
    public let fileURL: URL
    
    /// Convenience property mapping to the video file URL (Stage 2)
    public var url: URL { fileURL }
    
    /// User-friendly name of the file
    public let filename: String
    
    /// Duration of the track in seconds
    public let duration: TimeInterval
    
    /// Nominal frame rate (frames per second) of the video
    public let frameRate: Double
    
    /// Dimension width and height in pixels
    public let resolution: CGSize
    
    /// Number of audio tracks discovered
    public let audioTrackCount: Int
    
    /// Number of video tracks discovered
    public let videoTrackCount: Int
    
    /// File size on disk in bytes
    public let fileSize: Int64
    
    /// Optional metadata extraction creation date
    public let creationDate: Date?
    
    public init(
        id: UUID = UUID(),
        fileURL: URL,
        filename: String,
        duration: TimeInterval,
        frameRate: Double,
        resolution: CGSize,
        audioTrackCount: Int,
        videoTrackCount: Int,
        fileSize: Int64,
        creationDate: Date? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.filename = filename
        self.duration = duration
        self.frameRate = frameRate
        self.resolution = resolution
        self.audioTrackCount = audioTrackCount
        self.videoTrackCount = videoTrackCount
        self.fileSize = fileSize
        self.creationDate = creationDate
    }
    
    // Hashable conformance based on unique ID
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - UI Formatting Helpers
extension VideoFile {
    /// Returns the duration in standard 00:00:00 visual format
    public var formattedDuration: String {
        Formatters.formatDuration(duration)
    }
    
    /// Returns the file size formatted using standard units (e.g. 2.4 GB)
    public var formattedFileSize: String {
        Formatters.formatFileSize(fileSize)
    }
    
    /// Returns the frame rate string (e.g. 29.97 fps)
    public var formattedFrameRate: String {
        Formatters.formatFrameRate(frameRate)
    }
    
    /// Returns resolution formatted as W × H (e.g. 1920 × 1080)
    public var formattedResolution: String {
        Formatters.formatResolution(width: resolution.width, height: resolution.height)
    }
    
    /// Returns the date formatted based on target settings
    public var formattedCreationDate: String {
        guard let creationDate else { return "Unknown Date" }
        return Formatters.formatDate(creationDate)
    }
}
