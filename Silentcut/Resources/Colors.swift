import SwiftUI
import AppKit

extension Color {
    /// Deep dark charcoal background for main content canvas
    public static let proBackground = Color(nsColor: NSColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1.0)) // #161616
    
    /// Sidebar background color matching FCP sidebar shading
    public static let proSidebar = Color(nsColor: NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)) // #1E1E1E
    
    /// Panel and inspector container background color
    public static let proPanel = Color(nsColor: NSColor(red: 0.141, green: 0.141, blue: 0.141, alpha: 1.0)) // #242424
    
    /// Subtly lighter panel background for cards and nested items
    public static let proCardBackground = Color(nsColor: NSColor(red: 0.176, green: 0.176, blue: 0.176, alpha: 1.0)) // #2D2D2D
    
    /// Dark border lines separating editor panes
    public static let proBorder = Color(nsColor: NSColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0)) // #383838
    
    /// Secondary label description color
    public static let proTextSecondary = Color(nsColor: NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)) // #8C8C8C
    
    /// Glow border highlight color for active drag and drop states
    public static let proDragHighlight = Color(nsColor: NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.15)) // Subtle blue glow
}
