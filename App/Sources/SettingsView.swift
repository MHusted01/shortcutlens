import ServiceManagement
import ShortcutLensCore
import SwiftUI

/// The settings window's content. Every control writes through
/// `SettingsController`, which saves and applies the change at once.
struct SettingsView: View {
    private static let width: CGFloat = 380

    let controller: SettingsController

    var body: some View {
        Form {
            Section("Trigger") {
                LabeledContent("Hold Command for") {
                    HStack {
                        Slider(
                            value: binding(\.triggerDelay) { $0.with(triggerDelay: $1) },
                            in: AppSettings.triggerDelayRange,
                            step: AppSettings.triggerDelayStep
                        )
                        Text(controller.settings.triggerDelay, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                        Text("s")
                    }
                }
            }
            Section("Menus") {
                Stepper(
                    "Menu depth: \(controller.settings.maxMenuDepth)",
                    value: binding(\.maxMenuDepth) { $0.with(maxMenuDepth: $1) },
                    in: AppSettings.maxMenuDepthRange
                )
                Toggle(
                    "Show disabled items",
                    isOn: binding(\.showsDisabledItems) { $0.with(showsDisabledItems: $1) }
                )
            }
            Section("System") {
                Toggle(
                    "Show system shortcuts",
                    isOn: binding(\.showsSystemShortcuts) { $0.with(showsSystemShortcuts: $1) }
                )
            }
            packsSection
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLogin)
                launchAtLoginNote
            }
        }
        .formStyle(.grouped)
        .frame(width: Self.width)
        .fixedSize()
    }

    private var packsSection: some View {
        Section("Shortcut packs") {
            LabeledContent("Packs in use", value: "\(controller.packs.packs.count)")
            ForEach(controller.packs.problems, id: \.self) { problem in
                VStack(alignment: .leading) {
                    Text(problem.fileName)
                        .font(.callout.bold())
                    Text(problem.message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            if let error = controller.packsFolderError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            HStack {
                Button("Reload") { controller.reloadPacks() }
                Spacer()
                Button("Show Packs Folder") { controller.showPacksFolder() }
            }
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

    private func binding<Value>(
        _ keyPath: KeyPath<AppSettings, Value>,
        update: @escaping (AppSettings, Value) -> AppSettings
    ) -> Binding<Value> {
        Binding(
            get: { controller.settings[keyPath: keyPath] },
            set: { controller.update(update(controller.settings, $0)) }
        )
    }
}
