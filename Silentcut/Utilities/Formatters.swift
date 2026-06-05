import Foundation

public enum Formatters {
    /// Formats a time interval into an editor-friendly hours:minutes:seconds representation (00:00:00)
    public static func formatDuration(_ duration: TimeInterval) -> String {
        guard !duration.isNaN && duration.isFinite else { return "00:00:00" }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// Formats file size in bytes to a human-readable string (e.g. 2.4 GB, 45.2 MB)
    public static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Formats video frame rates to 2 decimal places with 'fps' units
    public static func formatFrameRate(_ fps: Double) -> String {
        guard !fps.isNaN && fps.isFinite && fps > 0 else { return "-- fps" }
        return String(format: "%.2f fps", fps)
    }
    
    /// Formats width and height into a clean resolution string (e.g., 3840 × 2160)
    public static func formatResolution(width: Double, height: Double) -> String {
        guard width > 0 && height > 0 else { return "-- × --" }
        return "\(Int(width)) × \(Int(height))"
    }
    
    /// Formats file dates using localized settings
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
