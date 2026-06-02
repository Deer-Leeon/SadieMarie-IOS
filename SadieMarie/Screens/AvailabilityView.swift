import SwiftUI
import ClerkKit

/// Availability tab — weekly hours + date overrides (mirrors `/admin/availability`).
struct AvailabilityView: View {
    @Environment(Clerk.self) private var clerk
    @State private var viewModel = AvailabilityViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBlock

                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }

                        if let success = viewModel.saveSuccessMessage {
                            successBanner(success)
                        }

                        AvailabilityWeeklySection(viewModel: viewModel)
                        AvailabilityOverridesSection(viewModel: viewModel)
                    }
                    .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .safeAreaInset(edge: .bottom) {
                AvailabilitySaveBar(
                    hasChanges: viewModel.hasUnsavedChanges,
                    isSaving: viewModel.isSaving,
                    action: { Task { await viewModel.save() } }
                )
            }
            .task(id: clerk.session?.id) {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }
            .refreshable {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Availability")
                .font(AdminTheme.fontAdminSerif(size: 28))
                .foregroundStyle(AdminTheme.stone900)

            Text(viewModel.timeZoneEyebrow)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                .tracking(AdminTheme.Typography.dayHeaderTracking)
                .foregroundStyle(AdminTheme.stone700)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(12)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func successBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 14))
            .foregroundStyle(AdminTheme.confirmedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AdminTheme.confirmedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AvailabilityView()
}
