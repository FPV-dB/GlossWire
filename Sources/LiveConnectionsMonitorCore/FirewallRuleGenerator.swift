import Foundation

public struct FirewallRuleGenerator: Sendable {
    public init() {}

    public func rules(for blockRules: [BlockRule], allowlist: [AllowlistEntry], settings: FirewallSettings) -> String {
        let allowed = Set(allowlist.filter(\.isEnabled).map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) })
        var lines = [
            "# Managed by GlossWire.",
            "# Dedicated PF anchor: \(settings.anchorName)",
            "# Do not place unrelated rules in this file.",
            ""
        ]
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
