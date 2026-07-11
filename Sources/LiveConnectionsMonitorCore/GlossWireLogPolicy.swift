import Foundation

public enum GlossWireLogPolicy {
    public static let defaultsKey = "logging.disableAll"
    public static var isDisabled: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }
}
