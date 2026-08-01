import SwiftUI

struct ConnectionStatusView: View {
    let isConnected: Bool

    var body: some View {
        Label(isConnected ? "Connected" : "Disconnected", systemImage: isConnected ? "checkmark.circle.fill" : "exclamationmark.circle")
            .foregroundStyle(isConnected ? .green : .secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(isConnected ? "Server connected" : "Server disconnected")
    }
}
