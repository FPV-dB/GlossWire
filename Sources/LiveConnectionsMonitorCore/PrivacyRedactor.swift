import Foundation

public enum PrivacyRedactor {
    public static func process(_ value: String, enabled: Bool) -> String {
        enabled ? "Application" : value
    }

    public static func address(_ value: String?, enabled: Bool) -> String {
        guard let value, !value.isEmpty else { return "-" }
        guard enabled else { return value }
        if value.contains(":") { return "xxxx:…:xxxx" }
        let parts = value.split(separator: ".")
        if parts.count == 4 { return "\(parts[0]).\(parts[1]).x.x" }
        return "redacted"
    }

    public static func hostname(_ value: String?, enabled: Bool) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return enabled ? "hidden.example" : value
    }

    public static func path(_ value: String?, enabled: Bool) -> String? {
        guard let value else { return nil }
        return enabled ? "~/…/Application" : value
    }
}
