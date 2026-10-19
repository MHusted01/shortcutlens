import ShortcutLensCore
import SwiftUI

/// What the onboarding window shows. `PermissionController` owns it and keeps
/// `isGranted` current; the view moves between the steps.
@MainActor
@Observable
final class OnboardingModel {
    var step = OnboardingStep.welcome
    var isGranted = false
}

/// The first run in three steps: what the app does, how to use it, and the
/// Accessibility permission with its live status. See "Spec: onboarding" on #90.
struct OnboardingView: View {
    static let width: CGFloat = 480
    private static let padding: CGFloat = 24
    private static let visualSize: CGFloat = 64
    private static let slide: CGFloat = 8
    private static let stepAnimation = Animation.easeInOut(duration: 0.2)

    let model: OnboardingModel
    let openSettings: () -> Void
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isTitleFocused: Bool
    /// Whether the last step change went forward; sets the slide direction.
    @State private var movedForward = true

    var body: some View {
        VStack(alignment: .leading, spacing: Self.padding) {
            ZStack(alignment: .topLeading) {
                // Every step, hidden, so the window keeps the height of the
                // tallest one instead of jumping between steps.
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    content(for: step, isGranted: false, isVisible: false).hidden()
                }
                content(for: model.step, isGranted: model.isGranted, isVisible: true)
                    .id(model.step)
                    .transition(transition)
            }
            footer
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: model.step) {
            // Reset first: setting `true` again would not move focus. Set it
            // after the new step's title is in the view tree.
            isTitleFocused = false
            DispatchQueue.main.async { isTitleFocused = true }
        }
    }

    /// `isVisible` is false for the hidden copies that only set the height;
    /// only the visible title takes VoiceOver focus.
    private func content(for step: OnboardingStep, isGranted: Bool, isVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            visual(for: step, isGranted: isGranted)
                .frame(width: Self.visualSize, height: Self.visualSize)
                .accessibilityHidden(true)
            title(of: step, isVisible: isVisible)
            paragraphs(for: step, isGranted: isGranted)
            // A shortcut past the guide while the permission is missing.
            if step != .accessibility, !isGranted {
                Button(OnboardingText.openSettingsButton, action: openSettings)
                    .buttonStyle(.link)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func title(of step: OnboardingStep, isVisible: Bool) -> some View {
        let title = Text(step.title)
            .font(.title2.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
        if isVisible {
            title.accessibilityFocused($isTitleFocused)
        } else {
            title
        }
    }

    @ViewBuilder
    private func visual(for step: OnboardingStep, isGranted: Bool) -> some View {
        switch step {
        case .welcome:
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
        case .howToUse:
            symbol("command").foregroundStyle(.tint)
        case .accessibility where isGranted:
            symbol("checkmark.circle.fill").foregroundStyle(.green)
        case .accessibility:
            symbol("hand.raised").foregroundStyle(.tint)
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).resizable().scaledToFit()
    }

    @ViewBuilder
    private func paragraphs(for step: OnboardingStep, isGranted: Bool) -> some View {
        switch step {
        case .welcome:
            Text(OnboardingText.welcome)
        case .howToUse:
            Text(OnboardingText.holdCommand)
            Text(OnboardingText.pressCommandTwice)
        case .accessibility where isGranted:
            Text(OnboardingText.ready)
        case .accessibility:
            Text(OnboardingText.explanation)
            Text(OnboardingText.noData)
            Text(OnboardingText.instructions).foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(model.step.counter)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            let primary = model.step.primaryButton(isGranted: model.isGranted)
            // Done also closes, so Skip next to it would be a second Done.
            if primary == .done {
                escapeCloses
            } else {
                Button(OnboardingText.skipButton, action: close)
                    .keyboardShortcut(.cancelAction)
            }
            if model.step.showsBack, let previous = model.step.previous {
                Button(OnboardingText.backButton) { move(to: previous, forward: false) }
            }
            Button(primary.title) { perform(primary) }
                .keyboardShortcut(.defaultAction)
        }
    }

    /// Keeps Escape closing the window while Skip is not shown.
    private var escapeCloses: some View {
        Button(action: close) { EmptyView() }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }

    /// Slides 8 pt in the direction of travel while cross-fading; only
    /// cross-fades under Reduce Motion.
    private var transition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        let offset = movedForward ? Self.slide : -Self.slide
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: offset)),
            removal: .opacity.combined(with: .offset(x: -offset))
        )
    }

    private func perform(_ button: OnboardingStep.PrimaryButton) {
        switch button {
        case .continue:
            if let next = model.step.next {
                move(to: next, forward: true)
            }
        case .openSettings:
            openSettings()
        case .done:
            close()
        }
    }

    private func move(to step: OnboardingStep, forward: Bool) {
        movedForward = forward
        withAnimation(Self.stepAnimation) {
            model.step = step
        }
    }
}
