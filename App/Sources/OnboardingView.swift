import ShortcutLensCore
import SwiftUI

/// Explains why ShortcutLens needs the Accessibility permission and links to
/// the matching System Settings pane.
struct OnboardingView: View {
    static let width: CGFloat = 440

    let openSettings: () -> Void
    let later: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(OnboardingText.title, systemImage: "keyboard")
                .font(.headline)
            Text(OnboardingText.explanation)
            Text(OnboardingText.noData)
            Text(OnboardingText.instructions)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(OnboardingText.laterButton, action: later)
                    .keyboardShortcut(.cancelAction)
                Button(OnboardingText.openSettingsButton, action: openSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: Self.width)
    }
}
