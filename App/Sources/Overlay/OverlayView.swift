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
    /// Opens the shortcut editor for a menu item row; nil hides "Edit Shortcut…".
    var onEdit: ((RowID, OverlayRow<AXUIElement>) -> Void)?
    /// Adds a menu item row to the favourites or removes it; nil hides the
    /// menu entry.
    var onFavourite: ((OverlayRow<AXUIElement>) -> Void)?

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
                // PaletteAnnouncement speaks the text when the state appears.
                placeholder {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text("No matching shortcuts")
                    }
                    .foregroundStyle(.secondary)
                }
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
                SearchBox(text: palette.query, onChange: palette.onQueryChange, onCommand: palette.onCommand)
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
                        SectionView(
                            section: sections[index], selection: palette?.selection, onSelect: onSelect, onEdit: onEdit,
                            onFavourite: onFavourite
                        )
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
    let onEdit: ((RowID, OverlayRow<AXUIElement>) -> Void)?
    let onFavourite: ((OverlayRow<AXUIElement>) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .lineLimit(1)
                .frame(height: metrics.sectionTitleHeight, alignment: .topLeading)
                .accessibilityAddTraits(.isHeader)
            ForEach(section.rows) { row in
                let id = RowID(section: section.id, row: row.id)
                // Every row in Favourites is one, so the star would only repeat the title.
                RowView(
                    row: row, isSelected: id == selection, showsStar: row.isFavourite && !section.isPinned,
                    accessibilityLabel: PaletteAnnouncement.rowLabel(row, inPinnedSection: section.isPinned)
                ) {
                    onSelect(row)
                }
                .id(id)
                .contextMenu { actions(for: row, id: id) }
                // VoiceOver users reach the same actions with VO-Command-Space.
                .accessibilityActions { actions(for: row, id: id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.title)
    }

    @ViewBuilder
    private func actions(for row: OverlayRow<AXUIElement>, id: RowID) -> some View {
        // Only menu items have an App Shortcut to edit.
        if let onEdit, row.element != nil {
            Button("Edit Shortcut…") { onEdit(id, row) }
        }
        if let onFavourite, row.canBeFavourite {
            Button(row.isFavourite ? "Remove from Favourites" : "Add to Favourites") { onFavourite(row) }
        }
    }
}

/// One shortcut. The whole row is the click target and highlights on hover;
/// the palette's selected row has a stronger highlight. Display-only rows
/// (system shortcuts) look normal but do not react to clicks.
private struct RowView: View {
    private static let highlightInset: CGFloat = -4
    private static let hoverOpacity = 0.08
    private static let selectionOpacity = 0.3
    /// Under Increase Contrast the selection also gets an accent outline.
    private static let selectionStrokeWidth: CGFloat = 1
    private static let disabledOpacity = 0.4
    /// Marks a shortcut the user set in App Shortcuts.
    private static let customSymbol = "person.crop.circle"
    /// Marks a shortcut whose keys another row also uses.
    private static let conflictSymbol = "exclamationmark.triangle.fill"
    private static let conflictColor = Color(nsColor: .systemOrange)
    /// Marks a row the user added to the favourites.
    private static let favouriteSymbol = "star.fill"
    private static let favouriteColor = Color(nsColor: .systemYellow)

    private static var highlightCornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 6
        }
        return 5
    }

    let row: OverlayRow<AXUIElement>
    let isSelected: Bool
    let showsStar: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        clickTarget
            .opacity(row.isEnabled ? 1 : Self.disabledOpacity)
            .background {
                let shape = RoundedRectangle(cornerRadius: Self.highlightCornerRadius).inset(by: Self.highlightInset)
                shape.fill(highlight)
                    .overlay {
                        if isSelected, contrast == .increased {
                            shape.strokeBorder(Color.accentColor, lineWidth: Self.selectionStrokeWidth)
                        }
                    }
            }
            .onHover { isHovered = $0 }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A button for menu items. Display-only rows (no menu item to press) are
    /// plain text, so VoiceOver does not read them as dimmed buttons; disabled
    /// menu items stay disabled buttons.
    @ViewBuilder
    private var clickTarget: some View {
        if row.element == nil {
            content.accessibilityElement(children: .ignore)
        } else {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .disabled(!row.isRunnable)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            line
            if let conflict = row.conflict {
                Text(conflict)
                    .font(.caption)
                    .foregroundStyle(Self.conflictColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(conflict)
                    .frame(height: metrics.rowHeight)
            }
        }
        .contentShape(Rectangle())
    }

    /// Title, markers and keys; a conflict adds a caption line below it.
    private var line: some View {
        HStack(spacing: 8) {
            Text(row.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if showsStar {
                Image(systemName: Self.favouriteSymbol)
                    .foregroundStyle(Self.favouriteColor)
                    .imageScale(.small)
                    .help("In Favourites")
                    // The row's label already says "favourite".
                    .accessibilityHidden(true)
            }
            if row.isCustom {
                Image(systemName: Self.customSymbol)
                    .foregroundStyle(.tint)
                    .imageScale(.small)
                    .help("Set in App Shortcuts")
                    // The row's label already says "custom shortcut".
                    .accessibilityHidden(true)
            }
            if row.conflict != nil {
                Image(systemName: Self.conflictSymbol)
                    .foregroundStyle(Self.conflictColor)
                    .imageScale(.small)
                    // The row's label already includes the conflict.
                    .accessibilityHidden(true)
            }
            Text(KeyDisplay.text(for: row.keys))
                .foregroundStyle(row.conflict == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Self.conflictColor))
                .monospacedDigit()
        }
        .frame(height: metrics.rowHeight)
    }

    private var highlight: Color {
        if isSelected {
            return Color.accentColor.opacity(Self.selectionOpacity)
        }
        return isHovered && row.isRunnable ? Color.primary.opacity(Self.hoverOpacity) : .clear
    }
}
