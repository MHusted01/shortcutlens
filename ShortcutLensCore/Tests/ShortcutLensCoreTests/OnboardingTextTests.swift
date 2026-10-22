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

    @Test(arguments: [OnboardingText.explanation, OnboardingText.noData])
    func privacyClaimsQuoteThePrivacyPolicy(text: String) throws {
        #expect(try Self.privacyText().contains(text))
    }

    @Test func instructionsNoLongerPromiseTheWindowCloses() {
        #expect(!OnboardingText.instructions.contains("closes"))
    }
}
