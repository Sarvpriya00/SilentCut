import Foundation
import AVFoundation

/// Errors encountered during the video file import process.
public enum VideoImportError: LocalizedError, Sendable {
    case fileDoesNotExist
    case unsupportedFormat(extension: String)
    case missingTracks
    case missingVideoTrack
    case avFoundationFailure(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileDoesNotExist:
            return "The selected file could not be found or does not exist."
        case .unsupportedFormat(let ext):
            return "Unsupported file format (.\(ext)). Please import a .mov, .mp4, or .m4v file."
        case .missingTracks:
            return "No media tracks were found in the selected file."
        case .missingVideoTrack:
            return "The selected file does not contain a valid video track."
        case .avFoundationFailure(let message):
            return "AVFoundation failed to load file metadata: \(message)"
        }
    }
}

/// Service class responsible for importing, validating, and extracting metadata from video files.
public struct VideoImportService: Sendable {
    public init() {}
    
    /// Imports a video file from a given local URL and builds a VideoFile model.
    /// - Parameter url: The URL pointing to the video file on the system.
    /// - Returns: A populated `VideoFile` instance containing loaded metadata.
    public func importVideo(from url: URL) async throws -> VideoFile {
        // 1. Validate that the file actually exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoImportError.fileDoesNotExist
        }
        
        // 2. Validate supported file extensions
        let pathExtension = url.pathExtension.lowercased()
        let supportedExtensions = ["mp4", "mov", "m4v"]
        guard supportedExtensions.contains(pathExtension) else {
            throw VideoImportError.unsupportedFormat(extension: pathExtension)
        }
        
        // 3. Create the AVURLAsset
        let asset = AVURLAsset(url: url)
        
        do {
            // Load key properties asynchronously using modern Swift 6 async API
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            // Check that the asset contains tracks
            guard !tracks.isEmpty else {
                throw VideoImportError.missingTracks
            }
            
            // Categorize tracks into video and audio
            let videoTracks = tracks.filter { $0.mediaType == .video }
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            
            // Ensure there is at least one video track to work with
            guard let primaryVideoTrack = videoTracks.first else {
                throw VideoImportError.missingVideoTrack
            }
            
            let videoTrackCount = videoTracks.count
            let audioTrackCount = audioTracks.count
            
            // Load specific track metadata asynchronously
            let frameRate = Double(try await primaryVideoTrack.load(.nominalFrameRate))
            let resolution = try await primaryVideoTrack.load(.naturalSize)
            
            // Load file properties from the filesystem
            var fileSize: Int64 = 0
            var creationDate: Date? = nil
            
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]) {
                fileSize = Int64(resourceValues.fileSize ?? 0)
                creationDate = resourceValues.creationDate
            }
            
            let durationInSeconds = duration.seconds
            let filename = url.lastPathComponent
            
            return VideoFile(
                fileURL: url,
                filename: filename,
                duration: durationInSeconds,
                frameRate: frameRate,
                resolution: resolution,
                audioTrackCount: audioTrackCount,
                videoTrackCount: videoTrackCount,
                fileSize: fileSize,
                creationDate: creationDate
            )
        } catch let error as VideoImportError {
            throw error
        } catch {
            throw VideoImportError.avFoundationFailure(error.localizedDescription)
        }
    }
}
