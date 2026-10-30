import XCTest
@testable import DoughCore

final class StoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private var store: Store { Store(url: dir.appendingPathComponent("nested/state.json")) }

    func testNoFileIsAFreshStart() {
        XCTAssertEqual(store.load(), AppState())
    }

    func testAStateComesBackAsItWent() throws {
        var state = AppState()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        state.ledger = Ledger(bank: 120, entries: [Entry(startedAt: now, endedAt: now, minutes: 25, completed: true)])
        state.session = Session(minutes: 50, rules: .starter, now: now)
        state.stakeBank = true
        try store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testFieldsMissingFromAnOldFileFallBack() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"ledger":{"bank":7,"entries":[]}}"#.utf8).write(to: store.url)
        let state = store.load()
        XCTAssertEqual(state.ledger.bank, 7)
        XCTAssertEqual(state.minutes, 50)
    }

    func testACorruptFileIsMovedAsideNotLost() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        XCTAssertEqual(store.load(), AppState())
        let left = try FileManager.default.contentsOfDirectory(atPath: store.url.deletingLastPathComponent().path)
        XCTAssertEqual(left.count, 1)
        XCTAssertTrue(left[0].contains("corrupt"))
    }
}
