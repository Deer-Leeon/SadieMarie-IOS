import PhotosUI
import SwiftUI
import ClerkKit

/// Website tab — manage the seven public site image slots.
struct WebsiteView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(PushRegistration.self) private var pushRegistration
    @Bindable var viewModel: WebsiteViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var activeSlot: WebsiteSlotItem?
    @State private var pendingImage: UIImage?
    @State private var showCropSheet = false
    @State private var isPhotoPickerPresented = false
    @State private var editingPortfolioItem: WebsiteSlotItem?
    @State private var editingDetailsItem: WebsiteSlotItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerBlock

                        if let notice = viewModel.refreshNotice {
                            RefreshNoticeText(notice: notice)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }

                        if let success = viewModel.saveSuccessMessage {
                            successBanner(success)
                        }

                        ForEach(WebsiteSection.allCases) { section in
                            sectionBlock(section)
                        }
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.top, 4)
                    .padding(.bottom, AdminTheme.Spacing.listVertical)
                    .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .task(id: clerk.session?.id) {
                guard clerk.session != nil, !viewModel.hasLoaded else { return }
                await viewModel.load(reason: .initial)
            }
            .onChange(of: pushRegistration.liveDataRevision) { _, _ in
                Task {
                    guard clerk.user != nil else { return }
                    await viewModel.load(showLoading: false, reason: .resume)
                }
            }
            .refreshable {
                guard clerk.user != nil else { return }
                await viewModel.load(showLoading: false, reason: .user)
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
                if let activeSlot, let pendingImage {
                    WebsiteImageCropSheet(
                        label: activeSlot.meta.label,
                        aspectRatio: activeSlot.meta.aspectRatio,
                        requiresCaption: activeSlot.meta.requiresCaption,
                        initialCaption: activeSlot.slot.caption ?? "",
                        services: viewModel.photoServices,
                        showsPhotoMeta: true,
                        initialSubject: activeSlot.slot.photoSubject ?? "",
                        initialAlt: activeSlot.slot.altText ?? "",
                        initialFileName: activeSlot.slot.fileName ?? "",
                        image: pendingImage,
                        onCancel: dismissCropFlow,
                        onSave: { data, caption, photo in
                            showCropSheet = false
                            Task {
                                await viewModel.upload(
                                    slotID: activeSlot.id,
                                    imageData: data,
                                    caption: caption,
                                    photo: photo
                                )
                                dismissCropFlow()
                            }
                        }
                    )
                }
            }
            .sheet(item: $editingPortfolioItem) { item in
                PortfolioSlotEditorSheet(
                    viewModel: viewModel,
                    item: item,
                    onDismiss: { editingPortfolioItem = nil }
                )
            }
            .sheet(item: $editingDetailsItem) { item in
                WebsitePhotoDetailsSheet(
                    viewModel: viewModel,
                    item: item,
                    onDismiss: { editingDetailsItem = nil }
                )
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Website")
                .font(AdminTheme.fontAdminSerif(size: 28))
                .foregroundStyle(AdminTheme.stone900)

            Text("Replace photos on sadiemarie.co, and edit each photo’s file name and alt text.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sectionBlock(_ section: WebsiteSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.rawValue.uppercased())
                .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                .tracking(AdminTheme.Typography.dayHeaderTracking)
                .foregroundStyle(AdminTheme.stone700)

            switch section {
            case .corePages:
                VStack(spacing: AdminTheme.Spacing.cardStack) {
                    ForEach(viewModel.slots(in: .corePages)) { item in
                        SiteImageCardView(
                            item: item,
                            isUploading: viewModel.uploadingSlotID == item.id,
                            onReplace: { beginReplace(for: item) },
                            onEditDetails: { editingDetailsItem = item }
                        )
                    }
                }
            case .portfolio:
                PortfolioCollageSection(
                    items: viewModel.slots(in: .portfolio),
                    uploadingSlotID: viewModel.uploadingSlotID,
                    onEdit: { editingPortfolioItem = $0 }
                )
            }
        }
    }

    private func beginReplace(for item: WebsiteSlotItem) {
        viewModel.clearSuccessBanner()
        activeSlot = item
        pickerItem = nil
        isPhotoPickerPresented = true
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
        activeSlot = nil
        pickerItem = nil
    }

    private var loadingOverlay: some View {
        ZStack {
            AdminTheme.cream.opacity(0.85).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 14))
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius))
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AdminTheme.confirmedText)
            Text(message)
                .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(AdminTheme.confirmedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius)
                .stroke(AdminTheme.confirmedBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius))
    }
}

#Preview {
    WebsiteView(viewModel: WebsiteViewModel())
        .environment(PushRegistration.shared)
}
