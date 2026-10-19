import SwiftUI

/// The palette's search field in its rounded container: a leading magnifying
/// glass and a tinted fill. The field always has focus while the palette
/// shows, so the container always draws the focus stroke instead of a system
/// focus ring.
struct SearchBox: View {
    private static let symbol = "magnifyingglass"
    private static let fillOpacity = 0.06
    private static let horizontalPadding: CGFloat = 8
    private static let verticalPadding: CGFloat = 5
    /// Between the magnifying glass and the field.
    private static let symbolSpacing: CGFloat = 6
    private static let focusStrokeWidth: CGFloat = 1
    /// Under Increase Contrast the focus stroke is thicker.
    private static let contrastFocusStrokeWidth: CGFloat = 2

    private static var cornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 8
        }
        return 6
    }

    let text: String
    let onChange: (String) -> Void
    let onCommand: (SearchCommand) -> Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
        HStack(spacing: Self.symbolSpacing) {
            Image(systemName: Self.symbol)
                .foregroundStyle(.secondary)
                // The field has its own label.
                .accessibilityHidden(true)
            SearchField(text: text, onChange: onChange, onCommand: onCommand)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(shape.fill(Color.primary.opacity(Self.fillOpacity)))
        .overlay {
            shape.strokeBorder(
                Color.accentColor,
                lineWidth: contrast == .increased ? Self.contrastFocusStrokeWidth : Self.focusStrokeWidth
            )
        }
    }
}
