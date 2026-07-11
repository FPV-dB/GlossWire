import Foundation

public enum ReputationBlockListCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case `default` = "Default"
    case ads = "Ads"
    case privacy = "Privacy"
    case malwareSecurity = "Malware protection, security"
    case annoyances = "Annoyances"
    case attacks = "FireHOL · Attacks"
    case abuse = "FireHOL · Abuse"
    case anonymizers = "FireHOL · Anonymizers"
    case organizations = "FireHOL · Organizations"
    case reputation = "FireHOL · Reputation"
    case spam = "FireHOL · Spam"
    case malware = "FireHOL · Malware"
    case unroutable = "FireHOL · Unroutable"
    case geolocation = "FireHOL · Geolocation"
    case miscellaneous = "Miscellaneous"

    public var id: String { rawValue }
}

public enum ReputationBlockListType: String, CaseIterable, Codable, Identifiable, Sendable {
    case hosts
    case adblock
    case domain
    case url
    case ipList

    public var id: String { rawValue }
}

public struct BlockListSubscription: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: ReputationBlockListCategory
    public let url: URL
    public let description: String
    public let isEnabledByDefault: Bool
    public let localCachePath: String
    public let lastUpdated: Date?
    public let listType: ReputationBlockListType

    public init(
        id: String,
        name: String,
        category: ReputationBlockListCategory,
        url: URL,
        description: String,
        isEnabledByDefault: Bool,
        localCachePath: String,
        lastUpdated: Date? = nil,
        listType: ReputationBlockListType
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.url = url
        self.description = description
        self.isEnabledByDefault = isEnabledByDefault
        self.localCachePath = localCachePath
        self.lastUpdated = lastUpdated
        self.listType = listType
    }

    public func with(lastUpdated: Date?) -> BlockListSubscription {
        BlockListSubscription(
            id: id,
            name: name,
            category: category,
            url: url,
            description: description,
            isEnabledByDefault: isEnabledByDefault,
            localCachePath: localCachePath,
            lastUpdated: lastUpdated,
            listType: listType
        )
    }
}

public enum ReputationSeverity: String, Codable, CaseIterable, Identifiable, Sendable {
    case info
    case privacy
    case adTracker = "ad/tracker"
    case malwareSecurity = "malware/security"

    public var id: String { rawValue }
}

public struct ReputationRule: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let subscriptionID: String
    public let listName: String
    public let category: ReputationBlockListCategory
    public let severity: ReputationSeverity
    public let listType: ReputationBlockListType
    public let value: String
    public let rawRule: String

    public init(
        subscription: BlockListSubscription,
        value: String,
        rawRule: String
    ) {
        self.id = "\(subscription.id):\(value):\(rawRule.hashValue)"
        self.subscriptionID = subscription.id
        self.listName = subscription.name
        self.category = subscription.category
        self.severity = Self.severity(for: subscription.category)
        self.listType = subscription.listType
        self.value = value
        self.rawRule = rawRule
    }

    private static func severity(for category: ReputationBlockListCategory) -> ReputationSeverity {
        switch category {
        case .ads, .annoyances:
            return .adTracker
        case .privacy:
            return .privacy
        case .malwareSecurity, .attacks, .abuse, .reputation, .spam, .malware:
            return .malwareSecurity
        case .anonymizers:
            return .privacy
        case .default, .organizations, .unroutable, .geolocation, .miscellaneous:
            return .info
        }
    }
}

public struct ReputationMatch: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let listName: String
    public let matchedRule: String
    public let matchedValue: String
    public let category: ReputationBlockListCategory
    public let severity: ReputationSeverity

    public init(rule: ReputationRule) {
        self.listName = rule.listName
        self.matchedRule = rule.rawRule
        self.matchedValue = rule.value
        self.category = rule.category
        self.severity = rule.severity
    }
}

