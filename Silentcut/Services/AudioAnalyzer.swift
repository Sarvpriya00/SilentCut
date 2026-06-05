import Foundation
import AVFoundation

/// Errors related to audio analysis operations.
public enum AudioAnalyzerError: LocalizedError, Sendable {
    case noAudioTrack
    case failedToInitializeReader(String)
    case readingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio tracks were found in the selected file."
        case .failedToInitializeReader(let msg):
            return "Failed to initialize AVAssetReader: \(msg)"
        case .readingFailed(let msg):
            return "Failed to extract audio track samples: \(msg)"
        }
    }
}

/// Protocol defining the interface for extracting audio structures from video resources.
public protocol AudioAnalyzerProtocol: Sendable {
    /// Extracts PCM samples from a video's primary audio track as a flat Float array.
    /// - Parameters:
    ///   - url: The file URL of the video file.
    ///   - targetSampleRate: The target sample rate (e.g. 44100.0).
    /// - Returns: A flat array of 32-bit floating point PCM values.
    func extractAudioSamples(from url: URL, targetSampleRate: Double) async throws -> [Float]
}

/// AudioAnalyzer implementation using AVAssetReader to process and extract PCM float values.
public struct AudioAnalyzer: AudioAnalyzerProtocol, Sendable {
    public init() {}
    
    public func extractAudioSamples(from url: URL, targetSampleRate: Double = 44100.0) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        
        // Find the first audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioAnalyzerError.noAudioTrack
        }
        
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioAnalyzerError.failedToInitializeReader(error.localizedDescription)
        }
        
        // Configure standard output format: Linear PCM mono 32-bit float
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1 // Automatic downmix to mono channel
        ]
        
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        if reader.canAdd(trackOutput) {
            reader.add(trackOutput)
        } else {
            throw AudioAnalyzerError.failedToInitializeReader("Unable to add track output target to reader.")
        }
        
        guard reader.startReading() else {
            let errorMsg = reader.error?.localizedDescription ?? "Failed to start reading sample buffers."
            throw AudioAnalyzerError.failedToInitializeReader(errorMsg)
        }
        
        var samples: [Float] = []
        
        // Loop through buffer frames and copy linear PCM float data
        while reader.status == .reading {
            guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else { break }
            
            var blockBuffer: CMBlockBuffer?
            var bufferList = AudioBufferList()
            
            let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: &bufferList,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: nil,
                blockBufferMemoryAllocator: nil,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &blockBuffer
            )
            
            if status == noErr {
                let buffer = bufferList.mBuffers
                if let mData = buffer.mData {
                    let byteSize = Int(buffer.mDataByteSize)
                    let sampleCount = byteSize / MemoryLayout<Float>.size
                    let floatPointer = mData.assumingMemoryBound(to: Float.self)
                    let bufferPointer = UnsafeBufferPointer(start: floatPointer, count: sampleCount)
                    samples.append(contentsOf: bufferPointer)
                }
            }
        }
        
        if reader.status == .failed {
            let errorMsg = reader.error?.localizedDescription ?? "Reading failed in progress."
            throw AudioAnalyzerError.readingFailed(errorMsg)
        }
        
        return samples
    }
}
