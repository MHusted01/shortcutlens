import ShortcutLensCore
import Testing

struct PaletteAnnouncementTests {
    typealias State = PaletteState<Int>

    /// Favourites (pinned): Save; File: Save, Open.
    private static let content = OverlayContent(appName: "TextEdit", sections: [
        OverlaySection(id: 0, title: "Favourites", rows: [
            OverlayRow(id: 0, title: "Save", keys: "⌘S", isFavourite: true, element: 0),
        ], isPinned: true),
        OverlaySection(id: 1, title: "File", rows: [
            OverlayRow(id: 0, title: "Save", keys: "⌘S", isFavourite: true, element: 0),
            OverlayRow(id: 1, title: "Open", keys: "⌘O", element: 1),
        ]),
    ])

    private static let loaded = State().with(content: content)

    @Test func rowLabelSpellsOutTheKeys() {
        let row = OverlayRow(id: 0, title: "Save As…", keys: "⇧⌘S", element: 0)

        #expect(PaletteAnnouncement.rowLabel(row, inPinnedSection: false) == "Save As…, Shift Command S")
    }

    @Test func rowLabelAddsFavouriteCustomAndConflict() {
        let row = OverlayRow(
            id: 0, title: "Find", keys: "⌘F", isCustom: true, isFavourite: true,
            conflict: "Also used by System > Spotlight", element: 0
        )

        #expect(
            PaletteAnnouncement.rowLabel(row, inPinnedSection: false)
                == "Find, Command F, favourite, custom shortcut, Also used by System > Spotlight"
        )
    }

    @Test func rowLabelLeavesOutFavouriteInThePinnedSection() {
        let row = OverlayRow(id: 0, title: "Save", keys: "⌘S", isFavourite: true, element: 0)

        #expect(PaletteAnnouncement.rowLabel(row, inPinnedSection: true) == "Save, Command S")
    }

    @Test func rowLabelLeavesOutEmptyKeys() {
        let row = OverlayRow(id: 0, title: "Save", keys: "", isCustom: true, element: 0)

        #expect(PaletteAnnouncement.rowLabel(row, inPinnedSection: false) == "Save, custom shortcut")
    }

    @Test func openingWhileLoadingSaysNothing() {
        #expect(PaletteAnnouncement.text(from: nil, to: State()) == nil)
    }

    @Test func openingWithContentNamesTheAppAndCount() {
        #expect(PaletteAnnouncement.text(from: nil, to: Self.loaded) == "TextEdit, 3 shortcuts")
    }

    @Test func finishedReadNamesTheAppAndCount() {
        #expect(PaletteAnnouncement.text(from: State(), to: Self.loaded) == "TextEdit, 3 shortcuts")
    }

    @Test func movingSaysTheSelectedRow() {
        let moved = Self.loaded.movingSelection(by: 1)

        #expect(PaletteAnnouncement.text(from: Self.loaded, to: moved) == "Save, Command S, favourite")
    }

    @Test func pinnedRowLeavesOutFavourite() {
        let wrapped = Self.loaded.movingSelection(by: 1).movingSelection(by: 2)

        #expect(PaletteAnnouncement.text(from: Self.loaded.movingSelection(by: 1), to: wrapped) == "Save, Command S")
    }

    @Test func typingSaysTheMatchCount() {
        #expect(PaletteAnnouncement.text(from: Self.loaded, to: Self.loaded.with(query: "op")) == "1 shortcut")
        #expect(PaletteAnnouncement.text(from: Self.loaded, to: Self.loaded.with(query: "s")) == "2 shortcuts")
    }

    @Test func typingWithoutMatchesSaysSo() {
        let state = Self.loaded.with(query: "zzz")

        #expect(PaletteAnnouncement.text(from: Self.loaded, to: state) == "No matching shortcuts")
    }

    @Test func noChangeSaysNothing() {
        #expect(PaletteAnnouncement.text(from: Self.loaded, to: Self.loaded) == nil)
    }
}
