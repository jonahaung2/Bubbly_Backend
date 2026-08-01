import SwiftUI

struct OverviewView: View {
    let model: AdminAppModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))]) {
                MetricCardView(title: "Contacts", value: model.contacts.count.formatted(), symbol: "person.2.fill", color: .blue)
                MetricCardView(title: "Groups", value: model.groups.count.formatted(), symbol: "person.3.fill", color: .purple)
                MetricCardView(title: "Media Assets", value: model.media.count.formatted(), symbol: "photo.stack.fill", color: .orange)
                MetricCardView(title: "Media Storage", value: Int64(model.media.reduce(0) { $0 + $1.byteCount }).formatted(.byteCount(style: .file)), symbol: "externaldrive.fill", color: .green)
            }
            .padding()

            if !model.isConnected {
                ContentUnavailableView("Connect to the Backend", systemImage: "network.slash", description: Text("Open Settings and enter the server URL and admin token."))
                    .padding()
            }
        }
        .navigationTitle("Overview")
    }
}

struct MetricCardView: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: symbol)
                .foregroundStyle(color)
            Text(value)
                .font(.largeTitle)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
