import ShortcutLensCore
import Testing

struct AppVersionTests {
    @Test func readsVersionKeys() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "12",
        ])

        #expect(version == AppVersion(marketing: "0.1.0", build: "12"))
        #expect(version.displayString == "0.1.0 (12)")
    }

    @Test func fallsBackWhenValuesAreMissingEmptyOrWrongType() {
        let unknown = AppVersion(marketing: AppVersion.unknownMarketing, build: AppVersion.unknownBuild)
        let wrong = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "",
            "CFBundleVersion": 12,
        ])

        #expect(AppVersion(infoDictionary: [:]) == unknown)
        #expect(wrong == unknown)
    }
}
