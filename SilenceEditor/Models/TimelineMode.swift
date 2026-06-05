import Foundation

/// Represents the formatting style of the generated timeline.
public enum TimelineMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case cutSilence = "Cut Silence"
    case splitSilence = "Split at Silence"
    
    public var id: String { rawValue }
}
