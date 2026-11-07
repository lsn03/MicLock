import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private let keepOpenKey = "keepMenuOpenAfterSelection"
    private let autoCloseKey = "autoCloseSeconds"

    var keepMenuOpenAfterSelection: Bool {
        get { defaults.object(forKey: keepOpenKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: keepOpenKey) }
    }

    var autoCloseSeconds: TimeInterval {
        get { defaults.object(forKey: autoCloseKey) as? Double ?? 30.0 }
        set { defaults.set(newValue, forKey: autoCloseKey) }
    }
}
