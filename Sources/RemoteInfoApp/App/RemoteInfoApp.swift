import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    var body: some Scene {
        MenuBarExtra("Remote Info", systemImage: "server.rack") {
            MenuBarPanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
