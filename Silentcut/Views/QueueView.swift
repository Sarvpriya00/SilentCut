import SwiftUI

/// Popover or list panel presenting background queue processing tasks.
public struct QueueView: View {
    /// Bindable View Model referencing queue manager structures
    @Bindable var viewModel: MainViewModel
    
    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header actions bar
            HStack {
                Text("BATCH QUEUE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.proTextSecondary)
                    .tracking(1.2)
                Spacer()
                
                Button(action: {
                    viewModel.queueManager.clearCompleted()
                }) {
                    Text("Clear Completed")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Clear finished or failed tasks from history logs")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.proBorder)
            
            if viewModel.queueManager.tasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.down.right")
                        .font(.system(size: 20))
                        .foregroundColor(.proTextSecondary.opacity(0.4))
                        .accessibilityHidden(true)
                    Text("Background Queue Empty")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.proTextSecondary)
                    Text("Right-click items in sidebar to add to queue.")
                        .font(.system(size: 9))
                        .foregroundColor(.proTextSecondary.opacity(0.8))
                    Spacer()
                }
                .frame(width: 250, height: 180)
            } else {
                List {
                    ForEach(viewModel.queueManager.tasks) { task in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(task.video.filename)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text(task.status.rawValue.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(statusColor(for: task.status))
                            }
                            
                            if task.status == .analyzing {
                                ProgressView(value: task.progress)
                                    .progressViewStyle(.linear)
                                    .controlSize(.small)
                            }
                            
                            if let error = task.errorDescription {
                                Text(error)
                                    .font(.system(size: 9))
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.queueManager.removeTask(withId: task.id)
                            } label: {
                                Label("Remove Task", systemImage: "trash")
                            }
                        }
                    }
                }
                .frame(width: 280, height: 220)
                .listStyle(.plain)
            }
        }
        .background(Color.proSidebar)
    }
    
    private func statusColor(for status: QueueTaskStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .analyzing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
