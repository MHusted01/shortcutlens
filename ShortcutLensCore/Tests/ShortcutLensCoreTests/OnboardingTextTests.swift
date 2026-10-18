import Foundation
import ShortcutLensCore
import Testing

struct OnboardingTextTests {
    /// PRIVACY.md at the repository root, four levels above this file.
    private static let privacyURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("PRIVACY.md")

    private static func privacyText() throws -> String {
        let text = try String(contentsOf: privacyURL, encoding: .utf8)
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test func explanationMatchesPrivacyPolicy() throws {
        #expect(try Self.privacyText().contains(OnboardingText.explanation))
    }

    @Test func noDataClaimMatchesPrivacyPolicy() throws {
        #expect(try Self.privacyText().contains(OnboardingText.noData))
    }

    @Test func textsAreNotEmpty() {
        #expect(!OnboardingText.title.isEmpty)
        #expect(!OnboardingText.instructions.isEmpty)
        #expect(!OnboardingText.openSettingsButton.isEmpty)
        #expect(!OnboardingText.laterButton.isEmpty)
        #expect(!OnboardingText.menuItem.isEmpty)
    }
}
