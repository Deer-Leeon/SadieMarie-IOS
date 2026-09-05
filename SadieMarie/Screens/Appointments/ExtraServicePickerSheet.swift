import SwiftUI

/// Catalogue picker for attaching an extra to a confirmed visit.
struct ExtraServicePickerSheet: View {
    var onSelect: (ManualBookingServiceOption) -> Void
    var onCancel: () -> Void

    @State private var catalog = ManualBookingViewModel(initialDate: Date())
    @State private var expandedGroupIDs: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if catalog.isLoadingServices {
                        ProgressView("Loading services…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else if !catalog.hasBookableServices {
                        Text("No bookable services found.")
                            .font(AdminTheme.fontAdminSans(size: 14))
                            .foregroundStyle(AdminTheme.stone500)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(catalog.serviceSections) { section in
                            sectionView(section)
                        }
                    }
                    if let error = catalog.errorMessage {
                        Text(error)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(Color.semanticRed)
                    }
                }
                .padding(AdminTheme.Spacing.listHorizontal)
                .padding(.bottom, 24)
            }
            .background(AdminTheme.cream)
            .navigationTitle("Add extra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .task {
            await catalog.loadServicesIfNeeded()
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ManualBookingServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !section.category.isEmpty {
                Text(section.category)
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
            }
            ForEach(section.rows) { row in
                switch row {
                case .group(let group):
                    groupRow(group)
                case .service(let service):
                    serviceRow(service)
                }
            }
        }
    }

    private func groupRow(_ group: ManualBookingGroupRow) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                if isExpanded {
                    expandedGroupIDs.remove(group.id)
                } else {
                    expandedGroupIDs.insert(group.id)
                }
            } label: {
                HStack {
                    Text(group.title)
                        .font(AdminTheme.fontAdminSerif(size: 17))
                        .foregroundStyle(AdminTheme.stone900)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .padding(14)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(group.children) { child in
                    serviceRow(child)
                        .padding(.leading, 12)
                }
            }
        }
    }

    private func serviceRow(_ service: ManualBookingServiceOption) -> some View {
        Button {
            onSelect(service)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.title)
                    .font(AdminTheme.fontAdminSerif(size: 16))
                    .foregroundStyle(AdminTheme.stone900)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !service.detailMetaLine.isEmpty {
                    Text(service.detailMetaLine)
                        .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(AdminTheme.stone500)
                        .textCase(.uppercase)
                }
            }
            .padding(14)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
