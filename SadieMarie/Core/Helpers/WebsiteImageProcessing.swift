import CoreGraphics
import UIKit

enum WebsiteImageProcessing {

    static func jpegData(from image: UIImage, quality: CGFloat = 0.88) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    /// Renders the visible region inside an aspect-ratio crop frame.
    static func croppedJPEGData(
        from image: UIImage,
        aspectRatio: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        cropSize: CGSize,
        compressionQuality: CGFloat = 0.88
    ) -> Data? {
        let cropped = croppedImage(
            from: image,
            aspectRatio: aspectRatio,
            scale: scale,
            offset: offset,
            cropSize: cropSize
        )
        return jpegData(from: cropped, quality: compressionQuality)
    }

    static func croppedImage(
        from image: UIImage,
        aspectRatio: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        cropSize: CGSize
    ) -> UIImage {
        let normalized = image.normalizedOrientation()
        let renderer = UIGraphicsImageRenderer(size: cropSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: cropSize.width / 2 + offset.width, y: cropSize.height / 2 + offset.height)
            context.cgContext.scaleBy(x: scale, y: scale)
            let drawSize = fittedSize(for: normalized.size, in: cropSize)
            normalized.draw(
                in: CGRect(
                    x: -drawSize.width / 2,
                    y: -drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
            )
        }
    }

    static func cropFrameSize(
        aspectRatio: CGFloat,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGSize {
        guard aspectRatio > 0 else { return CGSize(width: maxWidth, height: maxWidth) }

        if aspectRatio >= 1 {
            let width = maxWidth
            let height = width / aspectRatio
            if height <= maxHeight {
                return CGSize(width: width, height: height)
            }
            let fittedHeight = maxHeight
            return CGSize(width: fittedHeight * aspectRatio, height: fittedHeight)
        }

        let height = min(maxHeight, maxWidth / aspectRatio)
        return CGSize(width: height * aspectRatio, height: height)
    }

    private static func fittedSize(for imageSize: CGSize, in cropSize: CGSize) -> CGSize {
        let widthScale = cropSize.width / max(imageSize.width, 1)
        let heightScale = cropSize.height / max(imageSize.height, 1)
        let fill = max(widthScale, heightScale)
        return CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
