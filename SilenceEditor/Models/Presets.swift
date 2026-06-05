import Foundation

/// Defines standard predefined configurations optimized for specific recording and speaking situations.
public enum EditingPreset: String, CaseIterable, Identifiable, Sendable {
    case podcast = "Podcast"
    case interview = "Interview"
    case youtube = "YouTube Talking Head"
    case course = "Course Recording"
    case voiceover = "Voice Over"
    case custom = "Custom"
    
    public var id: String { rawValue }
    
    /// Default decibel threshold below which audio is treated as silent
    public var defaultThresholdDB: Float {
        switch self {
        case .podcast: return -32.0
        case .interview: return -35.0
        case .youtube: return -30.0
        case .course: return -28.0
        case .voiceover: return -38.0
        case .custom: return -35.0
        }
    }
    
    /// Default duration threshold (seconds) for flagging silences
    public var defaultMinSilenceDuration: Double {
        switch self {
        case .podcast: return 0.6
        case .interview: return 0.5
        case .youtube: return 0.4
        case .course: return 0.8
        case .voiceover: return 0.3
        case .custom: return 0.5
        }
    }
    
    /// Default boundary padding duration (seconds) to shrink silence zones
    public var defaultPaddingDuration: Double {
        switch self {
        case .podcast: return 0.15
        case .interview: return 0.20
        case .youtube: return 0.10
        case .course: return 0.25
        case .voiceover: return 0.08
        case .custom: return 0.10
        }
    }
    
    /// Default maximum gap duration (seconds) under which close silences will be merged
    public var defaultMergeGapThreshold: Double {
        switch self {
        case .podcast: return 0.30
        case .interview: return 0.40
        case .youtube: return 0.20
        case .course: return 0.50
        case .voiceover: return 0.15
        case .custom: return 0.25
        }
    }
}
