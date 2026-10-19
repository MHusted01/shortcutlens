import ShortcutLensCore
import SwiftUI

/// The Packs tab: how many packs are in use and which files failed to load.
struct PackSettings: View {
    let controller: SettingsController

    var body: some View {
        Section("Shortcut packs") {
            LabeledContent("Packs in use", value: "\(controller.packs.packs.count)")
            // By position: two files may report the same name and message.
            ForEach(Array(controller.packs.problems.enumerated()), id: \.offset) { _, problem in
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
}
