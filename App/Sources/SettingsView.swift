import ServiceManagement
import ShortcutLensCore
import SwiftUI

/// One tab of the settings window. Every control writes through
/// `SettingsController`, which saves and applies the change at once.
struct SettingsView: View {
    private static let width: CGFloat = 450

    let tab: SettingsTab
    let controller: SettingsController

    var body: some View {
        Form {
            switch tab {
            case .general: GeneralSettings(controller: controller)
            case .overlay: OverlaySettings(controller: controller)
            case .packs: PackSettings(controller: controller)
            case .advanced: AdvancedSettings(controller: controller)
            }
        }
        .formStyle(.grouped)
        .frame(width: Self.width)
        .fixedSize()
    }
}

private struct GeneralSettings: View {
    let controller: SettingsController

    var body: some View {
        Section("Trigger") {
            LabeledContent("Hold Command for") {
                HStack {
                    Slider(
                        value: controller.binding(\.triggerDelay) { $0.with(triggerDelay: $1) },
                        in: AppSettings.triggerDelayRange,
                        step: AppSettings.triggerDelayStep
                    )
                    Text(controller.settings.triggerDelay, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text("s")
                }
            }
        }
        Section("Startup") {
            Toggle("Launch at login", isOn: launchAtLogin)
            launchAtLoginNote
        }
    }

    @ViewBuilder private var launchAtLoginNote: some View {
        if let error = controller.launchAtLoginError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        } else if controller.launchAtLogin == .requiresApproval {
            HStack {
                Text("Allow ShortcutLens in Login Items.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Login Items") { controller.openLoginItemsSettings() }
            }
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { controller.launchAtLogin == .enabled || controller.launchAtLogin == .requiresApproval },
            set: { controller.setLaunchAtLogin($0) }
        )
    }
}

private struct OverlaySettings: View {
    let controller: SettingsController

    var body: some View {
        Section {
            Toggle(
                "Show disabled items",
                isOn: controller.binding(\.showsDisabledItems) { $0.with(showsDisabledItems: $1) }
            )
            Toggle(
                "Show system shortcuts",
                isOn: controller.binding(\.showsSystemShortcuts) { $0.with(showsSystemShortcuts: $1) }
            )
        }
    }
}

private struct AdvancedSettings: View {
    let controller: SettingsController

    var body: some View {
        Section("Menus") {
            Stepper(
                "Menu depth: \(controller.settings.maxMenuDepth)",
                value: controller.binding(\.maxMenuDepth) { $0.with(maxMenuDepth: $1) },
                in: AppSettings.maxMenuDepthRange
            )
        }
    }
}

private extension SettingsController {
    /// A binding to one setting; `update` returns the settings with the new value.
    func binding<Value>(
        _ keyPath: KeyPath<AppSettings, Value>,
        update: @escaping (AppSettings, Value) -> AppSettings
    ) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { self.update(update(self.settings, $0)) }
        )
    }
}
