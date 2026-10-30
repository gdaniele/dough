import Foundation

/// One finished or abandoned session.
public struct Entry: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var endedAt: Date
    public var minutes: Int
    public var completed: Bool

    public init(startedAt: Date, endedAt: Date, minutes: Int, completed: Bool) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.minutes = minutes
        self.completed = completed
    }
}

public struct DayBar: Equatable, Sendable {
    public var day: Date
    public var minutes: Int

    public init(day: Date, minutes: Int) {
        self.day = day
        self.minutes = minutes
    }
}

public struct Streak: Equatable, Sendable {
    public var current: Int
    public var best: Int

    public init(current: Int, best: Int) {
        self.current = current
        self.best = best
    }
}

/// The bank and the history. All or nothing: a session pays when it runs to its end. Giving up pays nothing, and the
/// bank is never touched.
public struct Ledger: Codable, Equatable, Sendable {
    public var bank = 0
    public var entries: [Entry] = []

    public init(bank: Int = 0, entries: [Entry] = []) {
        self.bank = bank
        self.entries = entries
    }

    /// Who the pizzeria feeds, by dough from finished sessions.
    public static let ladder: [(dough: Int, who: String)] = [(500, "your friends"), (2000, "your coworkers"),
                                                             (10000, "your neighborhood"), (50000, "your city")]

    /// Pizzeria from every finished session. It only grows, so the pizzeria does too.
    public var lifetime: Int { entries.filter(\.completed).map(\.minutes).reduce(0, +) }

    public var feeds: String { Self.ladder.last(where: { lifetime >= $0.dough })?.who ?? "you" }

    /// Pays a session that ran to its end; returns what it paid.
    @discardableResult
    public mutating func complete(_ session: Session, at end: Date) -> Int {
        let paid = session.minutes
        bank += paid
        entries.append(Entry(startedAt: session.startedAt, endedAt: end, minutes: paid, completed: true))
        return paid
    }

    /// Ends a session early; returns what it had earned, which is lost.
    @discardableResult
    public mutating func giveUp(_ session: Session, at end: Date) -> Int {
        entries.append(Entry(startedAt: session.startedAt, endedAt: end, minutes: session.earned, completed: false))
        return session.earned
    }

    /// Completed minutes a day, oldest first, for the `days` days ending on `today`. A session counts on the day it ended.
    public func minutesByDay(days: Int, today: Date, calendar: Calendar = .current) -> [DayBar] {
        let last = calendar.startOfDay(for: today)
        var totals: [Date: Int] = [:]
        for entry in entries where entry.completed {
            totals[calendar.startOfDay(for: entry.endedAt), default: 0] += entry.minutes
        }
        return (0 ..< days).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: last).map { DayBar(day: $0, minutes: totals[$0] ?? 0) }
        }
    }

    /// Days in a row with a completed session. Today doesn't break a streak until it's over.
    public func streak(today: Date, calendar: Calendar = .current) -> Streak {
        let days = Set(entries.filter(\.completed).map { calendar.startOfDay(for: $0.endedAt) })
        let before: (Date) -> Date? = { calendar.date(byAdding: .day, value: -1, to: $0) }

        var best = 0
        for day in days where !days.contains(before(day) ?? day) {
            var run = 1
            var next = calendar.date(byAdding: .day, value: 1, to: day)
            while let d = next, days.contains(d) {
                run += 1
                next = calendar.date(byAdding: .day, value: 1, to: d)
            }
            best = max(best, run)
        }

        var current = 0
        let start = calendar.startOfDay(for: today)
        var cursor = days.contains(start) ? start : before(start)
        while let d = cursor, days.contains(d) {
            current += 1
            cursor = before(d)
        }
        return Streak(current: current, best: best)
    }
}
