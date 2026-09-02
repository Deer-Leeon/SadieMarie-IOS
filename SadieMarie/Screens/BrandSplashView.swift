import SwiftUI
import UIKit

/// Layout tokens shared with `LaunchScreen.storyboard` so the system launch
/// image and the SwiftUI splash occupy the same pixels.
enum BrandSplashLayout {
    static let logoWidthFraction: CGFloat = 0.58
    /// Exact corner pixel of the logo file (`#F4F3EF`). Named asset colors
    /// are not available on the iOS launch screen and fall back to white.
    static let background = Color(
        red: 244 / 255,
        green: 243 / 255,
        blue: 239 / 255
    )
    static let uiBackground = UIColor(
        red: 244 / 255,
        green: 243 / 255,
        blue: 239 / 255,
        alpha: 1
    )
}

/// Full-screen brand mark. Uses the same UIImageView constraints as
/// `LaunchScreen.storyboard` so the system splash and this view are one frame.
struct BrandSplashView: View {
    var logoScale: CGFloat = 1
    var opacity: Double = 1

    var body: some View {
        BrandSplashBacking(logoScale: logoScale, opacity: opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(opacity > 0.05)
    }
}

private struct BrandSplashBacking: UIViewRepresentable {
    var logoScale: CGFloat
    var opacity: Double

    func makeUIView(context: Context) -> BrandSplashBackingView {
        BrandSplashBackingView()
    }

    func updateUIView(_ uiView: BrandSplashBackingView, context: Context) {
        uiView.setLogoScale(
            logoScale,
            opacity: opacity,
            animated: context.transaction.animation != nil
        )
    }
}

/// Mirrors `LaunchScreen.storyboard`: cream fill, logo width = 58% of the
/// view, centered on the full screen (not the safe area).
final class BrandSplashBackingView: UIView {
    private let imageView = UIImageView(image: UIImage(named: "BrandLogo"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = BrandSplashLayout.uiBackground
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(
                equalTo: widthAnchor,
                multiplier: BrandSplashLayout.logoWidthFraction
            ),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])
    }

    func setLogoScale(_ scale: CGFloat, opacity: Double, animated: Bool) {
        let changes = {
            self.imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.imageView.alpha = opacity
            self.backgroundColor = BrandSplashLayout.uiBackground.withAlphaComponent(opacity)
        }
        if animated {
            UIView.animate(
                withDuration: 0.72,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .curveEaseOut]
            ) {
                changes()
            }
        } else {
            changes()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#Preview {
    BrandSplashView()
}
