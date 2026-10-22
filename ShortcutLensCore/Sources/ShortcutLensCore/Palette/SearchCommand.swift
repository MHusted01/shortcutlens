/// A key the palette's search field handles itself instead of editing the text.
public enum SearchCommand: Sendable {
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case submit
    case cancel
}
