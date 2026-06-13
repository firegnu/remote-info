import SwiftUI

struct MenuBarPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Info")
                .font(.headline)
            Text("Native macOS menu bar app")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
