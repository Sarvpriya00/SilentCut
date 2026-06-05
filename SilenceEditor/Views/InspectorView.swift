import SwiftUI
import AVFoundation

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
                        
                        // Card 1: Silence Parameters Sliders (Stages 4-7, 9-10)
                        InspectorCard(title: "Silence Parameters") {
                            VStack(alignment: .leading, spacing: 12) {
                                // Presets Dropdown Picker (Stage 10)
                                Picker("Vocal Preset", selection: $viewModel.selectedPreset) {
                                    ForEach(EditingPreset.allCases) { preset in
                                        Text(preset.rawValue).tag(preset)
                                    }
                                }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                
                                Divider().background(Color.proBorder)
                                
                                // Threshold slider & Adaptive suggestions button
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
                                    HStack(spacing: 8) {
                                        Slider(value: $viewModel.thresholdDB, in: -60.0...(-10.0), step: 1.0)
                                            .controlSize(.mini)
                                        
                                        Button(action: {
                                            viewModel.applyAdaptiveThreshold()
                                        }) {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help("Auto-detect noise floor threshold (Stage 9)")
                                    }
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
                                
                                // Silence Merge Gap slider (Clustering - Stage 10)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Clustering Gap")
                                            .font(.system(size: 11))
                                            .foregroundColor(.proTextSecondary)
                                        Spacer()
                                        Text(String(format: "%.2fs", viewModel.mergeGapThreshold))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $viewModel.mergeGapThreshold, in: 0.05...1.5, step: 0.05)
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
                        
                        // Card 2: Export Timeline Manager (Stage 12)
                        if !viewModel.silenceRegions.isEmpty || !viewModel.keepSegments.isEmpty {
                            InspectorCard(title: "Export & Diagnostics") {
                                VStack(alignment: .leading, spacing: 10) {
                                    // Target Editor Picker
                                    Picker("NLE Target", selection: $viewModel.exportTarget) {
                                        ForEach(ExportTarget.allCases) { target in
                                            Text(target.rawValue).tag(target)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .controlSize(.small)
                                    
                                    Divider().background(Color.proBorder)
                                    
                                    // Simulation statistics rows
                                    VStack(spacing: 6) {
                                        InspectorRow(label: "Cuts Detected", value: "\(viewModel.silenceRegions.count)")
                                        
                                        let totalSilenceSecs = viewModel.silenceRegions.reduce(0.0) { $0 + $1.duration }
                                        InspectorRow(label: "Loudness Cut", value: Formatters.formatDuration(totalSilenceSecs))
                                        
                                        let totalKeepSecs = viewModel.keepSegments.reduce(0.0) { $0 + $1.duration }
                                        let estSavedHrs = (totalSilenceSecs / 3600.0) * 1.5 // Standard saved multiplier
                                        
                                        InspectorRow(label: "Final Duration", value: Formatters.formatDuration(totalKeepSecs))
                                        InspectorRow(label: "Est. Time Saved", value: String(format: "%.1f hrs", estSavedHrs))
                                    }
                                    
                                    // Verification System diagnostic reports (Stage 12)
                                    if let report = viewModel.activeReport, !report.issues.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Timeline Warnings:")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.orange)
                                            ForEach(report.issues, id: \.self) { issue in
                                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                                    Circle().fill(Color.orange).frame(width: 4, height: 4)
                                                    Text(issue)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.orange.opacity(0.85))
                                                }
                                            }
                                        }
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.08)))
                                        .padding(.top, 4)
                                    }
                                    
                                    // Export Button
                                    Button(action: {
                                        viewModel.exportTimeline()
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Export Timeline...")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    .controlSize(.regular)
                                    .padding(.top, 4)
                                    .help("Compile XML and save timeline to disk")
                                }
                            }
                        }
                        
                        // Card 3: Preview Audition Cuts (Stage 9)
                        if !viewModel.silenceRegions.isEmpty {
                            InspectorCard(title: "Audition cuts") {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(viewModel.silenceRegions.prefix(30)) { silence in
                                            HStack {
                                                // Confidence score color badge (red for high, orange for uncertain)
                                                Circle()
                                                    .fill(silence.confidence < 0.65 ? Color.orange : Color.red)
                                                    .frame(width: 6, height: 6)
                                                    .help(String(format: "Confidence: %.0f%%", silence.confidence * 100.0))
                                                
                                                Text(String(format: "%.2fs - %.2fs", silence.start, silence.end))
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                if let player = viewModel.player {
                                                    Button(action: {
                                                        viewModel.auditionSilence(silence, player: player)
                                                    }) {
                                                        Image(systemName: "play.fill")
                                                            .font(.system(size: 8))
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.mini)
                                                    .help("Audition context (2s before & after)")
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                        if viewModel.silenceRegions.count > 30 {
                                            Text("Showing first 30 cuts...")
                                                .font(.system(size: 9))
                                                .foregroundColor(.proTextSecondary)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                                .frame(maxHeight: 140)
                            }
                        }
                        
                        // Card 4: File Properties
                        InspectorCard(title: "File Info") {
                            InspectorRow(label: "File Size", value: video.formattedFileSize)
                            InspectorRow(label: "Created", value: video.formattedCreationDate)
                            InspectorRow(label: "Location", value: video.fileURL.lastPathComponent)
                        }
                        
                        // Card 5: Video Stream Info
                        InspectorCard(title: "Video Stream") {
                            InspectorRow(label: "Resolution", value: video.formattedResolution)
                            InspectorRow(label: "Frame Rate", value: video.formattedFrameRate)
                            InspectorRow(label: "Video Tracks", value: "\(video.videoTrackCount)")
                        }
                        
                        // Card 6: Audio Stream Info
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
