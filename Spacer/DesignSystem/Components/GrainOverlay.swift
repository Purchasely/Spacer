//
//  GrainOverlay.swift
//  Spacer
//
//  Subtle film grain over dark surfaces. Dark gradients band badly and read as
//  "flat AI"; a few percent of tiled noise defeats both. Disabled under Reduce
//  Transparency. The noise tile is generated once (deterministic LCG, no per-frame
//  cost) and reused.
//

import SwiftUI
import UIKit

struct GrainOverlay: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceTransparency {
                Image(uiImage: Self.tile)
                    .resizable(resizingMode: .tile)
                    .opacity(0.045)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }

    /// 120×120 grayscale noise tile, built once.
    private static let tile: UIImage = makeNoise(side: 120)

    private nonisolated static func makeNoise(side: Int) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> UInt8 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return UInt8((seed >> 56) & 0xFF)
        }
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let v = next()
            pixels[i] = v; pixels[i + 1] = v; pixels[i + 2] = v; pixels[i + 3] = 255
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        // Keep the buffer alive while the context uses it and produces the image.
        let cgImage: CGImage? = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo) else {
                return nil
            }
            return ctx.makeImage()
        }
        return cgImage.map { UIImage(cgImage: $0) } ?? UIImage()
    }
}

extension View {
    /// Overlays subtle film grain (no-op under Reduce Transparency).
    func filmGrain() -> some View { modifier(GrainOverlay()) }
}
