import DoughUI
import SwiftUI

@main
struct DoughApp: App {
    @StateObject private var model = DoughModel()

    var body: some Scene {
        // A plain Text fed by the model: a TimelineView here makes MenuBarExtra redraw its button forever.
        MenuBarExtra {
            MenuPanel(model: model)
        } label: {
            Text(model.menuText)
        }
        .menuBarExtraStyle(.window)

        Window("Block lists", id: "lists") {
            ListsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
