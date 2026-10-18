import ShortcutLensCore
import Testing

struct AccessibilityPermissionTests {
    @Test func startsUnknown() {
        let state = AccessibilityPermission.initial

        #expect(state.status == .unknown)
        #expect(!state.hasShownOnboarding)
    }

    @Test func showsOnboardingWhenMissingAtLaunch() {
        let (state, action) = AccessibilityPermission.initial.updated(isTrusted: false)

        #expect(state.status == .missing)
        #expect(state.hasShownOnboarding)
        #expect(action == .showOnboarding)
    }

    @Test func showsOnboardingOnlyOncePerLaunch() {
        let (first, _) = AccessibilityPermission.initial.updated(isTrusted: false)
        let (second, action) = first.updated(isTrusted: false)

        #expect(second == first)
        #expect(action == .none)
    }

    @Test func doesNothingWhenGrantedAtLaunch() {
        let (state, action) = AccessibilityPermission.initial.updated(isTrusted: true)

        #expect(state.status == .granted)
        #expect(!state.hasShownOnboarding)
        #expect(action == .none)
    }

    @Test func closesOnboardingWhenGranted() {
        let (missing, _) = AccessibilityPermission.initial.updated(isTrusted: false)
        let (state, action) = missing.updated(isTrusted: true)

        #expect(state.status == .granted)
        #expect(action == .closeOnboarding)
    }

    @Test func staysQuietWhileGranted() {
        let (granted, _) = AccessibilityPermission.initial.updated(isTrusted: true)
        let (state, action) = granted.updated(isTrusted: true)

        #expect(state == granted)
        #expect(action == .none)
    }

    @Test func showsOnboardingOnceWhenRevokedAfterLaunch() {
        let (granted, _) = AccessibilityPermission.initial.updated(isTrusted: true)
        let (revoked, firstAction) = granted.updated(isTrusted: false)
        let (_, regrantAction) = revoked.updated(isTrusted: true)
        let (_, repeatAction) = revoked.updated(isTrusted: false)

        #expect(revoked.status == .missing)
        #expect(firstAction == .showOnboarding)
        #expect(regrantAction == .closeOnboarding)
        #expect(repeatAction == .none)
    }

    @Test func doesNotShowAgainAfterGrantAndRevoke() {
        let (missing, _) = AccessibilityPermission.initial.updated(isTrusted: false)
        let (granted, _) = missing.updated(isTrusted: true)
        let (state, action) = granted.updated(isTrusted: false)

        #expect(state.status == .missing)
        #expect(action == .none)
    }

    @Test func isGrantedReflectsStatus() {
        #expect(!AccessibilityPermission.initial.isGranted)
        #expect(AccessibilityPermission.initial.updated(isTrusted: true).state.isGranted)
        #expect(!AccessibilityPermission.initial.updated(isTrusted: false).state.isGranted)
    }
}
