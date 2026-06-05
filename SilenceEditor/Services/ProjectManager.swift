import Foundation
import Observation

/// Manages the state of the active editing project.
/// Tracks imported media assets and handles placeholders for project serialization.
@Observable
@MainActor
public final class ProjectManager {
    /// A collection of all videos currently imported into the project workspace.
    public private(set) var importedVideos: [VideoFile] = []
    
    public init() {}
    
    /// Imports a unique video model into the project index.
    /// Prevents adding duplicate file paths.
    public func addVideo(_ video: VideoFile) {
        if !importedVideos.contains(where: { $0.fileURL == video.fileURL }) {
            importedVideos.append(video)
        }
    }
    
    /// Removes a video file from the project index by its unique ID.
    public func removeVideo(withId id: UUID) {
        importedVideos.removeAll { $0.id == id }
    }
    
    /// Placeholder service hook to handle project state persistence (e.g. saving editing states).
    public func saveProject() async throws {
        // TODO: Stage 2 - Implement project state serialization to local project files
    }
    
    /// Placeholder service hook to load a saved project file.
    public func loadProject(from url: URL) async throws {
        // TODO: Stage 2 - Implement project loading and file validation
    }
}
