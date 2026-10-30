import PizzeriaCore
import SwiftUI

/// The block lists. They lock while a session runs.
public struct ListsView: View {
    @ObservedObject var model: PizzeriaModel
    @State private var siteText = ""
    @State private var choices: [AppChoice] = []
    @State private var search = ""

    public init(model: PizzeriaModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.running {
                Label("Locked until the timer ends.", systemImage: "lock.fill").font(.callout.weight(.semibold))
            }
            Group {
                sites
                apps
            }
            .disabled(model.running)
        }
        .padding(18)
        .frame(width: 420, height: 620, alignment: .top)
        .onAppear {
            siteText = model.rules.sites.joined(separator: "\n")
            choices = model.blocker.candidates()
        }
    }

    private var sites: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Websites").font(.headline)
            ModePicker(mode: $model.rules.siteMode)
            Text(siteHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.rules.siteMode != .off {
                TextEditor(text: $siteText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 96)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
                    .onChange(of: siteText) { _, text in model.rules.sites = Sites.parse(text) }
            }
        }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps").font(.headline)
            ModePicker(mode: $model.rules.appMode)
            Text(appHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.rules.appMode != .off {
                TextField("Find an app", text: $search).textFieldStyle(.roundedBorder)
                List(shown) { app in
                    Toggle(app.name, isOn: Binding(
                        get: { model.rules.apps.contains(app.id) },
                        set: { on in
                            model.rules.apps.removeAll { $0 == app.id }
                            if on { model.rules.apps.append(app.id) }
                        }
                    ))
                }
                .listStyle(.bordered)
            }
        }
    }

    /// The listed apps first, then by name.
    private var shown: [AppChoice] {
        let found = choices.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        let listed = Set(model.rules.apps)
        return found.filter { listed.contains($0.id) } + found.filter { !listed.contains($0.id) }
    }

    private var siteHint: String {
        switch model.rules.siteMode {
        case .off: return "Browsers open any site."
        case .block: return "Safari, Chrome, Arc, Brave, Edge, Vivaldi and Firefox open any site but these, or their subdomains. One a line. macOS asks to let Pizzeria see each browser the first time."
        case .only: return "Safari, Chrome, Arc, Brave, Edge, Vivaldi and Firefox open these sites and nothing else. One a line. macOS asks to let Pizzeria see each browser the first time. Use another browser? Block it under Apps."
        }
    }

    private var appHint: String {
        switch model.rules.appMode {
        case .off: return "Every app stays open."
        case .block: return "These hide the moment they come to the front."
        case .only: return "Everything else hides the moment it comes to the front. Finder and System Settings always stay open."
        }
    }
}

private struct ModePicker: View {
    @Binding var mode: ListMode

    var body: some View {
        Picker("", selection: $mode) {
            Text("Off").tag(ListMode.off)
            Text("Block these").tag(ListMode.block)
            Text("Only these").tag(ListMode.only)
        }
        .pickerStyle(.segmented).labelsHidden()
    }
}
