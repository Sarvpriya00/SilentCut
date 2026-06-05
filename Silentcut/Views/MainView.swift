import SwiftUI
import AVKit

/// Primary application dashboard for SilenceEditor.
/// Coordinates the left Sidebar, center editing workspace/player, and right Inspector pane.
public struct MainView: View {
    @State private var viewModel = MainViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } content: {
            CenterWorkspaceView(viewModel: viewModel)
        } detail: {
            InspectorView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .frame(minWidth: 950, minHeight: 650)
        .toolbar {
            // Import File button
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.triggerManualImport()
                }) {
                    Label("Import Video", systemImage: "square.and.arrow.down.fill")
                }
                .help("Import a video file (.mov, .mp4, .m4v)")
            }
            
            // Recent Files history dropdown menu
            ToolbarItem(placement: .navigation) {
                Menu {
                    if viewModel.importedVideos.isEmpty {
                        Text("No Recent Files")
                            .font(.footnote)
                    } else {
                        ForEach(viewModel.importedVideos) { video in
                            Button(action: {
                                viewModel.selectedVideo = video
                            }) {
                                HStack {
                                    Image(systemName: "video")
                                    Text(video.filename)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Recent Files", systemImage: "clock")
                }
                .help("Switch between recently imported files")
            }
            
            // Silence analysis trigger (Enabled in Stage 2+)
            ToolbarItem(placement: .status) {
                Button(action: {
                    viewModel.runSilenceAnalysis()
                }) {
                    HStack(spacing: 5) {
                        if viewModel.isAnalyzing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        Text(viewModel.isAnalyzing ? "Analyzing..." : "Analyze Silence")
                    }
                }
                .disabled(viewModel.selectedVideo == nil || viewModel.isAnalyzing)
                .help("Extract waveform and run silence cuts")
            }
        }
    }
}

// MARK: - Center Workspace Panel
struct CenterWorkspaceView: View {
    @Bindable var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Error alerts if files fail validation
            if let error = viewModel.activeError {
                ErrorBanner(message: error) {
                    viewModel.dismissError()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            
            if let selectedVideo = viewModel.selectedVideo {
                VStack(spacing: 20) {
                    // Video Viewer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("VIEWER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.proTextSecondary)
                                .tracking(1.2)
                            Spacer()
                        }
                        
                        VideoPreviewPlayer(url: selectedVideo.fileURL)
                            .frame(minHeight: 240, maxHeight: .infinity)
                            .background(Color.black)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.proBorder, lineWidth: 1)
                            )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                    
                    // Waveform timeline preview (Stage 4-7)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("TIMELINE PREVIEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.proTextSecondary)
                                .tracking(1.2)
                            Spacer()
                            
                            // Visual stats label (Stage 5)
                            if !viewModel.silenceRegions.isEmpty {
                                Text("Detected \(viewModel.silenceRegions.count) silences")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.trailing, 8)
                            }
                            
                            Text(selectedVideo.formattedDuration)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 0) {
                            TimelineRulerView()
                                .frame(height: 18)
                                .background(Color.proSidebar)
                            
                            if viewModel.rmsValues.isEmpty {
                                MockWaveformView()
                                    .frame(height: 64)
                                    .background(Color.proPanel)
                                    .overlay(
                                        Text("Audio Waveform & Cut Detection Available (Click Analyze)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.proTextSecondary.opacity(0.8))
                                    )
                            } else {
                                WaveformView(
                                    rmsValues: viewModel.rmsValues,
                                    silenceRegions: viewModel.silenceRegions,
                                    keepSegments: viewModel.keepSegments,
                                    duration: selectedVideo.duration
                                )
                                .frame(height: 64)
                                .background(Color.proPanel)
                            }
                        }
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.proBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(height: 140)
                }
                .background(Color.proBackground)
            } else {
                DropZoneView(viewModel: viewModel)
                    .background(Color.proBackground)
            }
        }
        .background(Color.proBackground)
        .overlay {
            // Import loading glassmorphism overlay
            if viewModel.isImporting {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Extracting media metadata...")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    )
                    .ignoresSafeArea()
            } else if viewModel.isAnalyzing {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Extracting and analyzing audio samples...")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    )
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Native Video Player Helper
struct VideoPreviewPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: url) { _, newURL in
            player?.pause()
            player = AVPlayer(url: newURL)
        }
    }
}

