import SwiftUI
import UniformTypeIdentifiers

/// Center view when no video is selected.
/// Displays a large drop target with spring hover animations.
public struct DropZoneView: View {
    /// Bindable View Model referencing workspace states
    @Bindable var viewModel: MainViewModel
    
    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Icon Stack with Hover scaling
            ZStack {
                Circle()
                    .fill(viewModel.isHovering ? Color.blue.opacity(0.12) : Color.proPanel)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(viewModel.isHovering ? Color.blue : Color.proBorder, lineWidth: 2)
                    )
                    .scaleEffect(viewModel.isHovering ? 1.08 : 1.0)
                
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(viewModel.isHovering ? .blue : .white.opacity(0.9))
                    .offset(x: -2) // Center correction for badge system symbol
                    .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isHovering)
            
            // Text Header Details
            VStack(spacing: 8) {
                Text("Drop a Video to Begin")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Import a video file to analyze and prepare for editing.")
                    .font(.system(size: 12))
                    .foregroundColor(.proTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
            
            // Format labels capsule
            Text("Supports .mov, .mp4, .m4v")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.proTextSecondary.opacity(0.8))
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .stroke(Color.proBorder, lineWidth: 1)
                        .background(Capsule().fill(Color.proSidebar))
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    viewModel.isHovering ? Color.blue : Color.proBorder,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isHovering ? Color.proDragHighlight : Color.clear)
                )
        )
        .padding(32)
        .contentShape(Rectangle()) // Makes transparent spaces interactive
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isHovering) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isHovering)
    }
}
