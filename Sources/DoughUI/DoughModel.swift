import AppKit
import DoughCore
import SwiftUI

public enum Outcome: Equatable {
    case banked(Int)
    case lost(Int)
}

/// The app's one source of truth: holds the state, runs the session clock, starts and stops the blocker.
@MainActor
public final class DoughModel: ObservableObject {
    @Published public private(set) var state: AppState
    /// Ticks while a session runs, so the menu bar and the clock redraw.
    @Published public private(set) var now = Date()
    /// How the last session went, until the next one starts.
    @Published public private(set) var outcome: Outcome?
    public let blocker = Blocker()

    private let store: Store
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var savedAt = Date.distantPast

    public init(store: Store = .standard) {
        self.store = store
        state = store.load()
        blocker.stake = { [weak self] in self?.state.session?.earned ?? 0 }
        // A session open when the app last stopped carries on, with the time away left out.
        if let session = state.session { begin(session) }
    }

    public var running: Bool { state.session != nil }
    public var bank: Int { state.ledger.bank }
    public var streak: Streak { state.ledger.streak(today: Date()) }
    public var bars: [DayBar] { state.ledger.minutesByDay(days: 14, today: Date()) }

    /// The menu bar: the bank, or the time left and what's at stake.
    public var menuText: String {
        guard let s = state.session else { return "🍞 \(bank)" }
        return "🍞 \(clock(s.left)) · +\(s.earned)"
    }

    // The settings don't change while a session runs: it keeps its own copy of the rules anyway.

    public var rules: BlockRules {
        get { state.rules }
        set { guard !running else { return }; state.rules = newValue; save() }
    }

    public var stakeBank: Bool {
        get { state.stakeBank }
        set { guard !running else { return }; state.stakeBank = newValue; save() }
    }

    public var minutes: Int {
        get { state.minutes }
        set { guard !running else { return }; state.minutes = newValue; save() }
    }

    public func start() {
        guard !running else { return }
        let session = Session(minutes: state.minutes, rules: state.rules, now: Date())
        state.session = session
        outcome = nil
        begin(session)
        save()
    }

    /// All or nothing: ends the session with no pay.
    public func giveUp() {
        guard let session = state.session else { return }
        outcome = .lost(state.ledger.giveUp(session, at: Date(), stakeBank: state.stakeBank))
        end()
    }

    private func begin(_ session: Session) {
        blocker.start(rules: session.rules)
        // The clock counts only what the app watches, so the system mustn't nap it or sleep from idle mid-session.
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "A focus session is running")
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func end() {
        state.session = nil
        blocker.stop()
        timer?.invalidate()
        timer = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        save()
    }

    private func tick() {
        guard var session = state.session else { return }
        now = Date()
        session.tick(now: now)
        guard session.finished else {
            state.session = session
            if now.timeIntervalSince(savedAt) >= 5 { save() }
            return
        }
        outcome = .banked(state.ledger.complete(session, at: now))
        end()
        NSSound(named: NSSound.Name("Hero"))?.play()
    }

    private func save() {
        savedAt = Date()
        do { try store.save(state) } catch { NSLog("Dough couldn't save: \(error)") }
    }
}

public func clock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

func hours(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
}

/// The colours. One crust hue for the marks, a darker step of it under the white label of a prominent button in both
/// modes, and the cover's dark ground.
enum Ink {
    static let crust = Color(light: 0xA3560F, dark: 0xE9A44B)
    static let button = Color(light: 0xA3560F, dark: 0xA3560F)
    static let cover = Color(light: 0x1E1710, dark: 0x1E1710)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}
