import SwiftUI
import UIKit

/// Loads remote images with `URLSession` instead of `AsyncImage`.
/// `AsyncImage` often stalls on Vercel Blob CDN URLs used by the website CMS.
struct RemoteImageView<Placeholder: View, Failure: View>: View {
    let url: URL
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                renderedImage(image)
            } else if didFail {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url.absoluteString) {
            await loadImage()
        }
    }

    @ViewBuilder
    private func renderedImage(_ uiImage: UIImage) -> some View {
        if contentMode == .fill {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadImage() async {
        image = nil
        didFail = false

        var request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                didFail = true
                return
            }
            guard let uiImage = UIImage(data: data) else {
                didFail = true
                return
            }
            image = uiImage
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}
