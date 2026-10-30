import XCTest
@testable import PizzeriaCore

final class LedgerTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }()

    private func day(_ n: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: n, hour: hour))!
    }

    private func session(minutes: Int, watched seconds: TimeInterval) -> Session {
        var s = Session(minutes: minutes, rules: BlockRules(), now: day(1))
        s.counted = seconds
        return s
    }

    private func done(on n: Int, minutes: Int = 25, hour: Int = 12) -> Entry {
        Entry(startedAt: day(n, hour: hour), endedAt: day(n, hour: hour), minutes: minutes, completed: true)
    }

    func testACompletedSessionPaysItsMinutes() {
        var ledger = Ledger(bank: 10)
        XCTAssertEqual(ledger.complete(session(minutes: 50, watched: 3000), at: day(1)), 50)
        XCTAssertEqual(ledger.bank, 60)
        XCTAssertEqual(ledger.entries.count, 1)
        XCTAssertTrue(ledger.entries[0].completed)
    }

    func testGivingUpLosesTheSessionAndKeepsTheBank() {
        var ledger = Ledger(bank: 100)
        XCTAssertEqual(ledger.giveUp(session(minutes: 50, watched: 2940), at: day(1)), 49)
        XCTAssertEqual(ledger.bank, 100)
        XCTAssertFalse(ledger.entries[0].completed)
    }

    func testThePizzeriaGrowsWithFinishedPizzeriaAndNeverShrinks() {
        var ledger = Ledger(entries: [done(on: 1, minutes: 499)])
        XCTAssertEqual(ledger.feeds, "you")
        ledger.entries.append(done(on: 2, minutes: 1))
        XCTAssertEqual(ledger.feeds, "your friends")
        ledger.giveUp(session(minutes: 50, watched: 600), at: day(3))
        XCTAssertEqual(ledger.feeds, "your friends")
        ledger.entries.append(done(on: 4, minutes: 49_500))
        XCTAssertEqual(ledger.feeds, "your city")
    }

    func testBarsAddUpCompletedMinutesByDayOldestFirst() {
        let lost = Entry(startedAt: day(29), endedAt: day(29), minutes: 40, completed: false)
        let ledger = Ledger(entries: [done(on: 28, minutes: 25), done(on: 28, minutes: 50, hour: 15), done(on: 30, minutes: 90), lost])
        let bars = ledger.minutesByDay(days: 3, today: day(30), calendar: calendar)
        XCTAssertEqual(bars.map(\.minutes), [75, 0, 90])
        XCTAssertEqual(bars.map(\.day), [28, 29, 30].map { calendar.startOfDay(for: day($0)) })
    }

    func testBarsCrossTheClockChange() {
        // The clocks go back on 25 Oct 2026 in London: that day has 25 hours.
        let ledger = Ledger(entries: [done(on: 24), done(on: 25), done(on: 26)])
        let bars = ledger.minutesByDay(days: 3, today: day(26), calendar: calendar)
        XCTAssertEqual(bars.map(\.minutes), [25, 25, 25])
    }

    func testStreakCountsBackFromToday() {
        let ledger = Ledger(entries: [done(on: 28), done(on: 29), done(on: 30)])
        XCTAssertEqual(ledger.streak(today: day(30), calendar: calendar), Streak(current: 3, best: 3))
    }

    func testTodayDoesNotBreakAStreakUntilItsOver() {
        let ledger = Ledger(entries: [done(on: 28), done(on: 29)])
        XCTAssertEqual(ledger.streak(today: day(30), calendar: calendar).current, 2)
        XCTAssertEqual(ledger.streak(today: day(31), calendar: calendar).current, 0)
    }

    func testBestOutlivesAMissedDay() {
        let ledger = Ledger(entries: [done(on: 20), done(on: 21), done(on: 22), done(on: 29), done(on: 30)])
        XCTAssertEqual(ledger.streak(today: day(30), calendar: calendar), Streak(current: 2, best: 3))
    }

    func testAGivenUpSessionDoesNotKeepAStreakAlive() {
        let lost = Entry(startedAt: day(30), endedAt: day(30), minutes: 40, completed: false)
        let ledger = Ledger(entries: [lost])
        XCTAssertEqual(ledger.streak(today: day(30), calendar: calendar), Streak(current: 0, best: 0))
    }

    func testStreakCrossesTheClockChange() {
        let ledger = Ledger(entries: [done(on: 24), done(on: 25), done(on: 26)])
        XCTAssertEqual(ledger.streak(today: day(26), calendar: calendar), Streak(current: 3, best: 3))
    }

    func testNoHistoryNoStreak() {
        XCTAssertEqual(Ledger().streak(today: day(30), calendar: calendar), Streak(current: 0, best: 0))
    }
}