public enum ReputationBlockListCatalog {
    public static let subscriptions: [BlockListSubscription] = [
        item("easylist", "EasyList", .default, "https://easylist.to/easylist/easylist.txt", "General web advertising filters.", true, .adblock),
        item("easyprivacy", "EasyPrivacy", .default, "https://easylist.to/easylist/easyprivacy.txt", "Privacy and tracking protection filters.", true, .adblock),
        item("peter-lowe", "Peter Lowe - Ads, trackers, and more", .default, "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext", "Hosts-style ad and tracker domains.", true, .hosts),
        item("ublock-filters", "uBlock filters - Ads, trackers, and more", .default, "https://ublockorigin.github.io/uAssets/filters/filters.txt", "uBlock Origin default network filters.", true, .adblock),
        item("mobile-ads", "AdGuard/uBO - Mobile Ads", .ads, "https://ublockorigin.github.io/uAssets/filters/mobile.txt", "Mobile ad network filters.", false, .adblock),
        item("url-tracking", "AdGuard/uBO - URL Tracking Protection", .privacy, "https://ublockorigin.github.io/uAssets/filters/privacy.txt", "URL tracking and privacy filters.", false, .adblock),
        item("lan-block", "Block Outsider Intrusion into LAN", .privacy, "https://ublockorigin.github.io/uAssets/filters/lan-block.txt", "Rules intended to reduce outsider LAN intrusion patterns.", false, .adblock),
        item("badware", "uBlock filters - Badware risks", .malwareSecurity, "https://ublockorigin.github.io/uAssets/filters/badware.txt", "Badware and risky destination filters.", true, .adblock),
        item("urlhaus", "Malicious URL Blocklist", .malwareSecurity, "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-online.txt", "URLHaus-backed malicious URL filters.", true, .adblock),
        item("spamhaus-drop", "Spamhaus DROP", .malwareSecurity, "https://www.spamhaus.org/drop/drop.txt", "High-confidence netblocks used by spam and cyber-crime operations.", false, .ipList),
        item("dshield", "DShield Recommended Block List", .malwareSecurity, "https://www.dshield.org/block.txt", "Top attacking /24 networks observed by SANS ISC over recent days.", false, .ipList),
        item("feodo-tracker", "abuse.ch Feodo Tracker C2 IPs", .malwareSecurity, "https://feodotracker.abuse.ch/downloads/ipblocklist.txt", "Botnet command-and-control IP addresses tracked by abuse.ch.", false, .ipList),
        item("firehol-ipsum-3", "FireHOL IPsum Level 3", .malwareSecurity, "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ipsum_3.netset", "Aggregated IPs that appear on at least three public threat lists.", false, .ipList),
        item("firehol-ipsum-4", "FireHOL IPsum Level 4", .malwareSecurity, "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ipsum_4.netset", "More conservative IPsum feed: IPs appearing on at least four public threat lists.", false, .ipList),
        item("cins-army", "CINS Army", .malwareSecurity, "https://cinsscore.com/list/ci-badguys.txt", "Community threat-intelligence IP list from CINS/Nomic.", false, .ipList),
        item("binary-defense-artillery", "Binary Defense Artillery", .malwareSecurity, "https://binarydefense.com/banlist.txt", "Honeypot-observed attacker IP feed. Review provider terms before redistribution/commercial use.", false, .ipList),
        item("bitwire-malicious-outbound", "Bitwire IT · Malicious Outbound Destinations", .malwareSecurity, "https://raw.githubusercontent.com/bitwire-it/ipblocklist/main/outbound.txt", "Aggregated malicious destination, C2, botnet and malware infrastructure feed. Updated about every two hours; data licensed CC BY-NC-SA 4.0 by its maintainer.", false, .ipList),
        item("ai-widgets", "EasyList - AI Widgets", .annoyances, "https://easylist-downloads.adblockplus.org/ai.txt", "AI widget annoyance filters.", false, .adblock),
        item("cookie-notices", "EasyList/uBO - Cookie Notices", .annoyances, "https://ublockorigin.github.io/uAssets/filters/cookies.txt", "Cookie notice filters.", false, .adblock),
        item("notifications", "EasyList - Notifications", .annoyances, "https://easylist-downloads.adblockplus.org/notifications.txt", "Notification prompt filters.", false, .adblock),
        item("other-annoyances", "EasyList - Other Annoyances", .annoyances, "https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt", "General annoyance filters.", false, .adblock),
        item("overlay-notices", "EasyList/uBO - Overlay Notices", .annoyances, "https://ublockorigin.github.io/uAssets/filters/annoyances-overlays.txt", "Overlay notice filters.", false, .adblock),
        item("social-widgets", "EasyList - Social Widgets", .annoyances, "https://easylist-downloads.adblockplus.org/fanboy-social.txt", "Social widget filters.", false, .adblock),
        item("chat-widgets", "EasyList - Chat Widgets", .annoyances, "https://easylist-downloads.adblockplus.org/fanboy-cookiemonster.txt", "Chat widget filters.", false, .adblock),
        item("dan-pollock", "Dan Pollock's hosts file", .miscellaneous, "https://someonewhocares.org/hosts/hosts", "Curated hosts-file style blocklist.", false, .hosts),
        item("experimental", "uBlock filters - Experimental", .miscellaneous, "https://ublockorigin.github.io/uAssets/filters/experimental.txt", "Experimental uBlock filters.", false, .adblock),
        item("ubo-lite", "uBO Lite Test Filters", .miscellaneous, "https://ublockorigin.github.io/uAssets/filters/ubo-lite.txt", "uBO Lite test filters.", false, .adblock)
    ]

    private static func item(
        _ id: String,
        _ name: String,
        _ category: ReputationBlockListCategory,
        _ url: String,
        _ description: String,
        _ enabled: Bool,
        _ type: ReputationBlockListType
    ) -> BlockListSubscription {
        BlockListSubscription(
            id: id,
            name: name,
            category: category,
            url: URL(string: url)!,
            description: description,
            isEnabledByDefault: enabled,
            localCachePath: "\(id).txt",
            listType: type
        )
    }
}
