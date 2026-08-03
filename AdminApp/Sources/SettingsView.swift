import SwiftUI

struct SettingsView: View {
    @Bindable var model: AdminAppModel

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Server URL", text: $model.baseURLText, prompt: Text("https://api.example.com"))

                SecureField("Admin API Token", text: $model.token)
                    .textContentType(.password)
                LabeledContent("Status") {
                    Label(model.isConnected ? "Connected" : "Disconnected", systemImage: model.isConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.isConnected ? .green : .secondary)
                }
            }
            Section {
                HStack {
                    Button(model.isConnected ? "Reconnect" : "Connect", systemImage: "network") {
                        Task { await model.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.token.utf8.count < 32 || model.isLoading)
                    if model.isConnected {
                        Button("Disconnect", systemImage: "xmark.circle", action: model.disconnect)
                    }
                }
            } footer: {
                Text("The token is stored in this Mac’s Keychain. Production servers must use HTTPS.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .padding()
    }
}
