import SwiftUI

/// Hero / about slot — wide card with replace affordance.
struct SiteImageCardView: View {
    let item: WebsiteSlotItem
    var isUploading: Bool
    var onReplace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.meta.label)
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)

                Spacer()

                replaceButton
            }

            WebsiteSlotImageArea(
                item: item,
                aspectRatio: item.meta.aspectRatio,
                isUploading: isUploading,
                onReplace: onReplace
            )
        }
        .websiteCardChrome()
    }

    private var replaceButton: some View {
        Button(action: onReplace) {
            Text(item.isEmpty ? "Add image" : "Replace")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
        }
        .disabled(isUploading)
    }
}

/// Shared image preview / empty placeholder.
struct WebsiteSlotImageArea: View {
    let item: WebsiteSlotItem
    let aspectRatio: CGFloat
    var isUploading: Bool
    var onReplace: () -> Void
    var emptyBackground: Color = AdminTheme.stone100
    var imageContentMode: ContentMode = .fill
    /// When set (e.g. editor draft), shown instead of `item.imageURL`.
    var localPreviewImage: UIImage? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2)
                .fill(emptyBackground)

            if let localPreviewImage {
                localImageView(localPreviewImage)
            } else if let url = item.imageURL {
                RemoteImageView(url: url, contentMode: imageContentMode) {
                    ProgressView()
                        .tint(AdminTheme.stone700)
                } failure: {
                    emptyPlaceholder
                }
            } else {
                emptyPlaceholder
            }

            if isUploading {
                AdminTheme.cream.opacity(0.75)
                ProgressView()
                    .controlSize(.regular)
                    .tint(AdminTheme.stone900)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2))
        .contentShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius - 2))
        .onTapGesture(perform: onReplace)
    }

    @ViewBuilder
    private func localImageView(_ uiImage: UIImage) -> some View {
        if imageContentMode == .fill {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(emptyBackground == AdminTheme.stone100 ? AdminTheme.stone500 : .white.opacity(0.3))

            if emptyBackground == AdminTheme.stone100 {
                Text("Empty")
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                Text("Tap to add")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WebsiteCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AdminTheme.Spacing.rowHorizontal)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .shadow(
                color: AdminTheme.cardShadow,
                radius: AdminTheme.Layout.cardShadowRadius,
                y: AdminTheme.Layout.cardShadowY
            )
    }
}

extension View {
    func websiteCardChrome() -> some View {
        modifier(WebsiteCardChrome())
    }
}

#Preview {
    SiteImageCardView(
        item: WebsiteSlotItem(
            meta: WebsiteSlotMeta.meta(for: .homeHero),
            slot: .previewHero
        ),
        isUploading: false,
        onReplace: {}
    )
    .padding()
    .background(AdminTheme.cream)
}
