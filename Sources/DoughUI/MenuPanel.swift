import AppKit
import DoughCore
import SwiftUI

/// The menu bar's panel: the bank and the streak, the session, the last two weeks.
public struct MenuPanel: View {
    @ObservedObject var model: DoughModel
    @Environment(\.openWindow) private var openWindow

    public init(model: DoughModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header(bank: model.bank, streak: model.streak)
            if let session = model.state.session {
                RunningView(session: session, bank: model.bank, stakeBank: model.state.stakeBank, blocker: model.blocker, giveUp: model.giveUp)
            } else {
                idle
            }
            Divider()
            Histogram(bars: model.bars)
            Divider()
            HStack {
                Button("Block lists…") { open() }
                Spacer()
                if !model.running { Button("Quit") { NSApp.terminate(nil) } }
            }
            .buttonStyle(.link).foregroundStyle(.secondary).font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let note = outcomeNote {
                Text(note).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                ForEach([25, 50, 90], id: \.self) { m in
                    Button("\(m)") { model.minutes = m }
                        .tint(model.minutes == m ? Ink.crust : nil)
                        .buttonStyle(.bordered)
                }
                Spacer()
                Stepper(value: $model.minutes, in: Session.minutesRange, step: Session.minutesStep) {
                    Text(hours(model.minutes)).monospacedDigit()
                }
                .fixedSize()
            }
            Button(action: model.start) {
                Text("Start · \(model.minutes) dough on the line").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(Ink.crust).controlSize(.large)
            Text(summary).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var outcomeNote: String? {
        switch model.outcome {
        case .banked(let n): return "+\(n) banked."
        case .lost(let n): return n > 0 ? "Stopped early. \(n) dough gone." : "Stopped before the first minute. Nothing lost."
        case nil: return nil
        }
    }

    private var summary: String {
        let r = model.rules
        let apps: String
        switch r.appMode {
        case .off: apps = "All apps open"
        case .block: apps = "\(count(r.apps.count, "app")) blocked"
        case .only: apps = "Only \(count(r.apps.count, "app")) open"
        }
        let sites: String
        switch r.siteMode {
        case .off: sites = "all sites open"
        case .block: sites = "\(count(r.sites.count, "site")) blocked"
        case .only: sites = "only \(count(r.sites.count, "site")) open"
        }
        return "\(apps), \(sites)"
    }

    private func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }

    private func open() {
        openWindow(id: "lists")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct Header: View {
    let bank: Int
    let streak: Streak

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(bank.formatted()).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("dough banked").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(streak.current)").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("day streak · best \(streak.best)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct RunningView: View {
    let session: Session
    let bank: Int
    let stakeBank: Bool
    @ObservedObject var blocker: Blocker
    let giveUp: () -> Void
    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(clock(session.left)).font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
            ProgressView(value: session.progress).tint(Ink.crust)
            Text("+\(session.earned) dough rising, paid when the timer ends").font(.callout).foregroundStyle(.secondary)
            if !blocker.blind.isEmpty {
                Label("Sites aren't blocked in \(blocker.blind.sorted().joined(separator: ", ")). Allow Dough in System Settings › Privacy & Security.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            if confirming {
                Text(stakeBank ? "Lose \(session.earned) dough and your \(bank.formatted()) banked?" : "Lose \(session.earned) dough?")
                    .font(.callout.weight(.semibold))
                HStack {
                    Button("Keep going") { confirming = false }
                        .buttonStyle(.borderedProminent).tint(Ink.crust)
                    Button("Lose it", role: .destructive, action: giveUp)
                }
            } else {
                Button("Give up…") { confirming = true }
            }
        }
    }
}

/// Completed minutes a day. One series, so no legend: the title names it, a hover reads a bar out.
struct Histogram: View {
    let bars: [DayBar]
    @State private var hovered: Int?

    private var peak: Int { max(bars.map(\.minutes).max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Focus, last \(bars.count) days").font(.caption.weight(.semibold))
                Spacer()
                Text(readout).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(bars.indices, id: \.self) { column($0) }
            }
            .frame(height: 64)
            HStack {
                Text(bars.first?.day.formatted(.dateTime.day().month()) ?? "")
                Spacer()
                Text("Today")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var readout: String {
        if let i = hovered, bars.indices.contains(i) {
            return "\(bars[i].day.formatted(.dateTime.weekday().day().month())) · \(hours(bars[i].minutes))"
        }
        let total = bars.map(\.minutes).reduce(0, +)
        return total > 0 ? "\(hours(total)) total" : "Nothing yet"
    }

    private func column(_ i: Int) -> some View {
        let minutes = bars[i].minutes
        return GeometryReader { box in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                UnevenRoundedRectangle(topLeadingRadius: minutes > 0 ? 3 : 0, topTrailingRadius: minutes > 0 ? 3 : 0)
                    .fill(minutes > 0 ? AnyShapeStyle(Ink.crust.opacity(hovered == nil || hovered == i ? 1 : 0.55)) : AnyShapeStyle(.quaternary))
                    .frame(height: minutes > 0 ? max(3, box.size.height * CGFloat(minutes) / CGFloat(peak)) : 2)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = i } else if hovered == i { hovered = nil }
        }
        .accessibilityElement()
        .accessibilityLabel("\(bars[i].day.formatted(date: .abbreviated, time: .omitted)): \(hours(minutes))")
    }
}
