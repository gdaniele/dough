import XCTest
@testable import PanificioCore

final class SessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func watched(minutes: Int, for seconds: Int) -> Session {
        var s = Session(minutes: minutes, rules: BlockRules(), now: start)
        for i in 1 ... seconds { s.tick(now: start.addingTimeInterval(TimeInterval(i))) }
        return s
    }

    func testAPointForEveryWholeMinuteWatched() {
        XCTAssertEqual(watched(minutes: 25, for: 59).earned, 0)
        XCTAssertEqual(watched(minutes: 25, for: 60).earned, 1)
        XCTAssertEqual(watched(minutes: 25, for: 601).earned, 10)
    }

    func testItFinishesAtItsEndAndEarnsNoMore() {
        let s = watched(minutes: 5, for: 305)
        XCTAssertTrue(s.finished)
        XCTAssertEqual(s.earned, 5)
        XCTAssertEqual(s.left, 0)
        XCTAssertEqual(s.progress, 1)
    }

    func testMinutesStayInRange() {
        XCTAssertEqual(Session(minutes: 1, rules: BlockRules(), now: start).minutes, 5)
        XCTAssertEqual(Session(minutes: 9000, rules: BlockRules(), now: start).minutes, 480)
    }

    func testTimeTheAppWasNotWatchingDoesNotCount() {
        var s = watched(minutes: 25, for: 60)
        // Force quit, reopened long after the session would have ended.
        s.tick(now: start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(s.counted, 60, accuracy: 0.001)
        XCTAssertFalse(s.finished)
        // And it carries on from there.
        s.tick(now: start.addingTimeInterval(4 * 3600 + 10))
        XCTAssertEqual(s.counted, 70, accuracy: 0.001)
    }

    func testAClockSetBackOrForwardGainsNothing() {
        var s = watched(minutes: 25, for: 60)
        s.tick(now: start.addingTimeInterval(-1000))
        XCTAssertEqual(s.counted, 60, accuracy: 0.001)
        s.tick(now: start.addingTimeInterval(1_000_000))
        XCTAssertEqual(s.counted, 60, accuracy: 0.001)
    }
}