// MARK: - Timeline Ruler Drawing
struct TimelineRulerView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Horizontal divider
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: width, y: height))
                
                // Vertical periodic subdivision ticks
                let tickCount = Int(width / 30)
                for i in 0...tickCount {
                    let x = CGFloat(i) * 30
                    let isMajor = i % 5 == 0
                    let tickHeight: CGFloat = isMajor ? 10 : 5
                    path.move(to: CGPoint(x: x, y: height - tickHeight))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(Color.proBorder, lineWidth: 1.5)
        }
    }
}

// MARK: - Mock Waveform Drawing
struct MockWaveformView: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<120) { index in
                let height = CGFloat(sin(Double(index) * 0.15) * 16.0 + cos(Double(index) * 0.4) * 8.0 + 20.0)
                Capsule()
                    .fill(Color.proTextSecondary.opacity(0.15))
                    .frame(height: max(4, height))
            }
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Real Time Waveform & Cuts Visualizer (Stage 4-7)
struct WaveformView: View {
    let rmsValues: [Float]
    let silenceRegions: [SilenceRegion]
    let keepSegments: [KeepSegment]
    let duration: Double
    let targetCount: Int = 180
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Downsample full RMS database to fit fixed screen counts
            let downsampled = downsample(rmsValues, to: targetCount)
            
            ZStack(alignment: .leading) {
                // Background visual blocks representing Cuts (Red) vs Keeps (Blue)
                ZStack(alignment: .leading) {
                    // Draw Keep Regions (soft blue backgrounds)
                    ForEach(keepSegments) { segment in
                        let xStart = CGFloat(segment.start / duration) * width
                        let xEnd = CGFloat(segment.end / duration) * width
                        Rectangle()
                            .fill(Color.blue.opacity(0.08))
                            .frame(width: max(1, xEnd - xStart))
                            .offset(x: xStart)
                    }
                    
                    // Draw Silence Cuts Regions (soft red backgrounds)
                    ForEach(silenceRegions) { segment in
                        let xStart = CGFloat(segment.start / duration) * width
                        let xEnd = CGFloat(segment.end / duration) * width
                        Rectangle()
                            .fill(Color.red.opacity(0.14))
                            .frame(width: max(1, xEnd - xStart))
                            .offset(x: xStart)
                    }
                }
                .frame(width: width, height: height)
                
                // Foreground Audio Waveform Bars
                HStack(spacing: 2) {
                    ForEach(0..<downsampled.count, id: \.self) { index in
                        let db = downsampled[index]
                        
                        // Map dB range (-60dB to 0dB) to vertical height ratio (0.05 to 1.0)
                        let normalized = max(0.05, min(1.0, (db - (-60.0)) / (0.0 - (-60.0))))
                        let barHeight = height * CGFloat(normalized) * 0.95
                        
                        // Check if this visual segment falls inside any padded silence region
                        let barTime = (Double(index) / Double(targetCount)) * duration
                        let isSilent = silenceRegions.contains { barTime >= $0.start && barTime <= $0.end }
                        
                        Capsule()
                            .fill(isSilent ? Color.red.opacity(0.55) : Color.blue.opacity(0.65))
                            .frame(height: max(3, barHeight))
                    }
                }
                .padding(.horizontal, 6)
                .frame(width: width, height: height)
            }
        }
    }
    
    /// Downsamples decibel values using peak analysis of segments
    private func downsample(_ values: [Float], to count: Int) -> [Float] {
        guard !values.isEmpty else { return [] }
        guard values.count > count else { return values }
        
        var result: [Float] = []
        let chunkSize = Double(values.count) / Double(count)
        
        for i in 0..<count {
            let startIdx = Int(Double(i) * chunkSize)
            let endIdx = min(Int(Double(i + 1) * chunkSize), values.count)
            let range = values[startIdx..<endIdx]
            
            if let maxVal = range.max() {
                result.append(maxVal)
            } else {
                result.append(-100.0)
            }
        }
        return result
    }
}
