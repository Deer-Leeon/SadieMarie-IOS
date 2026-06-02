import SwiftUI
import UIKit

/// Aspect-ratio–locked crop UI before uploading a site image.
struct WebsiteImageCropSheet: View {
    let label: String
    let aspectRatio: CGFloat
    let requiresCaption: Bool
    let initialCaption: String
    let image: UIImage
    let onCancel: () -> Void
    let onSave: (Data, String?) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var caption: String = ""
    @State private var cropSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                AdminTheme.cream.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text(label)
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)

                    GeometryReader { geometry in
                        let frame = WebsiteImageProcessing.cropFrameSize(
                            aspectRatio: aspectRatio,
                            maxWidth: geometry.size.width,
                            maxHeight: geometry.size.height
                        )

                        ZStack {
                            Color.black.opacity(0.55)
                                .ignoresSafeArea()

                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: frame.width, height: frame.height)
                                .scaleEffect(scale)
                                .offset(offset)
                                .frame(width: frame.width, height: frame.height)
                                .clipped()
                                .overlay {
                                    RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius)
                                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: WebsiteLayout.cardRadius))
                                .gesture(dragGesture)
                                .simultaneousGesture(magnificationGesture)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            cropSize = frame
                            resetCropTransform()
                        }
                        .onChange(of: frame) { _, newFrame in
                            cropSize = newFrame
                        }
                    }
                    .frame(height: min(360, UIScreen.main.bounds.height * 0.42))

                    if requiresCaption {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption")
                                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                                .foregroundStyle(AdminTheme.stone700)

                            TextField("Shown on the portfolio tile", text: $caption)
                                .font(AdminTheme.fontAdminSans(size: 15))
                                .foregroundStyle(AdminTheme.stone900)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(AdminTheme.cardFill)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AdminTheme.stone200, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Crop & replace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(AdminTheme.stone700)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        guard let data = WebsiteImageProcessing.croppedJPEGData(
                            from: image,
                            aspectRatio: aspectRatio,
                            scale: scale,
                            offset: offset,
                            cropSize: cropSize
                        ) else { return }
                        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(data, trimmedCaption.isEmpty ? nil : trimmedCaption)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AdminTheme.stone900)
                }
            }
            .onAppear {
                caption = initialCaption
                resetCropTransform()
            }
        }
        .preferredColorScheme(.light)
    }

    private func resetCropTransform() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = lastScale * value
                scale = min(max(next, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}

enum WebsiteLayout {
    static let cardRadius: CGFloat = 12

    /// Mobile portfolio tile width on the web admin (`max-[860px]:w-[65%]`).
    static let portfolioTileWidthFraction: CGFloat = 0.65
    static let portfolioCollageGap: CGFloat = 8
    static let portfolioCollageInnerPadding: CGFloat = 10

    /// Empty portfolio tile fill (`#1C2E42` on web).
    static let portfolioEmptyBackground = Color(red: 28 / 255, green: 46 / 255, blue: 66 / 255)
}
