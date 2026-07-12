import Foundation

public struct FirewallRuleGenerator: Sendable {
    public init() {}

    public func rules(for blockRules: [BlockRule], allowlist: [AllowlistEntry], settings: FirewallSettings) -> String {
        if settings.isBlockingPaused {
            return """
            # Managed by GlossWire.
            # EMERGENCY PAUSE: all GlossWire blocking is temporarily disabled.
            # Saved rules and settings have not been deleted.

            """
        }
        let allowed = Set(allowlist.filter(\.isEnabled).map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) })
        var lines = [
            "# Managed by GlossWire.",
            "# Dedicated PF anchor: \(settings.anchorName)",
            "# Do not place unrelated rules in this file.",
            ""
        ]
        if settings.internetKillSwitchEnabled {
            lines.append(contentsOf: [
                "# INTERNET KILL SWITCH: preserve loopback, LAN, multicast, and broadcast; isolate public networks.",
                "pass quick on lo0 all",
                "pass in quick inet from 10.0.0.0/8",
                "pass out quick inet to 10.0.0.0/8",
                "pass in quick inet from 172.16.0.0/12",
                "pass out quick inet to 172.16.0.0/12",
                "pass in quick inet from 192.168.0.0/16",
                "pass out quick inet to 192.168.0.0/16",
                "pass in quick inet from 169.254.0.0/16",
                "pass out quick inet to 169.254.0.0/16",
                "pass in quick inet from 224.0.0.0/4",
                "pass out quick inet to 224.0.0.0/4",
                "pass out quick inet to 255.255.255.255",
                "pass in quick inet6 from fc00::/7",
                "pass out quick inet6 to fc00::/7",
                "pass in quick inet6 from fe80::/10",
                "pass out quick inet6 to fe80::/10",
                "pass in quick inet6 from ff00::/8",
                "pass out quick inet6 to ff00::/8",
                "block drop out quick all",
                "block drop in quick inet from any",
                "block drop in quick inet6 from any",
                ""
            ])
        }
        let blockedServices = NetworkServiceBlockPreset.allCases.filter { settings.blockedServiceIDs.contains($0.id) }
        if !blockedServices.isEmpty {
            lines.append("# Blocked Network Services")
            for service in blockedServices {
                lines.append("# \(service.name)")
                lines.append(contentsOf: service.pfRules)
            }
            lines.append("")
        }
        if !allowed.isEmpty {
            lines.append("# \(FirewallRuleGroup.trustedAllowlist.rawValue)")
            for value in allowed.sorted() where !value.isEmpty {
                lines.append("pass in quick from \(value)")
                lines.append("pass out quick to \(value)")
            }
            lines.append("")
        }
        for group in FirewallRuleGroup.allCases where group != .trustedAllowlist {
            let groupRules = blockRules.filter {
                $0.group == group && $0.isEnabled
                    && !allowed.contains($0.value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            guard !groupRules.isEmpty else { continue }
            lines.append("# \(group.rawValue)")
            for rule in groupRules.sorted(by: { $0.value < $1.value }) {
                switch rule.direction {
                case .inbound:
                    lines.append("block drop in quick from \(rule.value)")
                case .outbound:
                    lines.append("block drop out quick to \(rule.value)")
                case .both:
                    lines.append("block drop in quick from \(rule.value)")
                    lines.append("block drop out quick to \(rule.value)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
