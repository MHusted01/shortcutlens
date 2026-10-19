import AppKit
import ShortcutLensCore
import SwiftUI

/// The settings window's toolbar tabs. Each tab hosts a SwiftUI form; the
/// window takes the selected form's size and its title. The last chosen tab
/// is stored and selected again when the window is created.
///
/// A SwiftUI `Settings` scene is not used: it does not reliably open or come
/// to the front in a menu bar app, and macOS 14-15 could not be checked.
@MainActor
final class SettingsTabController: NSTabViewController {
    private let store: SettingsStore

    init(controller: SettingsController, store: SettingsStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: SettingsView(tab: tab, controller: controller))
            // Follows the form's height, for example when pack problems appear.
            host.sizingOptions = .preferredContentSize
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: nil)
            addTabViewItem(item)
        }
        selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: SettingsTab(store: store)) ?? 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let index = tabViewItem.map(tabView.indexOfTabViewItem), SettingsTab.allCases.indices.contains(index)
        else {
            return
        }
        SettingsTab.allCases[index].save(to: store)
        fitWindow(to: tabViewItem?.viewController, animated: true)
    }

    /// The restored tab was selected before the window existed; fit it now.
    override func viewWillAppear() {
        super.viewWillAppear()
        fitWindow(to: selectedViewController, animated: false)
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        guard viewController === selectedViewController else {
            return
        }
        fitWindow(to: viewController, animated: false)
    }

    /// Nil while no tab is selected, for example while the tabs are added.
    private var selectedViewController: NSViewController? {
        tabViewItems.indices.contains(selectedTabViewItemIndex)
            ? tabViewItems[selectedTabViewItemIndex].viewController
            : nil
    }

    /// Resizes the window to the tab's content, keeping its top edge in place.
    private func fitWindow(to viewController: NSViewController?, animated: Bool) {
        guard let window = view.window, let size = viewController?.preferredContentSize, size != .zero else {
            return
        }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        let animates = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        window.setFrame(frame, display: true, animate: animates)
    }
}
