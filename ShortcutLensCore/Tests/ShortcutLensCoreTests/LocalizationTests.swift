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

    /// Format specifiers such as `%@`, `%lld` and `%.1f`, without positions, sorted.
    static func placeholders(in text: String) -> [String] {
        let pattern = #/%(?:\d+\$)?(\.\d+)?(lld|ld|d|u|f|@|%)/#
        return text.matches(of: pattern).map { "%" + String($0.output.1 ?? "") + String($0.output.2) }.sorted()
    }

    /// `text` with every format specifier as a bare `%`, and `%%` as the `%`
    /// a code literal has.
    static func withoutPlaceholders(_ text: String) -> String {
        text.split(separator: "%%", omittingEmptySubsequences: false)
            .map { $0.replacing(#/%(?:\d+\$)?(?:\.\d+)?(?:lld|ld|d|u|f|@)/#, with: "%") }
            .joined(separator: "%")
    }

    /// Where localized literals are used: a catalog, the sources it serves, and
    /// the calls whose first argument is a localization key.
    struct Usage: Sendable, CustomTestStringConvertible {
        let catalog: String
        let sources: String
        let calls: [String]

        var testDescription: String {
            sources
        }
    }

    static let usages = [
        Usage(
            catalog: catalogs[0], sources: "ShortcutLensCore/Sources/ShortcutLensCore",
            calls: [#"String\(\s*localized:"#, #"entry\(\d+,"#, #"unassigned\(\d+,"#]
        ),
        Usage(catalog: catalogs[1], sources: "App/Sources", calls: [
            #"String\(\s*localized:"#, #"(?:^|[^.\w])Text\("#, #"Button\("#, #"Toggle\("#, #"Section\("#,
            #"LabeledContent\("#, #"Stepper\(\s*"#, #"ProgressView\("#, #"Label\("#, #"\.help\("#,
            #"\.accessibilityLabel\("#, #"\.accessibilityValue\("#,
        ]),
    ]

    /// The keys of the string literals right after one of `calls`, with
    /// interpolations as `%`. An interpolation must not contain a string
    /// literal; move such an expression into a local first.
    static func literalKeys(in source: String, calls: [String]) throws -> [String] {
        let literal = #"("""[\s\S]*?"""|"(?:[^"\\\n]|\\.)*")"#
        return try calls.flatMap { call in
            try source.matches(of: Regex(call + #"\s*"# + literal)).compactMap { match in
                match.output[1].substring.map { key(fromLiteral: String($0)) }
            }
        }
    }

    private static func key(fromLiteral literal: String) -> String {
        let text = if literal.hasPrefix("\"\"\"") {
            literal.dropFirst(3).dropLast(3)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .replacing("\\\n", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            String(literal.dropFirst().dropLast())
        }
        return text.replacing(#/\\\((?:[^()]|\([^()]*\))*\)/#, with: "%").replacing("\\\"", with: "\"")
    }

    @Test(arguments: usages) func everyLiteralInTheCodeIsACatalogKey(usage: Usage) throws {
        let keys = try Set(Self.strings(in: usage.catalog).keys.map(Self.withoutPlaceholders))
        let files = try FileManager.default
            .contentsOfDirectory(at: Self.root.appending(path: usage.sources), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        let missing = try files.flatMap { file in
            try Self.literalKeys(in: String(contentsOf: file, encoding: .utf8), calls: usage.calls)
                .filter { !keys.contains($0) }
                .map { "\(file.lastPathComponent): \($0)" }
        }
        #expect(missing.sorted() == [])
    }

    @Test func literalKeysReadInterpolationsAndMultilineText() throws {
        let source = #"""
        Text("Hi \(name.first(of: 2))!") Button("Say \"no\"")
        String(localized: """
            One \
            two.
            """)
        """#
        let calls = [#"Text\("#, #"Button\("#, #"String\(\s*localized:"#]

        #expect(try Self.literalKeys(in: source, calls: calls) == ["Hi %!", #"Say "no""#, "One two."])
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
        #expect(Self.placeholders(in: "%.1f%% of %@") == ["%%", "%.1f", "%@"])
    }

    @Test func withoutPlaceholdersMapsPercentEscapes() {
        #expect(Self.withoutPlaceholders("%lld%% of %@") == "%% of %")
        #expect(Self.withoutPlaceholders("50%%") == "50%")
        // `\(n)%\(name)` in code; `%%@` is a literal "%@".
        #expect(Self.withoutPlaceholders("%lld%%%@") == "%%%")
        #expect(Self.withoutPlaceholders("%%@") == "%@")
    }

    @Test func shortcutCountIsEnglishByDefault() {
        #expect(PaletteAnnouncement.shortcutCount(0) == "0 shortcuts")
        #expect(PaletteAnnouncement.shortcutCount(1) == "1 shortcut")
        #expect(PaletteAnnouncement.shortcutCount(3) == "3 shortcuts")
    }

    @Test func shortcutCountHasDanishPluralForms() {
        let danish = Locale(identifier: "da_DK")

        #expect(PaletteAnnouncement.shortcutCount(0, locale: danish) == "0 genveje")
        #expect(PaletteAnnouncement.shortcutCount(1, locale: danish) == "1 genvej")
        #expect(PaletteAnnouncement.shortcutCount(3, locale: danish) == "3 genveje")
    }
}
