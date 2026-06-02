import SwiftUI

/// Single portfolio collage tile — image preview with optional on-image caption overlay.
struct PortfolioTileView: View {
    let item: WebsiteSlotItem
    var isUploading: Bool
    var onTap: () -> Void

    private var overlayCaption: String? {
        item.slot.displayCaption()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                WebsiteSlotImageArea(
                    item: item,
                    aspectRatio: item.meta.aspectRatio,
                    isUploading: isUploading,
                    onReplace: {},
                    emptyBackground: WebsiteLayout.portfolioEmptyBackground,
                    imageContentMode: .fill
                )
                .allowsHitTesting(false)

                if let overlayCaption {
                    captionOverlay(text: overlayCaption)
                        .allowsHitTesting(false)
                }
            }

            collageEditBadge
                .padding(8)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.meta.label)
        .accessibilityHint("Edit portfolio image and caption")
        .accessibilityAddTraits(.isButton)
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
    }

    private var collageEditBadge: some View {
        Circle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    PortfolioTileView(
        item: WebsiteSlotItem(
            meta: WebsiteSlotMeta.meta(for: .portfolio1),
            slot: SiteImageSlot(
                id: WebsiteSlotId.portfolio1.rawValue,
                imageURL: "https://www.sadiemarie.co/images/hero.jpg",
                caption: nil
            )
        ),
        isUploading: false,
        onTap: {}
    )
    .padding()
    .background(AdminTheme.cream)
}
