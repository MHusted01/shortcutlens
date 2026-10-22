/// Version information read from a bundle's Info dictionary.
public struct AppVersion: Equatable, Sendable {
    public static let unknownMarketing = "0.0.0"
    public static let unknownBuild = "0"

    public let marketing: String
    public let build: String

    public init(marketing: String, build: String) {
        self.marketing = marketing
        self.build = build
    }

    /// Reads `CFBundleShortVersionString` and `CFBundleVersion`, falling back
    /// to placeholder values when a key is missing, empty or not a string.
    public init(infoDictionary: [String: Any]) {
        self.init(
            marketing: Self.nonEmptyString(infoDictionary["CFBundleShortVersionString"]) ?? Self.unknownMarketing,
            build: Self.nonEmptyString(infoDictionary["CFBundleVersion"]) ?? Self.unknownBuild
        )
    }

    /// Human-readable form, for example `0.1.0 (12)`.
    public var displayString: String {
        "\(marketing) (\(build))"
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else {
            return nil
        }
        return string
    }
}
