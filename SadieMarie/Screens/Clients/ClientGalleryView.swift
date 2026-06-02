import SwiftUI

struct ClientGalleryView: View {
    let photos: [ClientPhoto]
    var isLoading: Bool
    var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(AdminTheme.stone900)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(Color.semanticRed)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if photos.isEmpty {
                VStack(spacing: 8) {
                    Text("No photos yet")
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Text("Reference shots uploaded from the web admin will appear here.")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone700)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(photos) { photo in
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
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(AdminTheme.cream)
        .navigationTitle("Photo gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(AdminTheme.stone100)
    }
}
