import CoreGraphics

/// Picks the screen for the overlay and places it there. Works on plain
/// rectangles in AppKit's global coordinates, so it can be tested without
/// real screens.
public enum ScreenPicker {
    /// The index of the frame containing `point`, else of the nearest frame
    /// (the pointer can sit on an outer edge, which `contains` excludes).
    /// Nil only when `frames` is empty.
    public static func index(for point: CGPoint, in frames: [CGRect]) -> Int? {
        if let index = frames.firstIndex(where: { $0.contains(point) }) {
            return index
        }
        return frames.indices.min { distance(from: point, to: frames[$0]) < distance(from: point, to: frames[$1]) }
    }

    /// A frame of `size`, shrunk to fit `visible` and centred in it, with its
    /// origin on whole points so the panel is not blurry.
    public static func centeredFrame(size: CGSize, in visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        return CGRect(
            x: (visible.midX - width / 2).rounded(.down),
            y: (visible.midY - height / 2).rounded(.down),
            width: width,
            height: height
        )
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let horizontal = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let vertical = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (horizontal * horizontal + vertical * vertical).squareRoot()
    }
}
