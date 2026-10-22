import CoreGraphics
import ShortcutLensCore
import Testing

struct ScreenPickerTests {
    /// A laptop screen with a larger external display to its right, top-aligned.
    private let screens = [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: 1512, y: -458, width: 2560, height: 1440),
    ]

    @Test func picksScreenContainingThePointer() {
        #expect(ScreenPicker.index(for: CGPoint(x: 700, y: 500), in: screens) == 0)
        #expect(ScreenPicker.index(for: CGPoint(x: 3000, y: -200), in: screens) == 1)
    }

    @Test func picksNearestScreenWhenPointerIsOnAnOuterEdge() {
        // NSEvent.mouseLocation can report y == maxY at the top edge.
        #expect(ScreenPicker.index(for: CGPoint(x: 700, y: 982), in: screens) == 0)
        #expect(ScreenPicker.index(for: CGPoint(x: 4072, y: 0), in: screens) == 1)
    }

    @Test func returnsNilWithoutScreens() {
        #expect(ScreenPicker.index(for: .zero, in: []) == nil)
    }

    @Test func centresFrameInVisibleArea() {
        let frame = ScreenPicker.centeredFrame(size: CGSize(width: 400, height: 200), in: screens[0])

        #expect(frame == CGRect(x: 556, y: 391, width: 400, height: 200))
    }

    @Test func shrinksFrameToTheVisibleArea() {
        let visible = CGRect(x: 1512, y: -458, width: 2560, height: 1400)

        let frame = ScreenPicker.centeredFrame(size: CGSize(width: 3000, height: 2000), in: visible)

        #expect(frame == visible)
    }

    @Test func roundsOriginToWholePoints() {
        let frame = ScreenPicker.centeredFrame(size: CGSize(width: 401, height: 201), in: screens[0])

        #expect(frame.origin == CGPoint(x: 555, y: 390))
    }
}
