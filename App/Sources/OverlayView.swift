import AppKit
import ShortcutLensCore
import SwiftUI

/// The sizes `PanelLayout` computes with; the view must render exactly these.
private let metrics = PanelLayout.Metrics.standard

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
                    .padding(.top, metrics.sectionSpacing)
                if scrolls {
                    ScrollView(.vertical) { stack }
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
                        SectionView(section: sections[index])
                    }
                }
                .frame(width: metrics.columnWidth, alignment: .leading)
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
                .frame(height: metrics.sectionTitleHeight, alignment: .topLeading)
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
                .frame(height: metrics.rowHeight)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
