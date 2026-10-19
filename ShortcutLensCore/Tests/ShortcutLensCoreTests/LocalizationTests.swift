import Foundation
import ShortcutLensCore
import Testing

/// Checks the string catalogs of Core and the app: every key has a Danish
/// translation with the same placeholders as the English text.
struct LocalizationTests {
    /// The repository root, four levels above this file.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let catalogs = [
        "ShortcutLensCore/Sources/ShortcutLensCore/Localizable.xcstrings",
        "App/Resources/Localizable.xcstrings",
    ]

    private static func strings(in path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appending(path: path))
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(catalog["sourceLanguage"] as? String == "en")
        return try #require(catalog["strings"] as? [String: Any])
    }

    /// The values of one language's entry: a single string or plural forms.
    /// Nil when a value is missing or not marked as translated.
    private static func values(of entry: Any?, language: String) -> [String]? {
        guard let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any]
        else {
            return nil
        }
        let units = if let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] {
            plural.values.compactMap { ($0 as? [String: Any])?["stringUnit"] }
        } else {
            [localization["stringUnit"]].compactMap(\.self)
        }
        let translated = units.compactMap { unit -> String? in
            guard let unit = unit as? [String: Any], unit["state"] as? String == "translated",
                  let value = unit["value"] as? String, !value.isEmpty
            else {
                return nil
            }
            return value
        }
        return translated.isEmpty || translated.count != units.count ? nil : translated
    }

    /// Format specifiers such as `%@` and `%lld`, without positions, sorted.
    static func placeholders(in text: String) -> [String] {
        let pattern = #/%(?:\d+\$)?(lld|ld|d|@)/#
        return text.matches(of: pattern).map { "%" + String($0.output.1) }.sorted()
    }

    /// The translations a catalog has: every language of any entry except
    /// English, and always Danish.
    private static func languages(in strings: [String: Any]) -> [String] {
        let used = strings.values.flatMap { entry in
            (((entry as? [String: Any])?["localizations"] as? [String: Any]) ?? [:]).keys
        }
        return Set(used + ["da"]).subtracting(["en"]).sorted()
    }

    @Test(arguments: catalogs) func everyKeyIsTranslatedIntoEveryLanguage(path: String) throws {
        let strings = try Self.strings(in: path)
        #expect(!strings.isEmpty)
        let missing = Self.languages(in: strings).flatMap { language in
            strings.filter { Self.values(of: $0.value, language: language) == nil }.map { "\(language): \($0.key)" }
        }
        #expect(missing.sorted() == [])
    }

    @Test(arguments: catalogs) func translationsKeepThePlaceholders(path: String) throws {
        let strings = try Self.strings(in: path)
        let languages = Self.languages(in: strings)
        let broken = strings.filter { key, entry in
            let english = Self.values(of: entry, language: "en") ?? [key]
            let translated = languages.flatMap { Self.values(of: entry, language: $0) ?? [] }
            let expected = Self.placeholders(in: english[0])
            return !(english + translated).allSatisfy { Self.placeholders(in: $0) == expected }
        }.map(\.key).sorted()
        #expect(broken == [])
    }

    @Test func placeholdersIgnorePositions() {
        #expect(Self.placeholders(in: "%2$@ har %1$lld") == ["%@", "%lld"])
    }

    @Test func shortcutCountIsEnglishByDefault() {
        #expect(PaletteAnnouncement.shortcutCount(1) == "1 shortcut")
        #expect(PaletteAnnouncement.shortcutCount(3) == "3 shortcuts")
    }

    @Test func shortcutCountHasDanishPluralForms() {
        let danish = Locale(identifier: "da_DK")

        #expect(PaletteAnnouncement.shortcutCount(1, locale: danish) == "1 genvej")
        #expect(PaletteAnnouncement.shortcutCount(3, locale: danish) == "3 genveje")
    }
}
