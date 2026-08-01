import SwiftUI
import UniformTypeIdentifiers

struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var isConfirmingDelete = false
    let media: AdminMedia
    let model: AdminAppModel

    var body: some View {
        VStack {
            AsyncImage(url: media.url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Media preview")

            Form {
                LabeledContent("Kind", value: media.kind)
                LabeledContent("Scope", value: media.scopeID)
                LabeledContent("Asset", value: media.assetID)
                LabeledContent("Owner", value: media.ownerUserID)
                LabeledContent("Content Type", value: media.contentType)
                LabeledContent("Size") { Text(Int64(media.byteCount), format: .byteCount(style: .file)) }
            }
            .formStyle(.grouped)
        }
        .padding()
        .frame(minWidth: 680, minHeight: 680)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close", action: dismiss.callAsFunction) }
            ToolbarItem {
                Button("Replace", systemImage: "arrow.triangle.2.circlepath") { isImporting = true }
            }
            ToolbarItem {
                Button("Delete", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    .confirmationDialog("Delete Media?", isPresented: $isConfirmingDelete) {
                        Button("Delete Permanently", role: .destructive) {
                            Task { await model.delete(section: .media, id: media.id); dismiss() }
                        }
                    }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.png, .jpeg, .heic]) { result in
            importMedia(result)
        }
    }

    private func importMedia(_ result: Result<URL, any Error>) {
        Task {
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.preferredMIMEType ?? "application/octet-stream"
                if await model.replaceMedia(id: media.id, data: data, contentType: type) { dismiss() }
            } catch {
                model.issue = .init(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }
}
