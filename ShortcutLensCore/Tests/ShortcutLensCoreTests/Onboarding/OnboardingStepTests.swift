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

    /// Continue until the last step, which opens System Settings until the
    /// permission is granted.
    @Test(arguments: [
        (OnboardingStep.welcome, false, OnboardingStep.PrimaryButton.continue),
        (.welcome, true, .continue),
        (.howToUse, false, .continue),
        (.howToUse, true, .continue),
        (.accessibility, false, .openSettings),
        (.accessibility, true, .done),
    ])
    func primaryButtonFollowsTheStepAndPermission(
        step: OnboardingStep, isGranted: Bool, expected: OnboardingStep.PrimaryButton
    ) {
        #expect(step.primaryButton(isGranted: isGranted) == expected)
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
