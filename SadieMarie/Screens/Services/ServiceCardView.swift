import SwiftUI

enum ServiceCardVariant {
    case group
    case child
    case standalone
}

/// Compact full-width service row — aligned with booking list density.
struct ServiceCardView: View {
    let service: Service
    let variant: ServiceCardVariant
    var isArchiving: Bool
    var onEdit: () -> Void
    var onArchive: () -> Void

    @State private var isConfirmingDelete = false
    @State private var confirmResetTask: Task<Void, Never>?

    private var isGroup: Bool { variant == .group }

    var body: some View {
        HStack(alignment: .center, spacing: ServiceRowMetrics.columnSpacing) {
            priceColumn
            titleColumn
            Spacer(minLength: 8)
            actionsColumn
        }
        .padding(.horizontal, ServiceRowMetrics.rowPaddingHorizontal)
        .padding(.vertical, ServiceRowMetrics.rowPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .opacity(isArchiving ? 0.5 : 1)
        .onDisappear {
            confirmResetTask?.cancel()
        }
    }

    // MARK: - Columns

    private var priceColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isGroup {
                Text("From")
                    .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone500)
            }

            Text(ServiceFormat.price(service.price, prefixFrom: false))
                .font(AdminTheme.fontAdminSerif(size: ServiceRowMetrics.priceFontSize))
                .foregroundStyle(AdminTheme.stone900)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            if !isGroup, let mins = service.durationMins {
                Text("\(mins) min")
                    .font(AdminTheme.fontAdminSans(size: ServiceRowMetrics.metaFontSize))
                    .foregroundStyle(AdminTheme.stone500)
            }
        }
        .frame(width: ServiceRowMetrics.priceColumnWidth, alignment: .leading)
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isGroup {
                groupPill
            }

            Text(service.title)
                .font(AdminTheme.fontAdminSans(
                    size: ServiceRowMetrics.titleFontSize,
                    weight: .medium
                ))
                .foregroundStyle(AdminTheme.stone900)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !service.description.isEmpty {
                Text(service.description)
                    .font(AdminTheme.fontAdminSans(size: ServiceRowMetrics.metaFontSize))
                    .foregroundStyle(AdminTheme.stone500)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupPill: some View {
        Text("Group")
            .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(AdminTheme.cream)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(AdminTheme.stone900.opacity(0.88))
            .clipShape(Capsule())
    }

      private var actionsColumn: some View {
        Group {
            if isConfirmingDelete {
                HStack(spacing: ServiceRowMetrics.actionSpacing) {
                    Button("Cancel", action: cancelDelete)
                        .buttonStyle(ServiceSecondaryButtonStyle())
                        .disabled(isArchiving)

                    Button {
                        onArchive()
                    } label: {
                        Text(isArchiving ? "…" : "Confirm")
                    }
                    .buttonStyle(ServiceDestructiveButtonStyle())
                    .disabled(isArchiving)
                }
            } else {
                HStack(spacing: ServiceRowMetrics.actionSpacing) {
                    Button("Edit", action: onEdit)
                        .buttonStyle(ServiceSecondaryButtonStyle())

                    Button("Delete", action: primeDelete)
                        .buttonStyle(ServiceDeleteButtonStyle())
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var cardBackground: Color {
        switch variant {
        case .group:
            return AdminTheme.stone50.opacity(0.85)
        case .child, .standalone:
            return AdminTheme.cardFill
        }
    }

    private var borderColor: Color {
        if isConfirmingDelete { return AdminTheme.rose600.opacity(0.4) }
        return variant == .group ? AdminTheme.stone300 : AdminTheme.stone200
    }

    private func primeDelete() {
        isConfirmingDelete = true
        confirmResetTask?.cancel()
        confirmResetTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isConfirmingDelete = false
            }
        }
    }

    private func cancelDelete() {
        confirmResetTask?.cancel()
        isConfirmingDelete = false
    }
}

// MARK: - Metrics

private enum ServiceRowMetrics {
    static let priceColumnWidth: CGFloat = 68
    static let priceFontSize: CGFloat = 15
    static let titleFontSize: CGFloat = 14
    static let metaFontSize: CGFloat = 12
    static let columnSpacing: CGFloat = 12
    static let actionSpacing: CGFloat = 8
    static let rowPaddingHorizontal: CGFloat = 14
    static let rowPaddingVertical: CGFloat = 10
    static let buttonFontSize: CGFloat = 12
    static let buttonPaddingHorizontal: CGFloat = 12
    static let buttonPaddingVertical: CGFloat = 6
}

// MARK: - Button styles

private struct ServiceSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AdminTheme.fontAdminSans(size: ServiceRowMetrics.buttonFontSize, weight: .medium))
            .foregroundStyle(AdminTheme.stone700)
            .padding(.horizontal, ServiceRowMetrics.buttonPaddingHorizontal)
            .padding(.vertical, ServiceRowMetrics.buttonPaddingVertical)
            .background(AdminTheme.cardFill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AdminTheme.stone200, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ServiceDeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AdminTheme.fontAdminSans(size: ServiceRowMetrics.buttonFontSize, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .padding(.horizontal, ServiceRowMetrics.buttonPaddingHorizontal)
            .padding(.vertical, ServiceRowMetrics.buttonPaddingVertical)
            .background(AdminTheme.cardFill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AdminTheme.stone200, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ServiceDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AdminTheme.fontAdminSans(size: ServiceRowMetrics.buttonFontSize, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, ServiceRowMetrics.buttonPaddingHorizontal)
            .padding(.vertical, ServiceRowMetrics.buttonPaddingVertical)
            .background(AdminTheme.rose600)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: AdminTheme.Spacing.cardStack) {
            ServiceCardView(
                service: .previewGroup,
                variant: .group,
                isArchiving: false,
                onEdit: {},
                onArchive: {}
            )
            ServiceCardView(
                service: .previewChild,
                variant: .child,
                isArchiving: false,
                onEdit: {},
                onArchive: {}
            )
            .padding(.leading, 16)
            ServiceCardView(
                service: .previewStandalone,
                variant: .standalone,
                isArchiving: false,
                onEdit: {},
                onArchive: {}
            )
        }
        .padding()
    }
    .background(AdminTheme.cream)
}
