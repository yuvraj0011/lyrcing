import AppKit
import SwiftUI

struct Palette: Equatable {
    var colors: [Color]
    static let fallback = Palette(colors: [
        Color(hue: 0.72, saturation: 0.7, brightness: 0.85),
        Color(hue: 0.92, saturation: 0.65, brightness: 0.9),
        Color(hue: 0.55, saturation: 0.7, brightness: 0.85),
    ])
}

/// Looks up cover art through the iTunes Search API and extracts a vivid palette from it.
enum ArtworkService {
    private struct Search: Decodable {
        struct Item: Decodable { var artworkUrl100: String? }
        var results: [Item]
    }

    static func fetch(for track: Track) async -> (NSImage, Palette)? {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            .init(name: "term", value: "\(track.artist) \(track.title)"),
            .init(name: "entity", value: "song"),
            .init(name: "limit", value: "1"),
        ]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let s = try? JSONDecoder().decode(Search.self, from: data),
              let small = s.results.first?.artworkUrl100,
              let url = URL(string: small.replacingOccurrences(of: "100x100", with: "600x600")),
              let (imgData, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: imgData) else { return nil }
        return (img, palette(from: img))
    }

    static func palette(from image: NSImage) -> Palette {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .fallback }
        let n = 24
        var px = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .fallback }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))

        // Bucket by hue, weighted toward saturated, bright pixels.
        var weight = [Double](repeating: 0, count: 12)
        var sat = [Double](repeating: 0, count: 12)
        var bri = [Double](repeating: 0, count: 12)
        for i in 0..<(n * n) {
            let c = NSColor(red: CGFloat(px[i * 4]) / 255, green: CGFloat(px[i * 4 + 1]) / 255,
                            blue: CGFloat(px[i * 4 + 2]) / 255, alpha: 1)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            let w = Double(s * s * b) + 0.001
            let k = min(11, Int(h * 12))
            weight[k] += w; sat[k] += Double(s) * w; bri[k] += Double(b) * w
        }
        let order = weight.indices.sorted { weight[$0] > weight[$1] }
        var picked: [Int] = []
        for k in order where weight[k] > 0.05 {
            if picked.allSatisfy({ min(abs($0 - k), 12 - abs($0 - k)) >= 2 }) { picked.append(k) }
            if picked.count == 3 { break }
        }
        guard !picked.isEmpty else { return .fallback }
        var colors = picked.map { k -> Color in
            Color(hue: (Double(k) + 0.5) / 12,
                  saturation: min(1, max(0.55, sat[k] / weight[k] * 1.1)),
                  brightness: min(1, max(0.75, bri[k] / weight[k] * 1.15)))
        }
        while colors.count < 3 { colors.append(colors[colors.count - 1]) }
        return Palette(colors: colors)
    }

    /// Stable palette for tracks without cover art.
    static func palette(seed: String) -> Palette {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let base = Double(h % 360) / 360
        return Palette(colors: [0, 0.12, 0.55].map {
            Color(hue: (base + $0).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.9)
        })
    }
}
