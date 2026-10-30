import Foundation

/// How a list is read: ignored, a deny list, or an allow list.
public enum ListMode: String, Codable, CaseIterable, Sendable {
    case off, block, only
}

/// What a session blocks. A session keeps its own copy from the moment it starts, so nothing can be let through later.
public struct BlockRules: Codable, Equatable, Sendable {
    public var appMode: ListMode
    /// Bundle identifiers.
    public var apps: [String]
    public var siteMode: ListMode
    /// Hosts. A site covers its subdomains: "youtube.com" covers "m.youtube.com".
    public var sites: [String]

    public init(appMode: ListMode = .off, apps: [String] = [], siteMode: ListMode = .off, sites: [String] = []) {
        self.appMode = appMode
        self.apps = apps
        self.siteMode = siteMode
        self.sites = sites
    }

    /// What a new install starts with, so the first session blocks something.
    public static let starter = BlockRules(
        siteMode: .block,
        sites: ["youtube.com", "reddit.com", "x.com", "instagram.com", "tiktok.com"]
    )

    /// Never blocked: hiding these locks the user out of the Mac rather than out of a distraction.
    public static let alwaysAllowed: Set<String> = [
        "com.apple.finder", "com.apple.systempreferences", "com.apple.SystemSettings", "com.apple.loginwindow",
        "com.apple.dock", "com.apple.controlcenter", "com.apple.Spotlight", "com.apple.ScreenSaver.Engine",
        "com.apple.SecurityAgent",
    ]

    public func allowsApp(_ bundleID: String?) -> Bool {
        guard let id = bundleID, !Self.alwaysAllowed.contains(id) else { return true }
        switch appMode {
        case .off: return true
        case .block: return !apps.contains(id)
        case .only: return apps.contains(id)
        }
    }

    /// Whether a browser may show `address`, what its address bar reads. Text being typed, a search or a browser's own
    /// page is never blocked; what it leads to is.
    public func allowsSite(_ address: String) -> Bool {
        guard siteMode != .off, let host = Sites.host(of: address) else { return true }
        let listed = sites.compactMap(Sites.host(of:)).contains { host == $0 || host.hasSuffix("." + $0) }
        return siteMode == .only ? listed : !listed
    }
}

public enum Sites {
    /// "https://www.YouTube.com:443/watch?v=1" → "youtube.com"; nil for text that isn't an address.
    public static func host(of address: String) -> String? {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.isEmpty || s.contains(where: \.isWhitespace) { return nil }
        if let scheme = s.range(of: "://") {
            let name = s[..<scheme.lowerBound]
            if name != "http" && name != "https" { return nil }
            s = String(s[scheme.upperBound...])
        } else if s.hasPrefix("about:") || s.hasPrefix("chrome:") || s.hasPrefix("view-source:") {
            return nil
        }
        for mark in ["/", "?", "#"] { s = before(mark, in: s) }
        if let at = s.lastIndex(of: "@") { s = String(s[s.index(after: at)...]) }
        s = before(":", in: s)
        if !s.contains(".") || s.hasPrefix(".") || s.hasSuffix(".") { return nil }
        if s.contains(where: { !($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }) { return nil }
        return s.hasPrefix("www.") ? String(s.dropFirst(4)) : s
    }

    /// A text box's contents, one site per line, comma or space, as hosts.
    public static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .compactMap { host(of: String($0)) }
            .filter { seen.insert($0).inserted }
    }

    private static func before(_ mark: String, in text: String) -> String {
        text.range(of: mark).map { String(text[..<$0.lowerBound]) } ?? text
    }
}
