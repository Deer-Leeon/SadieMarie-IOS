import SwiftUI

/// Centered past-history overlay. The card hugs its appointments until it
/// reaches the screen, then the list scrolls (pinned to the most recent visit).
struct PastAppointmentsPopup: View {
    let appointments: [Appointment]
    var onSelectAppointment: ((Appointment) -> Void)?
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let maxWidth = min(geo.size.width - 40, 520)
            let maxHeight = max(geo.size.height - 48, 200)

            ZStack {
                ZStack {
                    AdminTheme.cream.opacity(0.72)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Dismiss past appointments")

                VStack(spacing: 0) {
                    header

                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)

                    PastAppointmentsPopupList(
                        appointments: appointments,
                        maxHeight: max(maxHeight - 56, 80),
                        onSelectAppointment: onSelectAppointment
                    )
                }
                .frame(width: maxWidth)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Past appointments")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 28, height: 28)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct PastAppointmentsPopupList: View {
    let appointments: [Appointment]
    let maxHeight: CGFloat
    var onSelectAppointment: ((Appointment) -> Void)?

    @State private var contentHeight: CGFloat = 0
    @State private var didPinToBottom = false

    private var needsScroll: Bool {
        contentHeight > maxHeight + 1
    }

    var body: some View {
        Group {
            if needsScroll {
                ScrollViewReader { proxy in
                    ScrollView {
                        listContent
                    }
                    .frame(height: maxHeight)
                    .onAppear {
                        pinToBottom(using: proxy)
                    }
                }
            } else {
                listContent
            }
        }
        .onPreferenceChange(PastPopupContentHeightKey.self) { height in
            if height > 0 {
                contentHeight = height
            }
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
            BookingsDaySectionRows(
                appointments: appointments,
                onSelectAppointment: onSelectAppointment,
                headerSurface: AdminTheme.cardFill
            )
            Color.clear
                .frame(height: 1)
                .id("past-bottom")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: PastPopupContentHeightKey.self,
                    value: geo.size.height
                )
            }
        }
    }

    private func pinToBottom(using proxy: ScrollViewProxy) {
        guard !didPinToBottom else { return }
        didPinToBottom = true
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo("past-bottom", anchor: .bottom)
            }
            DispatchQueue.main.async {
                withTransaction(transaction) {
                    proxy.scrollTo("past-bottom", anchor: .bottom)
                }
            }
        }
    }
}

private struct PastPopupContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
