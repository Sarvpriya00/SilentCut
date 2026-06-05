import SwiftUI

/// Right sidebar inspector view displaying properties and cutting options of the active video.
/// Conforms to professional visual styling with structured parameter sliders.
public struct InspectorView: View {
    /// Bindable View Model referencing workspace states and parameters
    @Bindable var viewModel: MainViewModel
    
    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Panel Header
            HStack {
                Text("INSPECTOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.proTextSecondary)
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.proBorder)
            
            if let video = viewModel.selectedVideo {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header info banner
                        HStack(spacing: 10) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text(video.filename)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                        
                        // Card 1: Silence Parameters Sliders (Stages 4-7)
                        InspectorCard(title: "Silence Parameters") {
                            VStack(alignment: .leading, spacing: 12) {
                                // Threshold slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("dB Threshold")
                                            .font(.system(size: 11))
                                            .foregroundColor(.proTextSecondary)
                                        Spacer()
                                        Text(String(format: "%.0f dB", viewModel.thresholdDB))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $viewModel.thresholdDB, in: -60.0...(-10.0), step: 1.0)
                                        .controlSize(.mini)
                                }
                                
                                // Min Silence Duration slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Min Duration")
                                            .font(.system(size: 11))
                                            .foregroundColor(.proTextSecondary)
                                        Spacer()
                                        Text(String(format: "%.2fs", viewModel.minSilenceDuration))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $viewModel.minSilenceDuration, in: 0.1...2.0, step: 0.05)
                                        .controlSize(.mini)
                                }
                                
                                // Boundary Padding slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Boundary Padding")
                                            .font(.system(size: 11))
                                            .foregroundColor(.proTextSecondary)
                                        Spacer()
                                        Text(String(format: "%.2fs", viewModel.paddingDuration))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $viewModel.paddingDuration, in: 0.0...0.5, step: 0.05)
                                        .controlSize(.mini)
                                }
                                
                                // Analysis Trigger Button
                                Button(action: {
                                    viewModel.runSilenceAnalysis()
                                }) {
                                    HStack(spacing: 6) {
                                        if viewModel.isAnalyzing {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "bolt.horizontal.fill")
                                        }
                                        Text(viewModel.isAnalyzing ? "Analyzing..." : "Analyze Silence")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.regular)
                                .disabled(viewModel.isAnalyzing)
                                .padding(.top, 4)
                            }
                        }
                        
                        // Card 2: Analysis Results Info (Stage 5-7)
                        if !viewModel.silenceRegions.isEmpty || !viewModel.keepSegments.isEmpty {
                            InspectorCard(title: "Analysis Details") {
                                VStack(spacing: 8) {
                                    InspectorRow(label: "Detected Silences", value: "\(viewModel.silenceRegions.count) regions")
                                    InspectorRow(label: "Kept Segments", value: "\(viewModel.keepSegments.count) regions")
                                    
                                    let totalSilenceSecs = viewModel.silenceRegions.reduce(0.0) { $0 + $1.duration }
                                    InspectorRow(label: "Silence Duration", value: Formatters.formatDuration(totalSilenceSecs))
                                    
                                    let totalKeepSecs = viewModel.keepSegments.reduce(0.0) { $0 + $1.duration }
                                    InspectorRow(label: "Stitched Duration", value: Formatters.formatDuration(totalKeepSecs))
                                    
                                    // Export FCPXML button (Stage 8)
                                    Button(action: {
                                        viewModel.exportFCPXML()
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Export FCPXML...")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    .controlSize(.regular)
                                    .padding(.top, 6)
                                    .help("Save edited timeline as an FCPXML project file")
                                }
                            }
                        }
                        
                        // Card 3: File Properties
                        InspectorCard(title: "File Info") {
                            InspectorRow(label: "File Size", value: video.formattedFileSize)
                            InspectorRow(label: "Created", value: video.formattedCreationDate)
                            InspectorRow(label: "Location", value: video.fileURL.lastPathComponent)
                        }
                        
                        // Card 4: Video Stream Info
                        InspectorCard(title: "Video Stream") {
                            InspectorRow(label: "Resolution", value: video.formattedResolution)
                            InspectorRow(label: "Frame Rate", value: video.formattedFrameRate)
                            InspectorRow(label: "Video Tracks", value: "\(video.videoTrackCount)")
                        }
                        
                        // Card 5: Audio Stream Info
                        InspectorCard(title: "Audio Stream") {
                            InspectorRow(label: "Audio Tracks", value: "\(video.audioTrackCount)")
                            InspectorRow(label: "Duration", value: video.formattedDuration)
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24))
                        .foregroundColor(.proTextSecondary.opacity(0.4))
                    Text("No Selection")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.proTextSecondary)
                    Text("Select a clip to view properties.")
                        .font(.system(size: 10))
                        .foregroundColor(.proTextSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.proSidebar)
    }
}
