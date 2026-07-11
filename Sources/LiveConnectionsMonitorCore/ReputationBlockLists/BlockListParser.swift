import Foundation

public struct BlockListParser: Sendable {
    public init() {}

    public func parse(_ text: String, subscription: BlockListSubscription) -> [ReputationRule] {
        var seen = Set<String>()
        var rules: [ReputationRule] = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = parseValue(from: line, type: subscription.listType), !seen.contains(value) else { continue }
            seen.insert(value)
            rules.append(ReputationRule(subscription: subscription, value: value, rawRule: line))
        }
        return rules
    }

    private func parseValue(from line: String, type: ReputationBlockListType) -> String? {
        guard !line.isEmpty else { return nil }
        if line.hasPrefix("#") || line.hasPrefix("!") || line.hasPrefix("[") { return nil }
        if line.contains("##") || line.contains("#@#") || line.contains("##+") { return nil }

        switch type {
        case .hosts:
            return parseHostsLine(line)
        case .domain:
            return normalizedDomain(line)
        case .url:
            return parseURLLike(line)
        case .ipList:
            return parseIPListLine(line)
        case .adblock:
            return parseAdblockLine(line)
        }
    }

    private func parseHostsLine(_ line: String) -> String? {
        let withoutComment = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? line
        let parts = withoutComment.split { $0 == " " || $0 == "\t" }.map(String.init)
        if parts.count >= 2, isAddressLike(parts[0]) {
            return normalizedDomain(parts[1])
        }
        return normalizedDomain(parts.first ?? "")
    }

    private func parseAdblockLine(_ line: String) -> String? {
        if line.hasPrefix("@@") { return nil }
        if line.hasPrefix("||") {
            let value = line.dropFirst(2).split { "|/^$*".contains($0) }.first.map(String.init) ?? ""
            return normalizedDomain(value)
        }
        if line.hasPrefix("|http://") || line.hasPrefix("|https://") {
            return parseURLLike(String(line.dropFirst()))
        }
        if line.hasPrefix("http://") || line.hasPrefix("https://") {
            return parseURLLike(line)
        }
        if line.contains("/") || line.contains("*") || line.contains("$") { return nil }
        return normalizedDomain(line)
    }

    private func parseURLLike(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        if let url = URL(string: trimmed), let host = url.host {
            return normalizedDomain(host)
        }
        return normalizedDomain(trimmed)
    }

    private func normalizedDomain(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: ".|^/"))
        if value.hasPrefix("www.") { value.removeFirst(4) }
        guard value.contains(".") || isAddressLike(value), value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == ":" }) else {
            return nil
        }
        return value
    }

    private func isAddressLike(_ value: String) -> Bool {
        value.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" } && value.contains(".")
    }

    private func parseIPListLine(_ line: String) -> String? {
        let withoutComment = line.split(separator: ";", maxSplits: 1).first.map(String.init) ?? line
        let tokens = withoutComment.split { $0 == " " || $0 == "\t" || $0 == "," }.map(String.init)
        for token in tokens {
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'[]()"))
            if isIPOrCIDR(trimmed) {
                return trimmed.lowercased()
            }
        }
        return nil
    }

    private func isIPOrCIDR(_ value: String) -> Bool {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 1 || parts.count == 2 else { return false }
        if parts.count == 2 {
            guard let prefix = Int(parts[1]), prefix >= 0, prefix <= (parts[0].contains(":") ? 128 : 32) else {
                return false
            }
        }
        return isIPv4(parts[0]) || isIPv6(parts[0])
    }

    private func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let octet = Int(part), octet >= 0, octet <= 255 else { return false }
            return String(octet) == part || part == "0"
        }
    }

    private func isIPv6(_ value: String) -> Bool {
        value.contains(":") && value.allSatisfy { $0.isHexDigit || $0 == ":" }
    }
}
