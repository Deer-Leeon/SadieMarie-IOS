import SwiftUI

/// Portfolio gallery — one white card; mobile web zig-zag at 65% width (left / right / left …).
struct PortfolioCollageSection: View {
    let items: [WebsiteSlotItem]
    var uploadingSlotID: String?
    var onEdit: (WebsiteSlotItem) -> Void

    var body: some View {
        VStack(spacing: WebsiteLayout.portfolioCollageGap) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                collageRow(index: index, item: item)
            }
        }
        .padding(WebsiteLayout.portfolioCollageInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private func collageRow(index: Int, item: WebsiteSlotItem) -> some View {
        let isLeading = index.isMultiple(of: 2)
        let tile = PortfolioTileView(
            item: item,
            isUploading: uploadingSlotID == item.id,
            onTap: { onEdit(item) }
        )
        .containerRelativeFrame(
            .horizontal,
            count: 100,
            span: 65,
            spacing: 0,
            alignment: isLeading ? .leading : .trailing
        )

        HStack(alignment: .top, spacing: 0) {
            if isLeading {
                tile
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                tile
            }
        }
    }
}

#Preview {
    ScrollView {
        PortfolioCollageSection(
            items: WebsiteSlotMeta.catalog
                .filter { $0.section == .portfolio }
                .map { WebsiteSlotItem(meta: $0, slot: .previewPortfolio) },
            onEdit: { _ in }
        )
        .padding()
    }
    .background(AdminTheme.cream)
}
