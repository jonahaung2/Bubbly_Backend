import SwiftUI

struct MediaView: View {
    @Bindable var model: AdminAppModel
    @State private var searchText = ""
    @State private var selectedMedia: AdminMedia?

    private var filteredMedia: [AdminMedia] {
        guard !searchText.isEmpty else { return model.media }
        return model.media.filter {
            $0.kind.localizedStandardContains(searchText)
                || $0.scopeID.localizedStandardContains(searchText)
                || $0.assetID.localizedStandardContains(searchText)
                || $0.ownerUserID.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        Group {
            if model.media.isEmpty {
                ContentUnavailableView("No Media", systemImage: "photo.on.rectangle.angled", description: Text(model.isConnected ? "No media assets were found." : "Connect to load media."))
            } else if filteredMedia.isEmpty {
                ContentUnavailableView.search
            } else {
                Table(filteredMedia) {
                    TableColumn("Preview") { media in
                        AsyncImage(url: media.url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "photo") }
                            .frame(width: 44, height: 44)
                            .clipShape(.rect(cornerRadius: 8))
                            .accessibilityLabel("Preview for \(media.assetID)")
                    }
                    .width(60)
                    TableColumn("Kind", value: \.kind)
                    TableColumn("Scope", value: \.scopeID)
                    TableColumn("Asset", value: \.assetID)
                    TableColumn("Size") { media in Text(Int64(media.byteCount), format: .byteCount(style: .file)) }
                    TableColumn("Type", value: \.contentType)
                    TableColumn("Actions") { media in
                        Button("Manage", systemImage: "slider.horizontal.3") { selectedMedia = media }
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .navigationTitle("Media")
        .searchable(text: $searchText, prompt: "Search media")
        .sheet(item: $selectedMedia) { media in
            MediaDetailView(media: media, model: model)
        }
    }
}
