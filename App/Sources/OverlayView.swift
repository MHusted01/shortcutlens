import AppKit
import ShortcutLensCore
import SwiftUI

/// Fixed sizes of the overlay. Rows and section titles have fixed heights, so
/// the panel size and the column split can be computed before rendering.
enum OverlayMetrics {
    static let padding: CGFloat = 20
    static let headerHeight: CGFloat = 40
    /// The `Divider` below the header.
    static let dividerHeight: CGFloat = 1
    static let columnWidth: CGFloat = 260
    static let columnSpacing: CGFloat = 24
    static let rowHeight: CGFloat = 20
    static let sectionTitleHeight: CGFloat = 24
    static let sectionSpacing: CGFloat = 14
    static let placeholderSize = CGSize(width: 360, height: 150)
    /// Share of the screen's visible area the overlay may cover.
    static let screenFraction: CGFloat = 0.9

    /// Includes the spacing below the section; see `OverlayController.layout`.
    static func sectionHeight(rows: Int) -> Int {
        Int(sectionTitleHeight + CGFloat(rows) * rowHeight + sectionSpacing)
    }
}

/// What the panel shows below its header.
enum OverlayBody {
    case loading
    case empty
    /// `scrolls` is true when the columns are taller than the panel can be.
    case shortcuts(sections: [OverlaySection<AXUIElement>], columns: [[Int]], scrolls: Bool)
}

/// The overlay: the app's icon and name, then its shortcuts in columns.
struct OverlayView: View {
    let appName: String
    let icon: NSImage?
    let content: OverlayBody

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            switch content {
            case .loading:
                placeholder { ProgressView().controlSize(.small) }
            case .empty:
                placeholder { Text("No keyboard shortcuts").foregroundStyle(.secondary) }
            case let .shortcuts(sections, columns, scrolls):
                let stack = columnStack(sections: sections, columns: columns)
                    .padding(.top, OverlayMetrics.sectionSpacing)
                if scrolls {
                    ScrollView(.vertical) { stack }
                } else {
                    stack
                }
            }
        }
        .padding(OverlayMetrics.padding)
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
        }
        .frame(height: OverlayMetrics.headerHeight, alignment: .top)
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func columnStack(sections: [OverlaySection<AXUIElement>], columns: [[Int]]) -> some View {
        HStack(alignment: .top, spacing: OverlayMetrics.columnSpacing) {
            ForEach(columns.indices, id: \.self) { column in
                VStack(alignment: .leading, spacing: OverlayMetrics.sectionSpacing) {
                    ForEach(columns[column], id: \.self) { index in
                        SectionView(section: sections[index])
                    }
                }
                .frame(width: OverlayMetrics.columnWidth, alignment: .leading)
            }
        }
    }
}

private struct SectionView: View {
    let section: OverlaySection<AXUIElement>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .lineLimit(1)
                .frame(height: OverlayMetrics.sectionTitleHeight, alignment: .topLeading)
            ForEach(section.rows) { row in
                HStack(spacing: 8) {
                    Text(row.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(row.keys)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(height: OverlayMetrics.rowHeight)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
