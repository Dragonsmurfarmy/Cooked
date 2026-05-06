//
//  Imagecropper.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import UIKit

struct ImageCropper: View {
    let image: UIImage
    @Binding var visibleImageData: Data?
    @Binding var isShown: Bool
    @Environment(\.dismiss) var dismiss
   

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Geometry tracking to capture the position for cropping
    @State private var viewSize: CGSize = .zero

    private let cropFrameSize: CGFloat = 300

    var body: some View {
        ZStack {
                    Color.black.ignoresSafeArea()

                    // THE IMAGE LAYER
                    // We put the image in a fixed frame so 'offset'
                    // is relative to the crop square, not the whole screen.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropFrameSize, height: cropFrameSize)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                                .simultaneously(with:
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { _ in lastScale = scale }
                                )
                        )

                    // THE OVERLAY LAYER
                    // Dim everything ELSE but the 300x300 center
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .mask(
                            ZStack {
                                Rectangle() // Full screen dim
                                Rectangle() // The "Hole"
                                    .frame(width: cropFrameSize, height: cropFrameSize)
                                    .blendMode(.destinationOut)
                            }
                        )
                        .allowsHitTesting(false)

                    // THE BORDER
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: cropFrameSize, height: cropFrameSize)
                        .allowsHitTesting(false)
                }
            .navigationTitle("image.crop")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)   // Makes text white
            .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("button.cancel") {
                                isShown = false // Manually turn off navigation
                                dismiss()
                            }
                        }
                    
                    ToolbarItem(placement: .principal) {
                        Button("button.reset") {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                ToolbarItem(placement: .confirmationAction) {
                                Button("button.done") {
                                    saveCroppedImage()
                                    isShown = false // Manually turn off navigation
                                    dismiss()
                                }
                            }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func saveCroppedImage() {
        let outputSize = CGSize(width: cropFrameSize, height: cropFrameSize)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        
        // Important: Handle image orientation correctly
        let uiImage = image.fixedOrientation()

        let croppedImage = renderer.image { context in
            let canvasCenter = cropFrameSize / 2
            context.cgContext.translateBy(x: canvasCenter, y: canvasCenter)
            
            context.cgContext.scaleBy(x: scale, y: scale)
            
            // We use the raw offset from the UI
            context.cgContext.translateBy(x: offset.width / scale, y: offset.height / scale)
            
            let aspectRatio = uiImage.size.width / uiImage.size.height
            let drawSize: CGSize
            if aspectRatio > 1 {
                drawSize = CGSize(width: cropFrameSize * aspectRatio, height: cropFrameSize)
            } else {
                drawSize = CGSize(width: cropFrameSize, height: cropFrameSize / aspectRatio)
            }
            
            uiImage.draw(in: CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        
        visibleImageData = croppedImage.jpegData(compressionQuality: 0.8)
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}
