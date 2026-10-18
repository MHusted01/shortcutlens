import AppKit
import ShortcutLensCore
import SwiftUI

/// The sizes `PanelLayout` computes with; the view must render exactly these.
private let metrics = PanelLayout.Metrics.standard

typealias RowID = PaletteState<AXUIElement>.RowID

/// What the panel shows below its header.
enum OverlayBody {
    case loading
    case empty
    /// The palette's query matches no row.
    case noMatches
    /// `scrolls` is true when the columns are taller than the panel can be.
    case shortcuts(sections: [OverlaySection<AXUIElement>], columns: [[Int]], scrolls: Bool)
}

/// What the palette shows and reports, updated in place while the user types
/// so the search field keeps its focus and caret.
@MainActor
@Observable
final class PaletteModel {
    var query = ""
    var body = OverlayBody.loading
    var selection: RowID?
    @ObservationIgnored let onQueryChange: (String) -> Void
    /// Returns whether the command was handled; see `SearchField`.
    @ObservationIgnored let onCommand: (SearchCommand) -> Bool

    init(onQueryChange: @escaping (String) -> Void, onCommand: @escaping (SearchCommand) -> Bool) {
        self.onQueryChange = onQueryChange
        self.onCommand = onCommand
    }
}

/// The overlay: the app's icon and name, then its shortcuts in columns.
/// Clicking a row calls `onSelect` with it. With a `palette`, the header has
/// a search field and the body and selection come from the palette.
struct OverlayView: View {
    let appName: String
    let icon: NSImage?
    let content: OverlayBody
    var palette: PaletteModel?
    let onSelect: (OverlayRow<AXUIElement>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            switch palette?.body ?? content {
            case .loading:
                placeholder { ProgressView().controlSize(.small) }
            case .empty:
                placeholder { Text("No keyboard shortcuts").foregroundStyle(.secondary) }
            case .noMatches:
                placeholder { Text("No matching shortcuts").foregroundStyle(.secondary) }
            case let .shortcuts(sections, columns, scrolls):
                let stack = columnStack(sections: sections, columns: columns)
                    .padding(.top, metrics.sectionSpacing)
                if scrolls {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) { stack }
                            .onChange(of: palette?.selection) { _, selection in
                                selection.map { proxy.scrollTo($0) }
                            }
                    }
                } else {
                    stack
                }
            }
        }
        .padding(metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            Text(appName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            if let palette {
                SearchField(text: palette.query, onChange: palette.onQueryChange, onCommand: palette.onCommand)
                    .frame(minWidth: metrics.columnWidth / 2)
            }
        }
        .frame(height: metrics.headerHeight, alignment: .top)
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func columnStack(sections: [OverlaySection<AXUIElement>], columns: [[Int]]) -> some View {
        HStack(alignment: .top, spacing: metrics.columnSpacing) {
            ForEach(columns.indices, id: \.self) { column in
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    ForEach(columns[column], id: \.self) { index in
                        SectionView(section: sections[index], selection: palette?.selection, onSelect: onSelect)
                    }
                }
                .frame(width: metrics.columnWidth, alignment: .leading)
            }
        }
    }
}

private struct SectionView: View {
    let section: OverlaySection<AXUIElement>
    let selection: RowID?
    let onSelect: (OverlayRow<AXUIElement>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .lineLimit(1)
                .frame(height: metrics.sectionTitleHeight, alignment: .topLeading)
            ForEach(section.rows) { row in
                let id = RowID(section: section.id, row: row.id)
                RowView(row: row, isSelected: id == selection) { onSelect(row) }
                    .id(id)
            }
        }
    }
}

/// One shortcut. The whole row is the click target and highlights on hover;
/// the palette's selected row has a stronger highlight. Display-only rows
/// (system shortcuts) look normal but do not react to clicks.
private struct RowView: View {
    private static let highlightInset: CGFloat = -4
    private static let highlightCornerRadius: CGFloat = 5
    private static let disabledOpacity = 0.4
    /// Marks a shortcut the user set in App Shortcuts.
    private static let customSymbol = "person.crop.circle"

    let row: OverlayRow<AXUIElement>
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(row.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if row.isCustom {
                    Image(systemName: Self.customSymbol)
                        .foregroundStyle(.tint)
                        .imageScale(.small)
                        .help("Set in App Shortcuts")
                }
                Text(row.keys)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(height: metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.isRunnable)
        .opacity(row.isEnabled ? 1 : Self.disabledOpacity)
        .background {
            RoundedRectangle(cornerRadius: Self.highlightCornerRadius)
                .inset(by: Self.highlightInset)
                .fill(highlight)
        }
        .onHover { isHovered = $0 }
        .accessibilityLabel(row.isCustom ? "\(row.title), \(row.keys), custom shortcut" : "\(row.title), \(row.keys)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var highlight: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        return isHovered && row.isRunnable ? Color.primary.opacity(0.1) : .clear
    }
}
