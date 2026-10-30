import Foundation

/// Everything the app keeps. One JSON file on this Mac; nothing ever leaves it.
public struct AppState: Codable, Equatable, Sendable {
    public var ledger = Ledger()
    public var rules = BlockRules.starter
    public var session: Session?
    public var minutes = 50

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case ledger, rules, session, minutes
    }

    /// Fields a future version adds fall back to their defaults, so an upgrade never reads an old file as corrupt.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ledger = try c.decodeIfPresent(Ledger.self, forKey: .ledger) ?? Ledger()
        rules = try c.decodeIfPresent(BlockRules.self, forKey: .rules) ?? .starter
        session = try c.decodeIfPresent(Session.self, forKey: .session)
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 50
    }
}

public struct Store: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// ~/Library/Application Support/Pizzeria/state.json
    public static var standard: Store {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Store(url: base.appendingPathComponent("Pizzeria/state.json"))
    }

    /// A file that can't be read is moved aside, never overwritten: the bank in it may still be recoverable by hand.
    public func load() -> AppState {
        guard let data = try? Data(contentsOf: url) else { return AppState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let state = try? decoder.decode(AppState.self, from: data) { return state }
        let aside = url.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: aside)
        return AppState()
    }

    public func save(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
