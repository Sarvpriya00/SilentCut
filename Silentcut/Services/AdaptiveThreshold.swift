import Foundation

/// Service for calculating the loudness distribution of audio tracks and recommending thresholds.
public struct AdaptiveThreshold: Sendable {
    public init() {}
    
    /// Recommends an optimal decibel threshold by estimating the recording's noise floor.
    /// - Parameter rmsValues: The computed decibels array.
    /// - Returns: A suggested threshold in decibels (dB).
    public func estimateThreshold(rmsValues: [Float]) -> Float {
        // Fallback default if empty
        guard !rmsValues.isEmpty else { return -35.0 }
        
        // Filter out extreme values (e.g., values below -80 dB representing absolute digital mute)
        let activeRMS = rmsValues.filter { $0 > -80.0 }
        guard !activeRMS.isEmpty else { return -35.0 }
        
        let sorted = activeRMS.sorted()
        
        // Estimate the background noise floor at the 15th percentile of the recording
        let noiseFloorIndex = Int(Double(sorted.count) * 0.15)
        let noiseFloor = sorted[noiseFloorIndex]
        
        // Recommend threshold 8 dB above the estimated noise floor to protect quiet vocal endings
        let suggested = noiseFloor + 8.0
        
        // Clamp within standard dialogue margins (-48 dB to -22 dB)
        return max(-48.0, min(-22.0, suggested))
    }
}
