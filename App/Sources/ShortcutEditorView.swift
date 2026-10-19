import ShortcutLensCore
import SwiftUI

/// The edit window: the item, a field that records the new keys, problems and
/// conflicts, and the actions. After a change it tells the user to relaunch
/// the app, which only reads App Shortcuts when it starts.
struct ShortcutEditorView: View {
    private static let width: CGFloat = 380
    private static let recorderHeight: CGFloat = 32
    /// macOS handles its own active shortcuts before any app sees the keys.
    private static let systemShortcutHint = """
    Shortcuts macOS uses can't be recorded. Turn them off in System Settings > Keyboard > \
    Keyboard Shortcuts first.
    """

    let editor: ShortcutEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let request = editor.request {
                header(request)
                if let reason = editor.unavailableReason {
                    Text(reason).foregroundStyle(.secondary)
                } else if editor.status == .editing {
                    recorder
                    messages
                    Text(Self.systemShortcutHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    outcome(request)
                }
                actions
            }
        }
        .padding(20)
        .frame(width: Self.width, alignment: .leading)
    }

    private func header(_ request: ShortcutEditRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.title).font(.headline)
            Text(request.menuPath.joined(separator: " › ")).foregroundStyle(.secondary)
            Text("Current: \(request.currentKeys)").foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var recorder: some View {
        ZStack {
            KeyRecorder { editor.record($0) }
            Text(editor.recordedLabel ?? "Press the new shortcut")
                .foregroundStyle(editor.recorded == nil ? .secondary : .primary)
                .monospacedDigit()
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.recorderHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
        .accessibilityElement()
        .accessibilityLabel("New shortcut")
        .accessibilityValue(editor.recordedLabel ?? "None")
    }

    @ViewBuilder
    private var messages: some View {
        if let problem = editor.problem {
            Text(problem.message).foregroundStyle(.red)
        } else if let conflict = editor.conflict {
            Label(conflict, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func outcome(_ request: ShortcutEditRequest) -> some View {
        switch editor.status {
        case .saved:
            Text("Saved. Quit and reopen \(request.appName) to use \(editor.recordedLabel ?? "it").")
        case .removed:
            Text("Removed. Quit and reopen \(request.appName) to use the default shortcut.")
        case .failed:
            Text("The shortcut could not be saved.").foregroundStyle(.red)
        case .editing:
            EmptyView()
        }
    }

    private var actions: some View {
        HStack {
            if editor.status == .editing, editor.hasCustomEntry {
                Button("Remove Custom Shortcut") { editor.removeCustomShortcut() }
            }
            Spacer()
            if editor.status == .editing, editor.unavailableReason == nil {
                Button("Cancel") { editor.close() }
                    .keyboardShortcut(.cancelAction)
                Button(editor.conflict == nil ? "Save" : "Save Anyway") { editor.save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.canSave)
            } else {
                Button("Done") { editor.close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
