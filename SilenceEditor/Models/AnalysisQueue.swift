import Foundation

/// State representation of a task inside the background analysis queue.
public enum QueueTaskStatus: String, Sendable, Codable {
    case pending = "Pending"
    case analyzing = "Analyzing"
    case completed = "Completed"
    case failed = "Failed"
}

/// A queued item in the concurrent batch analysis manager.
public struct QueueTask: Identifiable, Sendable, Hashable, Equatable {
    public let id: UUID
    public let video: VideoFile
    public var status: QueueTaskStatus
    public var progress: Double
    public var errorDescription: String?
    
    public init(
        id: UUID = UUID(),
        video: VideoFile,
        status: QueueTaskStatus = .pending,
        progress: Double = 0.0,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.video = video
        self.status = status
        self.progress = progress
        self.errorDescription = errorDescription
    }
    
    public static func == (lhs: QueueTask, rhs: QueueTask) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
