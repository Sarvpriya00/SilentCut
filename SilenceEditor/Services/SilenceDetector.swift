import Foundation
import Accelerate

/// Represents a detected interval of silence within a video's audio track.
public struct SilenceRegion: Sendable, Identifiable, Hashable, Equatable {
    public let id: UUID
    public let start: Double
    public let end: Double
    
    public var duration: Double {
        end - start
    }
    
    public init(id: UUID = UUID(), start: Double, end: Double) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// Represents a timeline segment of audio/video content that should be kept (non-silent).
public struct KeepSegment: Sendable, Identifiable, Hashable, Equatable {
    public let id: UUID
    public let start: Double
    public let end: Double
    
    public var duration: Double {
        end - start
    }
    
    public init(id: UUID = UUID(), start: Double, end: Double) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// Protocol defining the interface for processing RMS decibels and identifying silences.
public protocol SilenceDetectorProtocol: Sendable {
    /// Computes decibel values for successive chunks of audio samples.
    func computeRMS(samples: [Float], sampleRate: Double, chunkSizeMs: Double) -> [Float]
    
    /// Flags contiguous silent intervals that are below the threshold.
    func detectSilence(rmsValues: [Float], thresholdDB: Float, minSilenceDuration: Double, chunkSizeMs: Double) -> [SilenceRegion]
    
    /// Combines silent chunks separated by small sound fluctuations.
    func mergeRegions(_ regions: [SilenceRegion], gapThreshold: Double) -> [SilenceRegion]
    
    /// Shrinks the silent boundaries to preserve speech margins.
    func padRegions(_ regions: [SilenceRegion], padding: Double, maxDuration: Double) -> [SilenceRegion]
    
    /// Translates silence cuts into keeping intervals.
    func convertToKeepSegments(from silenceRegions: [SilenceRegion], totalDuration: Double) -> [KeepSegment]
}

/// SilenceDetector implementation computing audio chunk RMS levels and filtering silence intervals.
public struct SilenceDetector: SilenceDetectorProtocol, Sendable {
    public init() {}
    
    /// Computes Root Mean Square (RMS) decibel values for audio samples in consecutive chunks.
    public func computeRMS(samples: [Float], sampleRate: Double, chunkSizeMs: Double = 50.0) -> [Float] {
        guard !samples.isEmpty && sampleRate > 0 else { return [] }
        
        let chunkSize = Int((sampleRate * chunkSizeMs) / 1000.0)
        guard chunkSize > 0 else { return [] }
        
        let totalSamples = samples.count
        var rmsValues: [Float] = []
        
        // Loop through samples and calculate RMS for each chunk using Accelerate
        for start in stride(from: 0, to: totalSamples, by: chunkSize) {
            let end = min(start + chunkSize, totalSamples)
            let currentChunkSize = end - start
            guard currentChunkSize > 0 else { break }
            
            var rms: Float = 0
            samples.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    vDSP_rmsqv(baseAddress + start, 1, &rms, vDSP_Length(currentChunkSize))
                }
            }
            
            // Convert to decibels (dB), clamping floor to avoid log10(0)
            let db = rms > 0.00001 ? 20.0 * log10(rms) : -100.0
            rmsValues.append(db)
        }
        
        return rmsValues
    }
    
    /// Detects silent intervals where RMS dB values remain below the threshold for at least the specified duration.
    public func detectSilence(
        rmsValues: [Float],
        thresholdDB: Float,
        minSilenceDuration: Double,
        chunkSizeMs: Double = 50.0
    ) -> [SilenceRegion] {
        guard !rmsValues.isEmpty else { return [] }
        
        let chunkDuration = chunkSizeMs / 1000.0
        var silenceRegions: [SilenceRegion] = []
        var activeSilenceStart: Int? = nil
        
        for (index, db) in rmsValues.enumerated() {
            let isSilent = db < thresholdDB
            
            if isSilent {
                if activeSilenceStart == nil {
                    activeSilenceStart = index
                }
            } else {
                if let startIdx = activeSilenceStart {
                    let duration = Double(index - startIdx) * chunkDuration
                    if duration >= minSilenceDuration {
                        silenceRegions.append(SilenceRegion(
                            start: Double(startIdx) * chunkDuration,
                            end: Double(index) * chunkDuration
                        ))
                    }
                    activeSilenceStart = nil
                }
            }
        }
        
        // Handle trailing silence region at end of samples
        if let startIdx = activeSilenceStart {
            let duration = Double(rmsValues.count - startIdx) * chunkDuration
            if duration >= minSilenceDuration {
                silenceRegions.append(SilenceRegion(
                    start: Double(startIdx) * chunkDuration,
                    end: Double(rmsValues.count) * chunkDuration
                ))
            }
        }
        
        return silenceRegions
    }
    
    /// Merges silence regions that are separated by a gap shorter than the gapThreshold.
    public func mergeRegions(_ regions: [SilenceRegion], gapThreshold: Double = 0.25) -> [SilenceRegion] {
        guard !regions.isEmpty else { return [] }
        
        // Ensure regions are sorted chronologically
        let sorted = regions.sorted { $0.start < $1.start }
        var merged: [SilenceRegion] = [sorted[0]]
        
        for i in 1..<sorted.count {
            let current = sorted[i]
            let lastMergedIdx = merged.count - 1
            let last = merged[lastMergedIdx]
            
            let gap = current.start - last.end
            if gap <= gapThreshold {
                // Combine overlapping/close regions
                let newEnd = max(last.end, current.end)
                merged[lastMergedIdx] = SilenceRegion(id: last.id, start: last.start, end: newEnd)
            } else {
                merged.append(current)
            }
        }
        
        return merged
    }
    
    /// Applies padding to shrink silence regions, ensuring word boundaries are not clipped.
    public func padRegions(_ regions: [SilenceRegion], padding: Double = 0.1, maxDuration: Double) -> [SilenceRegion] {
        var padded: [SilenceRegion] = []
        
        for region in regions {
            // Shrink the silence region at both ends to create buffer padding for keep zones
            let newStart = max(0.0, region.start + padding)
            let newEnd = min(maxDuration, region.end - padding)
            
            // Only preserve if the silence is still longer than the sum of padding bounds
            if newStart < newEnd {
                padded.append(SilenceRegion(id: region.id, start: newStart, end: newEnd))
            }
        }
        
        return padded
    }
    
    /// Inverts silence regions to produce keep segments representing the active audio track timeline blueprint.
    public func convertToKeepSegments(from silenceRegions: [SilenceRegion], totalDuration: Double) -> [KeepSegment] {
        var keepSegments: [KeepSegment] = []
        let sortedSilences = silenceRegions.sorted { $0.start < $1.start }
        
        var currentTime = 0.0
        for silence in sortedSilences {
            if silence.start > currentTime {
                keepSegments.append(KeepSegment(start: currentTime, end: silence.start))
            }
            currentTime = max(currentTime, silence.end)
        }
        
        if currentTime < totalDuration {
            keepSegments.append(KeepSegment(start: currentTime, end: totalDuration))
        }
        
        return keepSegments
    }
}
