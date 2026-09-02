import SwiftUI

/// Quiet diagonal wash for official closed hours on the admin time grid.
/// Distinct from blocked-time pills — this is background, not a hold.
struct ClosedHoursHatchFill: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(AdminTheme.stone200.opacity(0.55))
            )

            let spacing: CGFloat = 6
            var path = Path()
            var offset = -size.height
            while offset < size.width {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                offset += spacing
            }
            context.stroke(
                path,
                with: .color(AdminTheme.stone500.opacity(0.28)),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ClosedHoursHatchBands: View {
    let bands: [StudioScheduleWindows.MinuteBand]
    let hourHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                let y = StudioScheduleWindows.yOffset(
                    forStartMins: band.startMins,
                    hourHeight: hourHeight
                )
                let height = StudioScheduleWindows.bandHeight(
                    startMins: band.startMins,
                    endMins: band.endMins,
                    hourHeight: hourHeight
                )
                ClosedHoursHatchFill()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: max(height, 0), alignment: .top)
                    .padding(.top, y)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
