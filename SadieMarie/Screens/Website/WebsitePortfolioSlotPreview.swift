import SwiftUI

/// Portfolio preview for the editor sheet — same 65% width and aspect ratio as the collage tile.
struct WebsitePortfolioSlotPreview: View {
    let item: WebsiteSlotItem
    let aspectRatio: CGFloat
    var isUploading: Bool = false
    var localPreviewImage: UIImage? = nil
    var overlayCaption: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            previewTile
                .containerRelativeFrame(
                    .horizontal,
                    count: 100,
                    span: Int(WebsiteLayout.portfolioTileWidthFraction * 100),
                    spacing: 0
                )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var previewTile: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2)
                    .fill(WebsiteLayout.portfolioEmptyBackground)

                imageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isUploading {
                    AdminTheme.cream.opacity(0.75)
                    ProgressView()
                        .controlSize(.regular)
                        .tint(AdminTheme.stone900)
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2))

            if let overlayCaption {
                captionOverlay(text: overlayCaption)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius))
    }

    @ViewBuilder
    private var imageContent: some View {
        if let localPreviewImage {
            Image(uiImage: localPreviewImage)
                .resizable()
                .scaledToFill()
                .clipped()
        } else if let url = item.imageURL {
            RemoteImageView(url: url, contentMode: .fill) {
                ProgressView()
                    .tint(AdminTheme.stone700)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } failure: {
                emptyPlaceholder
            }
        } else {
            emptyPlaceholder
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("No image yet")
                .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func captionOverlay(text: String) -> some View {
        Text(text)
            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
            .foregroundStyle(Color.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
            .allowsHitTesting(false)
    }
}
