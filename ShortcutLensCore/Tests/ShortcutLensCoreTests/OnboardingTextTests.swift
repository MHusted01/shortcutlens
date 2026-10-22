import Foundation
import ShortcutLensCore
import Testing

struct OnboardingTextTests {
    private static func privacyText() throws -> String {
        let text = try String(contentsOf: RepositoryFiles.url("PRIVACY.md"), encoding: .utf8)
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
