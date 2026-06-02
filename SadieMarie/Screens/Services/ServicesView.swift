import SwiftUI
import ClerkKit

/// Services tab — CMS catalogue (mirrors `/admin/services`).
struct ServicesView: View {
    @Environment(Clerk.self) private var clerk
    @State private var viewModel = ServicesViewModel()
    @State private var formMode: ServiceFormMode?
    @State private var formError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBlock
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                            .padding(.bottom, 8)
                    }

                    listContent
                }

                if viewModel.isLoading && viewModel.services.isEmpty {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .task(id: clerk.session?.id) {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }
            .refreshable {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }
            .sheet(item: $formMode) { mode in
                ServiceFormSheet(
                    mode: mode,
                    allServices: viewModel.services,
                    isSubmitting: viewModel.isSubmitting,
                    submitError: formError,
                    onCancel: {
                        formMode = nil
                        formError = nil
                    },
                    onSubmitCreate: { payload in
                        Task { await handleCreate(payload) }
                    },
                    onSubmitUpdate: { payload in
                        Task { await handleUpdate(payload) }
                    }
                )
            }
        }
    }

    private var headerBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Services")
                    .font(AdminTheme.fontAdminSerif(size: 28))
                    .foregroundStyle(AdminTheme.stone900)

                Text("Manage bookable offerings and group headers for the public site.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            NavigationLink {
                ServiceCatalogView()
            } label: {
                Label("Menu", systemImage: "menucard")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AdminTheme.cream)
                    .overlay(
                        Capsule()
                            .stroke(AdminTheme.stone300, lineWidth: 1)
                    )
            }
            .padding(.trailing, 8)

            Button {
                formError = nil
                formMode = .create
            } label: {
                Label("Add", systemImage: "plus")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .foregroundStyle(AdminTheme.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AdminTheme.stone900)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.services.isEmpty && !viewModel.isLoading {
            emptyState
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(
                    alignment: .leading,
                    spacing: AdminTheme.Spacing.cardStack,
                    pinnedViews: [.sectionHeaders]
                ) {
                    ForEach(viewModel.groupedCategories) { section in
                        Section {
                            sectionRows(section)
                        } header: {
                            categoryHeader(section)
                        }
                    }
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.vertical, AdminTheme.Spacing.listVertical)
                .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(AdminTheme.cream)
        }
    }

    @ViewBuilder
    private func sectionRows(_ section: ServiceCategorySection) -> some View {
        ForEach(section.groups) { groupSection in
            serviceRow(groupSection.group, variant: .group)

            if groupSection.children.isEmpty {
                emptyChildrenHint(for: groupSection.group)
                    .padding(.leading, 14)
            } else {
                ForEach(groupSection.children) { child in
                    serviceRow(child, variant: .child)
                        .padding(.leading, 14)
                }
            }
        }

        if !section.groups.isEmpty && !section.standalones.isEmpty {
            Color.clear.frame(height: 4)
        }

        ForEach(section.standalones) { service in
            serviceRow(service, variant: .standalone)
        }
    }

    private func serviceRow(
        _ service: Service,
        variant: ServiceCardVariant
    ) -> some View {
        ServiceCardView(
            service: service,
            variant: variant,
            isArchiving: viewModel.archivingId == service.id,
            onEdit: { openEdit(service) },
            onArchive: { Task { await viewModel.archive(id: service.id) } }
        )
    }

    private func categoryHeader(_ section: ServiceCategorySection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section.category)
                .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                .tracking(AdminTheme.Typography.dayHeaderTracking)
                .textCase(.uppercase)
                .foregroundStyle(AdminTheme.stone700)

            Spacer()

            Text("\(section.serviceCount) \(section.serviceCount == 1 ? "service" : "services")")
                .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AdminTheme.stone500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AdminTheme.Spacing.stickyHeaderVertical)
        .background(AdminTheme.cream.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 1)
        }
    }

    private func emptyChildrenHint(for group: Service) -> some View {
        Text("No child services yet. Add one and nest it under “\(group.title)”.")
            .font(AdminTheme.fontAdminSans(size: 12))
            .foregroundStyle(AdminTheme.stone500)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, AdminTheme.Spacing.rowHorizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No services yet")
                .font(AdminTheme.fontAdminSerif(size: 20))
                .foregroundStyle(AdminTheme.stone900)

            Text("Add your first service to publish it to the booking page and site menu.")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone500)
                .multilineTextAlignment(.center)

            Button {
                formMode = .create
            } label: {
                Label("Add your first service", systemImage: "plus")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AdminTheme.stone900)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AdminTheme.cardFill.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AdminTheme.stone300, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func openEdit(_ service: Service) {
        formError = nil
        formMode = .edit(service)
    }

    private func handleCreate(_ payload: CreateServicePayload) async {
        formError = nil
        do {
            try await viewModel.create(payload)
            formMode = nil
        } catch let error as AdminAPIError {
            formError = error.localizedDescription
        } catch {
            formError = error.localizedDescription
        }
    }

    private func handleUpdate(_ payload: UpdateServicePayload) async {
        formError = nil
        do {
            try await viewModel.update(payload)
            formMode = nil
        } catch let error as AdminAPIError {
            formError = error.localizedDescription
        } catch {
            formError = error.localizedDescription
        }
    }
}

#Preview {
    ServicesView()
}
