import SwiftUI

/// Public service menu — mirrors the live site catalogue (`GET /api/services`).
struct ServiceCatalogView: View {
    @State private var viewModel = ServiceCatalogViewModel()
    @State private var expandedGroupIDs: Set<Int> = []

    var body: some View {
        ZStack {
            AdminTheme.cream.ignoresSafeArea()

            Group {
                if viewModel.sections.isEmpty, !viewModel.isLoading {
                    emptyState
                } else {
                    catalogList
                }
            }

            if viewModel.isLoading, viewModel.sections.isEmpty {
                ProgressView()
                    .tint(AdminTheme.stone700)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
        .onAppear {
            Task { await viewModel.load() }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var catalogList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28, pinnedViews: []) {
                headerBlock

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                ForEach(viewModel.sections) { section in
                    sectionBlock(section)
                }
            }
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.top, 4)
            .padding(.bottom, AdminTheme.Spacing.listVertical)
            .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Service menu")
                .font(AdminTheme.fontAdminSerif(size: 28))
                .foregroundStyle(AdminTheme.stone900)

            Text("Live preview of the public site menu. Pull to refresh after CMS changes.")
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: PublicServiceCategorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !section.category.isEmpty {
                Text(section.category)
                    .font(AdminTheme.fontAdminSerif(size: 20))
                    .foregroundStyle(AdminTheme.stone900)
            }

            ForEach(section.rows) { row in
                switch row {
                case .group(let group):
                    groupRow(group)
                case .service(let service):
                    serviceRow(service, indented: false)
                }
            }

            ForEach(section.comingSoonFooters, id: \.self) { footerCategory in
                comingSoonBlock(category: footerCategory)
            }
        }
    }

    private func groupRow(_ group: PublicCatalogGroup) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        let hasChildren = !group.children.isEmpty

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                guard hasChildren else { return }
                if isExpanded {
                    expandedGroupIDs.remove(group.id)
                } else {
                    expandedGroupIDs.insert(group.id)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.header.title)
                            .font(AdminTheme.fontAdminSans(size: 16, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone900)
                            .multilineTextAlignment(.leading)

                        if !group.header.description.isEmpty {
                            Text(group.header.description)
                                .font(AdminTheme.fontAdminSans(size: 13))
                                .foregroundStyle(AdminTheme.stone600)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(PublicCatalogFormat.groupPrice(group.header.price))
                            .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                            .foregroundStyle(AdminTheme.stone700)

                        if hasChildren {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AdminTheme.stone500)
                        }
                    }
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)

            if isExpanded, hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.children) { child in
                        serviceRow(child, indented: true)
                    }
                }
                .padding(.leading, 16)
            }

            Divider()
                .overlay(AdminTheme.stone200)
        }
    }

    @ViewBuilder
    private func serviceRow(_ service: PublicCatalogService, indented: Bool) -> some View {
        let bookingURL: URL? = {
            guard let slug = service.slug else { return nil }
            return PublicCatalogFormat.calBookingURL(
                slug: slug,
                username: viewModel.calUsername
            )
        }()

        Group {
            if let bookingURL {
                Link(destination: bookingURL) {
                    serviceRowContent(service, indented: indented)
                }
            } else {
                serviceRowContent(service, indented: indented)
            }
        }
    }

    private func serviceRowContent(_ service: PublicCatalogService, indented: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.title)
                    .font(AdminTheme.fontAdminSans(size: indented ? 15 : 16, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                    .multilineTextAlignment(.leading)

                if !service.description.isEmpty {
                    Text(service.description)
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(PublicCatalogFormat.price(service.price))
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                if let minutes = service.durationMins, minutes > 0 {
                    Text(PublicCatalogFormat.duration(minutes))
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
        }
        .padding(.vertical, indented ? 10 : 12)
    }

    private func comingSoonBlock(category: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category)
                .font(AdminTheme.fontAdminSerif(size: 18))
                .foregroundStyle(AdminTheme.stone900)

            Text("Coming soon.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No services to show")
                .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AdminTheme.stone700)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        ServiceCatalogView()
    }
}
