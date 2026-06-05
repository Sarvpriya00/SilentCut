import SwiftUI

/// A custom banner component to display import or process failures in the UI.
/// Matches Apple Pro aesthetics with deep desaturated red coloring and clean borders.
public struct ErrorBanner: View {
    /// The localized error message description to display
    public let message: String
    
    /// Triggered when the user clicks the close/dismiss button
    public let onDismiss: () -> Void
    
    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Import Error")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red)
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Dismiss Error")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: NSColor(red: 0.18, green: 0.08, blue: 0.08, alpha: 0.9)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}
