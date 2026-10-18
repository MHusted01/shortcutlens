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

    @Test func fallsBackWhenKeysAreMissing() {
        let version = AppVersion(infoDictionary: [:])

        #expect(version.marketing == AppVersion.unknownMarketing)
        #expect(version.build == AppVersion.unknownBuild)
    }

    @Test func fallsBackWhenValuesAreEmptyOrWrongType() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "",
            "CFBundleVersion": 12,
        ])

        #expect(version == AppVersion(marketing: AppVersion.unknownMarketing, build: AppVersion.unknownBuild))
    }
}
