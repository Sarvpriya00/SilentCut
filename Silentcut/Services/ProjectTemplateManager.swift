import Foundation

/// Defines the workspace recovery state elements for JSON serialization.
public struct AutosaveState: Codable, Sendable {
    public let importedVideoURLs: [URL]
    public let selectedVideoURL: URL?
    public let thresholdDB: Float
    public let minSilenceDuration: Double
    public let paddingDuration: Double
    public let mergeGapThreshold: Double
    public let timestamp: Date
}

/// Service for auto-saving and restoring workspace states, preventing data loss during crashes.
public struct ProjectTemplateManager: Sendable {
    public init() {}
    
    /// Returns the target URL of the JSON autosave file in Application Support
    private var autosaveURL: URL {
        let fm = FileManager.default
        let paths = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("SilenceEditor", isDirectory: true)
        // Ensure application support subfolder is created
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("autosave.json")
    }
    
    /// Writes the active workspace state atomically to disk.
    public func saveState(_ state: AutosaveState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: autosaveURL, options: .atomic)
        } catch {
            NSLog("SilenceEditor: Autosave failed: \(error.localizedDescription)")
        }
    }
    
    /// Reads and decodes the saved workspace state, if present.
    public func loadState() -> AutosaveState? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: autosaveURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: autosaveURL)
            return try JSONDecoder().decode(AutosaveState.self, from: data)
        } catch {
            NSLog("SilenceEditor: Failed to load autosave state: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deletes the autosave record (e.g. when clearing the project cleanly).
    public func clearAutosave() {
        try? FileManager.default.removeItem(at: autosaveURL)
    }
}
