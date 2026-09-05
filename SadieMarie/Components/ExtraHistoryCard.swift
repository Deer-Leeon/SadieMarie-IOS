import SwiftUI

/// L from the parent time column into nested extra cards — web `border-b-2 border-l-2`.
private struct ExtraNestConnector: View {
    var body: some View {
        ExtraLConnectorShape()
            .stroke(
                AdminTheme.stone500.opacity(0.9),
                style: StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .round)
            )
            .frame(width: 44, height: 20)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ExtraLConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// Nested extras under a client-history visit, with the L connector.
struct NestedVisitExtras: View {
    let extras: [Appointment]
    var muted: Bool = false
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(extras) { extra in
                ExtraHistoryCard(extra: extra, muted: muted)
                    .contentShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                    .onTapGesture { onSelect?() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(
                        "Open visit extra · \(BookingDisplay.appointmentServiceLabel(extra))"
                    )
            }
        }
        .padding(.leading, 76)
        .padding(.top, 4)
        .overlay(alignment: .topLeading) {
            ExtraNestConnector()
                .padding(.leading, 32)
                .offset(y: -8)
        }
    }
}

/// Smaller service-colored extra row nested under a parent visit in history.
struct ExtraHistoryCard: View {
    let extra: Appointment
    var muted: Bool = false

    private var colors: BookingDisplay.ServiceColor? {
        muted ? nil : BookingDisplay.serviceColor(for: extra)
    }

    private var priceLabel: String? {
        BookingDisplay.formattedPrice(extra.servicePrice)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(BookingDisplay.appointmentServiceLabel(extra))
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(colors?.text ?? AdminTheme.stone900)
                    .lineLimit(1)
                Text("Extra")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(colors?.textMuted ?? AdminTheme.stone500)
            }
            Spacer(minLength: 8)
            if let priceLabel {
                Text(priceLabel)
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(colors?.text ?? AdminTheme.stone700)
            }
            if extra.terminalPayment?.isSettled == true {
                if let label = BookingDisplay.settlementLabel(for: extra.terminalPayment) {
                    Text(label)
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(AdminTheme.confirmedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AdminTheme.confirmedBackground)
                        .clipShape(Capsule())
                }
            } else {
                Text("Unpaid")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone500)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(AdminTheme.stone200.opacity(0.8), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors?.accent ?? AdminTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(colors == nil ? AdminTheme.stone200 : Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .opacity(muted ? 0.7 : 1)
    }
}
