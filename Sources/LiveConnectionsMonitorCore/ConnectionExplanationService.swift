import Foundation

public struct ConnectionExplanation: Hashable, Sendable {
    public let headline: String
    public let explanation: String
    public let evidence: [String]
    public let confidence: String
}

public struct ConnectionExplanationService: Sendable {
    public init() {}

    public func explain(_ connection: NetworkConnection, safetyReport: IPSafetyReport? = nil) -> ConnectionExplanation {
        let process = connection.processName.isEmpty ? "This process" : connection.processName
        let port = connection.remote?.port ?? connection.local.port
        let service = Self.services[port]
        let processPurpose = purpose(for: process)
        let direction = directionText(connection.direction)
        var evidence: [String] = []

        if let service {
            evidence.append("Port \(port) is commonly used for \(service.name).")
        } else if !port.isEmpty {
            evidence.append("Port \(port) has no built-in common-service match.")
        }
        evidence.append("GlossWire observed a \(connection.protocolKind.rawValue) connection \(direction).")
        if !connection.state.isEmpty { evidence.append("macOS reported the state as \(connection.state).") }
        if let report = matching(report: safetyReport, connection: connection) {
            evidence.append("The current IP safety score is \(report.riskScore)/100 (\(report.riskLabel.rawValue)).")
            if let hostname = report.reverseDNS, !hostname.isEmpty { evidence.append("Reverse DNS: \(hostname).") }
            if let asn = report.asn, !asn.isEmpty { evidence.append("ASN/ISP: \(asn).") }
            if report.torExitNode == true { evidence.append("The address matched the Tor exit-node check.") }
        }

        let servicePhrase = service.map { "a \($0.name) connection" } ?? "a network connection"
        let purposePhrase = processPurpose.map { " \($0)" } ?? ""
        let remote = connection.remote.map { " to \($0.address)\($0.port.isEmpty ? "" : ":\($0.port)")" } ?? ""
        return ConnectionExplanation(
            headline: "\(process) is using \(service?.shortName ?? connection.protocolKind.rawValue)",
            explanation: "\(process) established \(servicePhrase)\(remote).\(purposePhrase) This is a local inference from visible metadata; encrypted payload contents are not inspected, so the exact application action cannot be proven.",
            evidence: evidence,
            confidence: service != nil && processPurpose != nil ? "High-confidence protocol match; purpose is inferred" : service != nil ? "Known port; application purpose is inferred" : "Low confidence"
        )
    }

    private func matching(report: IPSafetyReport?, connection: NetworkConnection) -> IPSafetyReport? {
        guard let report, report.ip == connection.remote?.address else { return nil }
        return report
    }

    private func directionText(_ direction: ConnectionDirection) -> String {
        switch direction {
        case .incoming: "inbound"
        case .outgoing: "outbound"
        case .listening: "while listening for inbound traffic"
        case .established: "in an established session"
        case .unknown: "with an undetermined direction"
        }
    }

    private func purpose(for process: String) -> String? {
        let name = process.lowercased()
        if name.contains("safari") || name.contains("chrome") || name.contains("firefox") || name.contains("arc") {
            return "For a web browser, likely reasons include loading a page, synchronization, extension traffic, updates, or safe-browsing checks."
        }
        if name.contains("dropbox") || name.contains("onedrive") || name.contains("drive") {
            return "For a cloud-storage client, this may be authentication, metadata exchange, or file synchronization."
        }
        if name.contains("steam") { return "For Steam, this may be authentication, store/community traffic, cloud saves, or a game/content download." }
        if name.contains("discord") || name.contains("slack") || name.contains("teams") {
            return "For a communications app, this may be messaging, presence, media, notifications, or voice/video setup."
        }
        if name.contains("softwareupdated") || name.contains("appstore") {
            return "For an update service, this is likely a catalogue, entitlement, or software-download request."
        }
        if name.contains("mdnsresponder") { return "This macOS service handles DNS resolution and Bonjour service discovery." }
        if name.contains("ssh") { return "For SSH, this is likely a remote shell, tunnel, or SFTP session." }
        return nil
    }

    private struct Service: Sendable {
        let shortName: String
        let name: String
    }

    private static let services: [String: Service] = [
        "20": Service(shortName: "FTP", name: "FTP data"),
        "21": Service(shortName: "FTP", name: "FTP control"),
        "22": Service(shortName: "SSH", name: "SSH or SFTP"),
        "23": Service(shortName: "Telnet", name: "Telnet"),
        "25": Service(shortName: "SMTP", name: "SMTP email delivery"),
        "53": Service(shortName: "DNS", name: "Domain Name System lookup"),
        "67": Service(shortName: "DHCP", name: "DHCP server"),
        "68": Service(shortName: "DHCP", name: "DHCP client"),
        "80": Service(shortName: "HTTP", name: "unencrypted web HTTP"),
        "123": Service(shortName: "NTP", name: "network time synchronization"),
        "143": Service(shortName: "IMAP", name: "IMAP email retrieval"),
        "443": Service(shortName: "HTTPS", name: "encrypted HTTPS"),
        "445": Service(shortName: "SMB", name: "SMB file sharing"),
        "465": Service(shortName: "SMTPS", name: "encrypted SMTP"),
        "587": Service(shortName: "SMTP", name: "authenticated email submission"),
        "993": Service(shortName: "IMAPS", name: "encrypted IMAP"),
        "995": Service(shortName: "POP3S", name: "encrypted POP3"),
        "3283": Service(shortName: "ARD", name: "Apple Remote Desktop administration"),
        "3389": Service(shortName: "RDP", name: "Microsoft Remote Desktop"),
        "3478": Service(shortName: "STUN/TURN", name: "real-time media NAT traversal"),
        "5223": Service(shortName: "APNs", name: "Apple Push Notification service"),
        "5353": Service(shortName: "mDNS", name: "Bonjour multicast DNS discovery"),
        "5900": Service(shortName: "VNC", name: "VNC or macOS Screen Sharing")
    ]
}
