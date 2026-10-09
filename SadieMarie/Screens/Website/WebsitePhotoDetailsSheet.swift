import SwiftUI

/// Edit a photo’s service, alt text, and file name without uploading a new image.
struct WebsitePhotoDetailsSheet: View {
    @Bindable var viewModel: WebsiteViewModel
    let item: WebsiteSlotItem
    let onDismiss: () -> Void

    @State private var subject: String
    @State private var altText: String
    @State private var fileName: String

    init(viewModel: WebsiteViewModel, item: WebsiteSlotItem, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.item = item
        self.onDismiss = onDismiss
        let stored = SiteImagePhotoFields.stored(from: item.slot)
        _subject = State(initialValue: stored.photoSubject)
        _altText = State(initialValue: stored.altText)
        _fileName = State(initialValue: stored.fileName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AdminTheme.fontAdminSans(size: 14))
                                .foregroundStyle(Color.semanticRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("These words stay with this photo. Saving does not replace the picture.")
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(AdminTheme.stone700)

                        WebsitePhotoMetaFields(
                            services: viewModel.photoServices,
                            subject: $subject,
                            altText: $altText,
                            fileName: $fileName
                        )
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.vertical, AdminTheme.Spacing.listVertical)
                }

                if viewModel.isUploading && viewModel.uploadingSlotID == item.id {
                    AdminTheme.cream.opacity(0.85).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(AdminTheme.stone900)
                }
            }
            .navigationTitle("Photo details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(AdminTheme.stone700)
                        .disabled(viewModel.isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .font(AdminTheme.fontAdminSans(size: 16, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                    .disabled(viewModel.isUploading || !canSave)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var draft: SiteImagePhotoFields {
        SiteImagePhotoFields(
            altText: altText,
            fileName: fileName,
            photoSubject: subject
        )
    }

    private var canSave: Bool {
        draft != SiteImagePhotoFields.stored(from: item.slot)
    }

    private func save() async {
        await viewModel.saveSlot(
            id: item.id,
            newImage: nil,
            newCaption: nil,
            photo: draft
        )
        if viewModel.errorMessage == nil {
            onDismiss()
        }
    }
}
