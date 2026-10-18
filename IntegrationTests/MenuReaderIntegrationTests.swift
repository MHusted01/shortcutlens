import AppKit
@testable import ShortcutLens
import ShortcutLensCore
import Testing

/// Reads MenuFixture's real menu bar through `SystemAXClient`. Runs locally
/// only (`make integration`): it needs the Accessibility permission, which the
/// host app ShortcutLens.app keeps across rebuilds when dev-signed (see README).
@MainActor
struct MenuReaderIntegrationTests {
    /// One line per shortcut: menu path, then the rendered shortcut.
    private static let expected = [
        "MenuFixture > Quit MenuFixture: ⌘Q",
        // AppKit adds this Option alternate to the Quit item by itself.
        "MenuFixture > Quit and Keep Windows: ⌥⌘Q",
        "File > New: ⌘N",
        "File > Save As…: ⇧⌘S",
        "File > Export > PDF: ⌥⌘P",
        "File > Export > More > Everything: ⌃⌥⇧⌘X",
        "Keys > Refresh: F5",
        "Keys > Back: ⌘←",
        "Keys > Delete: ⌘⌫",
        "Keys > Send: ⇧↩",
        "Keys > Cancel: ⎋",
    ]

    private static let launchTimeout: Duration = .seconds(10)

    @Test func readsTheFixtureMenus() async throws {
        try #require(AXIsProcessTrusted(), "Grant ShortcutLens the Accessibility permission first.")
        let fixture = try await launchFixture()
        defer { fixture.forceTerminate() }

        let lines = try await waitForMenus(of: fixture.processIdentifier)

        #expect(lines == Self.expected)
    }

    /// MenuFixture.app is built next to the host app, ShortcutLens.app.
    private func launchFixture() async throws -> NSRunningApplication {
        let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MenuFixture.app")
        try #require(FileManager.default.fileExists(atPath: url.path), "Missing \(url.path)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        return try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// The menu bar appears shortly after launch; poll until it has shortcuts.
    private func waitForMenus(of pid: pid_t) async throws -> [String] {
        let reader = MenuReader(client: SystemAXClient())
        let deadline = ContinuousClock.now + Self.launchTimeout
        while ContinuousClock.now < deadline {
            let groups = reader.read(processID: pid)
            if !groups.isEmpty {
                return groups.flatMap(\.items).map(describe)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("MenuFixture showed no menu bar within \(Self.launchTimeout)")
        return []
    }

    private func describe(_ entry: MenuEntry<AXUIElement>) -> String {
        let path = entry.shortcut.menuPath.joined(separator: " > ")
        return "\(path): \(ShortcutFormatter.string(for: entry.shortcut) ?? "?")"
    }
}
