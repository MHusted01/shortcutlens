/// What character keys type on the current keyboard layout, by virtual key
/// code. The app translates the keys with the layout (`UCKeyTranslate`); Core
/// only keeps results that read as a key label. A key without a label falls
/// back to the stored character and then to the US table (`KeyCodes`).
public struct KeyLabels: Sendable {
    /// No layout known: every key falls back.
    public static let none = KeyLabels(labels: [:])

    private let labels: [Int: Character]

    private init(labels: [Int: Character]) {
        self.labels = labels
    }

    /// Asks `translate` for each key code. Nil, empty, multi-character,
    /// whitespace, control and private-use results are dropped, so the
    /// fallback applies to those keys.
    public init(keyCodes: some Sequence<Int>, translate: (Int) -> String?) {
        var labels: [Int: Character] = [:]
        for keyCode in keyCodes {
            if let label = translate(keyCode).flatMap(Self.label) {
                labels[keyCode] = label
            }
        }
        self.init(labels: labels)
    }

    public func label(for keyCode: Int) -> Character? {
        labels[keyCode]
    }

    private static func label(from text: String) -> Character? {
        guard text.count == 1, let character = text.first, !character.isWhitespace else {
            return nil
        }
        let hidden: Set<Unicode.GeneralCategory> = [.control, .privateUse, .format, .unassigned]
        let isHidden = character.unicodeScalars.contains { hidden.contains($0.properties.generalCategory) }
        return isHidden ? nil : character
    }
}
