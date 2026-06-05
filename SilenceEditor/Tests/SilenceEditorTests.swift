import Testing
import Foundation
import CoreGraphics
@testable import SilenceEditor

struct SilenceEditorTests {
    @Test("Test formatting seconds to HH:MM:SS duration string")
    func testDurationFormatting() {
        #expect(Formatters.formatDuration(0) == "00:00:00")
        #expect(Formatters.formatDuration(15) == "00:00:15")
        #expect(Formatters.formatDuration(75) == "00:01:15")
        #expect(Formatters.formatDuration(3600) == "01:00:00")
        #expect(Formatters.formatDuration(3665) == "01:01:05")
        #expect(Formatters.formatDuration(Double.nan) == "00:00:00")
    }
    
    @Test("Test formatting byte counts to file sizes")
    func testFileSizeFormatting() {
        #expect(Formatters.formatFileSize(0) == "Zero bytes" || Formatters.formatFileSize(0) == "0 bytes")
        #expect(Formatters.formatFileSize(1000) == "1 KB")
        #expect(Formatters.formatFileSize(1_000_000) == "1 MB")
        #expect(Formatters.formatFileSize(1_000_000_000) == "1 GB")
    }
    
    @Test("Test formatting frame rates")
    func testFrameRateFormatting() {
        #expect(Formatters.formatFrameRate(29.97) == "29.97 fps")
        #expect(Formatters.formatFrameRate(59.94) == "59.94 fps")
        #expect(Formatters.formatFrameRate(0) == "-- fps")
    }
    
    @Test("Test formatting resolutions")
    func testResolutionFormatting() {
        #expect(Formatters.formatResolution(width: 1920, height: 1080) == "1920 × 1080")
        #expect(Formatters.formatResolution(width: 3840, height: 2160) == "3840 × 2160")
        #expect(Formatters.formatResolution(width: 0, height: 0) == "-- × --")
    }
    
    @Test("Test RMS calculation with constant amplitude signals")
    func testRMSComputation() {
        let detector = SilenceDetector()
        // Constant 1.0 signal -> RMS should be exactly 1.0 (20 * log10(1.0) = 0 dB)
        let samples: [Float] = Array(repeating: 1.0, count: 4410)
        let rms = detector.computeRMS(samples: samples, sampleRate: 44100.0, chunkSizeMs: 50.0)
        
        #expect(rms.count == 2) // 4410 samples / 2205 size = 2 chunks
        #expect(abs(rms[0] - 0.0) < 0.01)
        #expect(abs(rms[1] - 0.0) < 0.01)
    }
    
    @Test("Test silence range detection from decibel lists")
    func testSilenceDetection() {
        let detector = SilenceDetector()
        // 10 chunks: 4 loud, 4 silent (-45dB), 2 loud
        let rmsValues: [Float] = [-10.0, -12.0, -15.0, -11.0, -45.0, -50.0, -48.0, -46.0, -8.0, -10.0]
        
        // Threshold: -35dB, min silence: 0.2s (4 chunks * 50ms = 200ms = 0.2s)
        let silences = detector.detectSilence(rmsValues: rmsValues, thresholdDB: -35.0, minSilenceDuration: 0.2, chunkSizeMs: 50.0)
        
        #expect(silences.count == 1)
        #expect(abs(silences[0].start - 0.2) < 0.001) // Starts at chunk index 4 (4 * 0.05 = 0.2s)
        #expect(abs(silences[0].end - 0.4) < 0.001)   // Ends at chunk index 8 (8 * 0.05 = 0.4s)
        #expect(abs(silences[0].duration - 0.2) < 0.001)
    }
    
    @Test("Test merging close silence chunks")
    func testMergeRegions() {
        let detector = SilenceDetector()
        let regions = [
            SilenceRegion(start: 1.0, end: 2.0),
            SilenceRegion(start: 2.1, end: 3.0), // gap: 0.1s (< 0.25s gap threshold -> merges)
            SilenceRegion(start: 4.0, end: 5.5)  // gap: 1.0s (> 0.25s gap threshold -> keeps separate)
        ]
        
        let merged = detector.mergeRegions(regions, gapThreshold: 0.25)
        #expect(merged.count == 2)
        #expect(abs(merged[0].start - 1.0) < 0.001)
        #expect(abs(merged[0].end - 3.0) < 0.001)
        #expect(abs(merged[1].start - 4.0) < 0.001)
        #expect(abs(merged[1].end - 5.5) < 0.001)
    }
    
    @Test("Test padding / shrinking silence regions")
    func testPadRegions() {
        let detector = SilenceDetector()
        let regions = [
            SilenceRegion(start: 1.0, end: 3.0),
            SilenceRegion(start: 5.0, end: 5.15) // duration 0.15s, too short for 0.1s pad on both sides (0.2s total) -> discarded
        ]
        
        let padded = detector.padRegions(regions, padding: 0.1, maxDuration: 10.0)
        #expect(padded.count == 1)
        #expect(abs(padded[0].start - 1.1) < 0.001)
        #expect(abs(padded[0].end - 2.9) < 0.001)
    }
    
    @Test("Test keep segments inversion timeline creation")
    func testConvertToKeepSegments() {
        let detector = SilenceDetector()
        let silences = [
            SilenceRegion(start: 10.0, end: 12.0),
            SilenceRegion(start: 20.0, end: 25.0)
        ]
        
        let keeps = detector.convertToKeepSegments(from: silences, totalDuration: 30.0)
        #expect(keeps.count == 3)
        #expect(abs(keeps[0].start - 0.0) < 0.001)
        #expect(abs(keeps[0].end - 10.0) < 0.001)
        #expect(abs(keeps[1].start - 12.0) < 0.001)
        #expect(abs(keeps[1].end - 20.0) < 0.001)
        #expect(abs(keeps[2].start - 25.0) < 0.001)
        #expect(abs(keeps[2].end - 30.0) < 0.001)
    }
    
    @Test("Test FCPXML generation structure and offsets")
    func testFCPXMLGeneration() {
        let generator = FCPXMLGenerator()
        let video = VideoFile(
            fileURL: URL(fileURLWithPath: "/tmp/IMG_7527.MOV"),
            filename: "IMG_7527.MOV",
            duration: 30.0,
            frameRate: 29.97,
            resolution: CGSize(width: 1920, height: 1080),
            audioTrackCount: 1,
            videoTrackCount: 1,
            fileSize: 10_000_000
        )
        
        let keeps = [
            KeepSegment(start: 0.0, end: 10.0),
            KeepSegment(start: 12.0, end: 20.0)
        ]
        
        do {
            let xml = try generator.generateFCPXML(for: video, keepSegments: keeps)
            
            // Check headers
            #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
            #expect(xml.contains("<!DOCTYPE fcpxml>"))
            #expect(xml.contains("<fcpxml version=\"1.9\">"))
            
            // Check resources mapping
            #expect(xml.contains("frameDuration=\"1001/30000s\""))
            #expect(xml.contains("name=\"IMG_7527.MOV\""))
            
            // Check sequence and spine
            #expect(xml.contains("duration=\"17.9846s\"")) // Snapped sum: 10.01s + 7.9746s
            #expect(xml.contains("offset=\"0.0000s\""))
            #expect(xml.contains("offset=\"10.0100s\""))
            #expect(xml.contains("start=\"12.0120s\""))
            #expect(xml.contains("duration=\"7.9746s\""))
        } catch {
            Issue.record("FCPXML generation failed: \(error)")
        }
    }
}
