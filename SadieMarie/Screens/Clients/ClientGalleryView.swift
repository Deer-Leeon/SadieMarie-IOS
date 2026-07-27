import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ClientGalleryView: View {
    let photos: [ClientPhoto]
    var isLoading: Bool
    var isUploading: Bool
    var errorMessage: String?
    var onUpload: (Data, String, String) async -> Bool
    var onDelete: (ClientPhoto) async -> Bool

    @State private var pickerItem: PhotosPickerItem?
    @State private var photoPendingDelete: ClientPhoto?
    @State private var showDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        Group {
            if isLoading && photos.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .tint(AdminTheme.stone900)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, photos.isEmpty {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(Color.semanticRed)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if photos.isEmpty {
                VStack(spacing: 12) {
                    Text("No photos yet")
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Text("Add reference shots from your photo library.")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone700)
                        .multilineTextAlignment(.center)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Add photo")
                            .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone900)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AdminTheme.stone100)
                            .clipShape(Capsule())
                    }
                    .disabled(isUploading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(photos) { photo in
                            photoCell(photo)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        photoPendingDelete = photo
                                        showDeleteConfirm = true
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(AdminTheme.cream)
        .navigationTitle("Photo gallery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    if isUploading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone900)
                    }
                }
                .disabled(isUploading)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await handlePicked(item) }
        }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let photo = photoPendingDelete else { return }
                Task { _ = await onDelete(photo) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            if let errorMessage, !photos.isEmpty {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.semanticRed.opacity(0.12))
            }
        }
    }

    private func photoCell(_ photo: ClientPhoto) -> some View {
        AsyncImage(url: URL(string: photo.blobUrl)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            default:
                placeholder
                    .overlay { ProgressView().tint(AdminTheme.stone700) }
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var placeholder: some View {
        Rectangle()
            .fill(AdminTheme.stone100)
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let filename = "client-photo-\(UUID().uuidString).jpg"
            let mime = "image/jpeg"
            // Prefer JPEG bytes when possible; raw HEIC still accepted by the API.
            let uploadData: Data
            if let uiImage = UIImage(data: data),
               let jpeg = uiImage.jpegData(compressionQuality: 0.85) {
                uploadData = jpeg
            } else {
                uploadData = data
            }
            _ = await onUpload(uploadData, filename, mime)
        } catch {
            // Parent surfaces errors via photosError.
        }
    }
}
