import SwiftUI

/// SidebarView displaying the collection of imported videos.
/// Conforms to Apple Pro App styling guidelines (Logic Pro/FCP sidebars).
public struct SidebarView: View {
    /// Bindable View Model referencing workspace states
    @Bindable var viewModel: MainViewModel
    
    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("MEDIA BROWSER")
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
            
            // Media List
            if viewModel.importedVideos.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundColor(.proTextSecondary.opacity(0.4))
                    Text("No media imported")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.proTextSecondary)
                    Text("Drag files or click Import in the toolbar.")
                        .font(.system(size: 10))
                        .foregroundColor(.proTextSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(selection: $viewModel.selectedVideo) {
                    ForEach(viewModel.importedVideos) { video in
                        HStack(spacing: 10) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.proTextSecondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(video.filename)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(video.formattedDuration)
                                    .font(.system(size: 10))
                                    .foregroundColor(.proTextSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(video)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteVideo(video)
                            } label: {
                                Label("Remove File", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            
            Divider()
                .background(Color.proBorder)
            
            // Sidebar Footer info
            HStack {
                Text(footerText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.proTextSecondary)
                Spacer()
            }
            .padding(12)
            .background(Color.proSidebar)
        }
        .background(Color.proSidebar)
    }
    
    private var footerText: String {
        let count = viewModel.importedVideos.count
        if count == 0 {
            return "0 Clips"
        } else if count == 1 {
            let bytes = viewModel.importedVideos[0].fileSize
            return "1 Clip • \(Formatters.formatFileSize(bytes))"
        } else {
            let totalBytes = viewModel.importedVideos.reduce(0) { $0 + $1.fileSize }
            return "\(count) Clips • \(Formatters.formatFileSize(totalBytes))"
        }
    }
}
