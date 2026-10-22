import Foundation

/// The tabs of the settings window, in toolbar order. The window opens on the
/// tab the user last chose; it is stored by name, so reordering keeps it.
public enum SettingsTab: String, CaseIterable, Sendable {
    case general
    case overlay
    case packs
    case advanced

    /// The store key of the last chosen tab.
    public static let storeKey = "settingsTab"

    /// The last chosen tab in `store`, or General if none is stored or the
    /// stored one no longer exists.
    public init(store: SettingsStore) {
        self = (store.object(forKey: Self.storeKey) as? String).flatMap(Self.init(rawValue:)) ?? .general
    }

    public func save(to store: SettingsStore) {
        store.set(rawValue, forKey: Self.storeKey)
    }

    /// The tab's label, also the window title while it is shown.
    public var title: String {
        switch self {
        case .general: String(localized: "General", bundle: .module)
        case .overlay: String(localized: "Overlay", bundle: .module)
        case .packs: String(localized: "Packs", bundle: .module)
        case .advanced: String(localized: "Advanced", bundle: .module)
        }
    }

    /// The SF Symbol shown above the label.
    public var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .overlay: "rectangle.grid.2x2"
        case .packs: "shippingbox"
        case .advanced: "slider.horizontal.3"
        }
    }
}
