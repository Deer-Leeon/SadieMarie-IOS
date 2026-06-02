import PhotosUI
import SwiftUI

/// Edit a portfolio slot — image, caption, and save via `WebsiteViewModel.saveSlot`.
struct PortfolioSlotEditorSheet: View {
    @Bindable var viewModel: WebsiteViewModel
    let item: WebsiteSlotItem
    let onDismiss: () -> Void

    @State private var draftCaption: String
    @State private var draftImage: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var showCropSheet = false
    @State private var isPhotoPickerPresented = false

    private var defaultCaptionPlaceholder: String {
        SiteImageSlot.portfolioDefaults[item.id]
            ?? item.meta.label
    }

    init(viewModel: WebsiteViewModel, item: WebsiteSlotItem, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.item = item
        self.onDismiss = onDismiss
        _draftCaption = State(initialValue: item.slot.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        previewSection
                        changeImageButton
                        captionSection
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.vertical, AdminTheme.Spacing.listVertical)
                }

                if viewModel.isUploading && viewModel.uploadingSlotID == item.id {
                    savingOverlay
                }
            }
            .navigationTitle(item.meta.label)
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
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $pickerItem,
                matching: .images
            )
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePickedPhoto(newItem) }
            }
            .sheet(isPresented: $showCropSheet) {
                if let pendingImage {
                    WebsiteImageCropSheet(
                        label: item.meta.label,
                        aspectRatio: item.meta.aspectRatio,
                        requiresCaption: false,
                        initialCaption: "",
                        image: pendingImage,
                        onCancel: dismissCropFlow,
                        onSave: { data, _ in
                            draftImage = data
                            dismissCropFlow()
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var canSave: Bool {
        draftImage != nil || captionDraftDiffersFromStored
    }

    private var captionDraftDiffersFromStored: Bool {
        switch item.slot.caption {
        case nil:
            return !draftCaption.isEmpty
        case let stored?:
            return stored != draftCaption
        }
    }

    private var previewSection: some View {
        WebsitePortfolioSlotPreview(
            item: item,
            aspectRatio: item.meta.aspectRatio,
            isUploading: viewModel.isUploading && viewModel.uploadingSlotID == item.id,
            localPreviewImage: draftImage.flatMap { UIImage(data: $0) },
            overlayCaption: previewOverlayCaption
        )
    }

    private var previewOverlayCaption: String? {
        SiteImageSlot(
            id: item.id,
            imageURL: item.slot.imageURL,
            caption: effectiveCaptionForPreview
        ).displayCaption()
    }

    /// Maps the draft field to the API caption semantics (`nil` = default, `""` = hidden).
    private var effectiveCaptionForPreview: String? {
        if !draftCaption.isEmpty {
            return draftCaption
        }
        if item.slot.caption != nil {
            return ""
        }
        return nil
    }

    private var changeImageButton: some View {
        Button {
            pickerItem = nil
            isPhotoPickerPresented = true
        } label: {
            Label("Change Image", systemImage: "photo.on.rectangle.angled")
                .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploading)
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image Title / Caption")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            TextField(defaultCaptionPlaceholder, text: $draftCaption)
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )

            Text("Leave blank to hide the label on the website.")
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
        }
    }

    private var savingOverlay: some View {
        ZStack {
            AdminTheme.cream.opacity(0.85).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)
        }
    }

    private func save() async {
        let captionForRequest: String? = draftImage != nil || captionDraftDiffersFromStored
            ? draftCaption
            : nil

        await viewModel.saveSlot(
            id: item.id,
            newImage: draftImage,
            newCaption: captionForRequest
        )

        if viewModel.errorMessage == nil {
            onDismiss()
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        pendingImage = image
        showCropSheet = true
    }

    private func dismissCropFlow() {
        showCropSheet = false
        pendingImage = nil
        pickerItem = nil
    }
}
