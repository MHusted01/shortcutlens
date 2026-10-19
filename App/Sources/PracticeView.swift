import ShortcutLensCore
import SwiftUI

/// The practice window: one menu item at a time with its keys hidden, a
/// field that takes the answer, the result, and the score at the end.
struct PracticeView: View {
    private static let width: CGFloat = 380
    private static let recorderHeight: CGFloat = 32

    let practice: PracticeController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch practice.state {
            case .reading:
                ProgressView("Reading the menus of \(practice.appName)…")
                    .frame(maxWidth: .infinity)
            case .empty:
                Text("\(practice.appName) has no menu shortcuts to practise.")
                actions
            case .practising:
                content
                actions
            }
        }
        .padding(20)
        .frame(width: Self.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var content: some View {
        let session = practice.session
        if let card = session.current {
            VStack(alignment: .leading, spacing: 4) {
                Text("Question \(session.position) of \(session.count)").foregroundStyle(.secondary)
                Text(card.prompt).font(.headline)
            }
            if session.phase == .asking {
                recorder
            } else {
                result(session.phase, card: card)
            }
        } else {
            Text("\(session.correctCount) of \(session.count) right").font(.headline)
            if !practice.savesProgress {
                Text("\(practice.appName) has no bundle identifier, so progress is not saved.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recorder: some View {
        ZStack {
            KeyRecorder { practice.answer($0) }
                // A new field per question, so it takes the focus again.
                .id(practice.session.position)
            Text("Press the shortcut").foregroundStyle(.secondary).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.recorderHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
        .accessibilityElement()
        .accessibilityLabel("Answer")
        .accessibilityValue("Press the shortcut")
    }

    @ViewBuilder
    private func result(_ phase: PracticeSession.Phase, card: PracticeCard) -> some View {
        switch phase {
        case .correct:
            Label("Right: \(card.keys)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case let .wrong(pressed):
            Label(Self.wrongAnswer(pressed: pressed, answer: card.keys), systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .revealed:
            Text("The answer is \(card.keys).")
        case .asking, .finished:
            EmptyView()
        }
    }

    private static func wrongAnswer(pressed: String?, answer: String) -> String {
        guard let pressed else {
            return String(localized: "Not quite. The answer is \(answer).")
        }
        return String(localized: "Not quite: you pressed \(pressed). The answer is \(answer).")
    }

    private var actions: some View {
        HStack {
            let phase = practice.session.phase
            if practice.state == .practising, phase == .finished, practice.hasProgress {
                Button("Reset Progress") { practice.resetProgress() }
            }
            Spacer()
            if practice.state != .practising {
                Button("Done") { practice.close() }
                    .keyboardShortcut(.defaultAction)
            } else if phase == .asking {
                Button("Show Answer") { practice.reveal() }
            } else if phase == .finished {
                Button("Done") { practice.close() }
                    .keyboardShortcut(.cancelAction)
                Button("Practise Again") { practice.practiseAgain() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") { practice.next() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
