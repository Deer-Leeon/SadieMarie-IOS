import SwiftUI
import ClerkKit

/// Clients tab — searchable CRM directory (mirrors `/admin/clients`).
struct ClientsView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(PushRegistration.self) private var pushRegistration
    @Bindable var viewModel: ClientsViewModel
    @State private var selectedClient: Client?
    @State private var showAddClient = false

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBlock
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    searchBar
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                        .padding(.bottom, 10)

                    toolbarRow
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                        .padding(.bottom, 12)

                    if let notice = viewModel.refreshNotice {
                        RefreshNoticeText(notice: notice)
                            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                            .padding(.bottom, 8)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                            .padding(.bottom, 8)
                    }

                    listContent
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
                await viewModel.load()
            }
            .onChange(of: pushRegistration.liveDataRevision) { _, _ in
                Task {
                    guard clerk.user != nil else { return }
                    await viewModel.load(showLoading: false, reason: .resume)
                }
            }
            .onChange(of: pushRegistration.pendingOpenClientId) { _, clientId in
                guard clientId != nil else { return }
                Task { await openPendingPushClientIfNeeded() }
            }
            .onAppear {
                if pushRegistration.pendingOpenClientId != nil {
                    Task { await openPendingPushClientIfNeeded() }
                }
            }
            .refreshable {
                guard clerk.user != nil else { return }
                await viewModel.load(showLoading: false, reason: .user)
            }
            .navigationDestination(item: $selectedClient) { client in
                ClientProfileView(
                    entry: .directory(client),
                    backLabel: "Clients",
                    onBack: { selectedClient = nil },
                    onClose: { selectedClient = nil },
                    onMutated: { Task { await viewModel.load(showLoading: false) } },
                    onClientUpdated: { updated in
                        viewModel.upsert(updated)
                        selectedClient = updated
                    },
                    embedInNavigationStack: false
                )
            }
            .sheet(isPresented: $showAddClient) {
                AddClientSheet(
                    onCancel: { showAddClient = false },
                    onCreated: { client in
                        viewModel.upsert(client)
                        showAddClient = false
                        selectedClient = client
                    }
                )
            }
        }
    }

    private var headerBlock: some View {
        HStack(alignment: .center) {
            Text("Clients")
                .font(AdminTheme.fontAdminSerif(size: 28))
                .foregroundStyle(AdminTheme.stone900)

            Spacer(minLength: 12)

            Button {
                showAddClient = true
            } label: {
                Text("New\nClient")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AdminTheme.stone700)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AdminTheme.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AdminTheme.stone200, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Client")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)

            TextField("Search name, email, or phone", text: $viewModel.searchQuery)
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone900)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AdminTheme.cardFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var toolbarRow: some View {
        HStack {
            Text("\(viewModel.filteredCount) of \(viewModel.totalCount) clients")
                .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            Spacer()

            Menu {
                Picker("Sort", selection: $viewModel.sortBy) {
                    ForEach(ClientSortOption.allCases) { option in
                        Text(option.menuTitle).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.sortBy.menuTitle)
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AdminTheme.stone900)
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.filteredClients.isEmpty {
            if viewModel.refreshNotice != .pullToTryAgain {
                emptyState
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AdminTheme.Spacing.cardStack) {
                    ForEach(viewModel.filteredClients) { client in
                        ClientRowView(client: client, onSelect: { selectedClient = client })
                    }
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.bottom, AdminTheme.Spacing.listVertical)
                .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 48)

                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)

                    Text(emptySubtitle)
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone700)
                        .multilineTextAlignment(.center)

                    if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       viewModel.errorMessage == nil {
                        Button {
                            showAddClient = true
                        } label: {
                            Text("New Client")
                                .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                                .foregroundStyle(AdminTheme.stone900)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AdminTheme.cream)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AdminTheme.stone200, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .strokeBorder(
                            AdminTheme.stone200,
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                )

                Spacer(minLength: 48)
            }
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
        }
    }

    private var emptyTitle: String {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No results"
        }
        if viewModel.errorMessage != nil {
            return "No clients to show"
        }
        return "No clients yet"
    }

    private var emptySubtitle: String {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try a different name, email, or phone number."
        }
        return "Add people you already work with, or wait for bookings to come in. Saving a client does not text or email them."
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
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }

    private func openPendingPushClientIfNeeded() async {
        guard let clientId = pushRegistration.pendingOpenClientId else { return }
        let needle = clientId.lowercased()
        if viewModel.clients.first(where: { $0.id.lowercased() == needle }) == nil {
            await viewModel.load(showLoading: false, reason: .resume)
        }
        if let found = viewModel.clients.first(where: { $0.id.lowercased() == needle }) {
            selectedClient = found
        }
        _ = pushRegistration.consumePendingOpenClientId()
    }
}

#Preview {
    ClientsView(viewModel: ClientsViewModel())
        .environment(PushRegistration.shared)
}
