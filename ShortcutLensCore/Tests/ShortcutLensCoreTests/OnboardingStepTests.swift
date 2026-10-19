import ShortcutLensCore
import Testing

struct OnboardingStepTests {
    @Test func stepsFollowTheSpecOrder() {
        #expect(OnboardingStep.allCases == [.welcome, .howToUse, .accessibility])
    }

    @Test func numbersStartAtOne() {
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3])
    }

    @Test func nextMovesForwardAndStopsAtTheEnd() {
        #expect(OnboardingStep.welcome.next == .howToUse)
        #expect(OnboardingStep.howToUse.next == .accessibility)
        #expect(OnboardingStep.accessibility.next == nil)
    }

    @Test func previousMovesBackAndStopsAtTheStart() {
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.howToUse.previous == .welcome)
        #expect(OnboardingStep.accessibility.previous == .howToUse)
    }

    @Test func backShowsFromTheSecondStep() {
        #expect(OnboardingStep.allCases.map(\.showsBack) == [false, true, true])
    }

    @Test func primaryButtonContinuesUntilTheLastStep() {
        #expect(OnboardingStep.welcome.primaryButton(isGranted: false) == .continue)
        #expect(OnboardingStep.howToUse.primaryButton(isGranted: false) == .continue)
        #expect(OnboardingStep.welcome.primaryButton(isGranted: true) == .continue)
        #expect(OnboardingStep.howToUse.primaryButton(isGranted: true) == .continue)
    }

    @Test func lastStepOpensSettingsUntilGranted() {
        #expect(OnboardingStep.accessibility.primaryButton(isGranted: false) == .openSettings)
        #expect(OnboardingStep.accessibility.primaryButton(isGranted: true) == .done)
    }

    @Test func counterIsEnglishByDefault() {
        #expect(OnboardingStep.allCases.map(\.counter) == ["Step 1 of 3", "Step 2 of 3", "Step 3 of 3"])
    }

    @Test func titlesAreEnglishByDefault() {
        #expect(OnboardingStep.allCases.map(\.title) == [
            "Welcome to ShortcutLens", "How to use it", "Allow ShortcutLens to use Accessibility",
        ])
    }

    @Test func primaryButtonTitlesAreEnglishByDefault() {
        let buttons: [OnboardingStep.PrimaryButton] = [.continue, .openSettings, .done]

        #expect(buttons.map(\.title) == ["Continue", "Open System Settings", "Done"])
    }
}
