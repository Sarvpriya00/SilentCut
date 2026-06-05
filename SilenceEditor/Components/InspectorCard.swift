import SwiftUI

/// A card container for groups of metadata parameters in the Inspector.
/// Uses deep charcoal colorings matching FCP and Logic Pro UI cards.
public struct InspectorCard<Content: View>: View {
    public let title: String
    public let content: Content
    
    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.proTextSecondary)
                .tracking(1.2)
            
            Divider()
                .background(Color.proBorder)
            
            VStack(spacing: 8) {
                content
            }
        }
        .padding(12)
        .background(Color.proCardBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.proBorder, lineWidth: 1)
        )
    }
}

/// A structured row component representing a singular metadata parameter key-value pair.
public struct InspectorRow: View {
    public let label: String
    public let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.proTextSecondary)
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
