import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

enum LyricsState: Equatable {
    case idle, loading, none
    case synced([LyricLine])
    case plain([String])
}

/// Fetches time-synced lyrics from LRCLIB (https://lrclib.net), a free community database.
enum LyricsService {
    private struct Response: Decodable {
        var syncedLyrics: String?
        var plainLyrics: String?
        var duration: Double?
    }

    /// "Song - Remastered 2011" / "Song (feat. X)" -> "Song"
    private static func cleanTitle(_ t: String) -> String {
        var s = t
        if let r = s.range(of: " - ") { s = String(s[..<r.lowerBound]) }
        while let o = s.firstIndex(of: "("), let c = s[o...].firstIndex(of: ")") { s.removeSubrange(o...c) }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Share of letters written in Latin script (1 = fully English / Hinglish / romanized Punjabi).
    static func latinRatio(_ text: String) -> Double {
        var latin = 0, total = 0
        for u in text.unicodeScalars where CharacterSet.letters.contains(u) {
            total += 1
            if u.value < 0x250 { latin += 1 }
        }
        return total == 0 ? 1 : Double(latin) / Double(total)
    }

    private static func isRoman(_ r: Response) -> Bool { latinRatio(r.syncedLyrics ?? r.plainLyrics ?? "") >= 0.8 }

    /// Picks the best lyrics: matching length first, then synced over plain, then — when `preferRoman` —
    /// English / Hinglish / romanized text over the original script. If no roman version exists the native script is used.
    static func fetch(for track: Track, preferRoman: Bool = true) async -> LyricsState {
        var found: [Response] = []
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist),
            .init(name: "album_name", value: track.album),
            .init(name: "duration", value: String(Int(track.duration.rounded()))),
        ]
        if let r = await request(comps.url!, as: Response.self) {
            if !preferRoman || isRoman(r), let state = state(from: r) { return state }
            found.append(r)
        }

        // Search several phrasings (LRCLIB often holds clips, live cuts and alternate scripts of one song).
        let title = cleanTitle(track.title)
        func good(_ r: Response) -> Bool {
            abs((r.duration ?? 0) - track.duration) <= 10 && !(r.syncedLyrics ?? "").isEmpty && (!preferRoman || isRoman(r))
        }
        for q in ["\(track.title) \(track.artist)", "\(title) \(track.artist)", title] {
            var search = URLComponents(string: "https://lrclib.net/api/search")!
            search.queryItems = [.init(name: "q", value: q)]
            if let list = await request(search.url!, as: [Response].self) { found += list }
            if found.contains(where: good) { break }
        }

        func rank(_ r: Response) -> Double {
            var score = abs((r.duration ?? 0) - track.duration)
            if score > 10 { score += 1000 }                                   // wrong length: last resort
            if (r.syncedLyrics ?? "").isEmpty { score += 100 }                 // plain is worse than synced
            if preferRoman, !isRoman(r) { score += 50 }                        // native script only if nothing roman
            return score
        }
        for r in found.sorted(by: { rank($0) < rank($1) }) where abs((r.duration ?? 0) - track.duration) <= 10 {
            if let s = state(from: r) { return s }
        }
        return .none
    }

    private static func request<T: Decodable>(_ url: URL, as: T.Type) async -> T? {
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("Lyrcing/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func state(from r: Response) -> LyricsState? {
        if let s = r.syncedLyrics, !s.isEmpty {
            let lines = parseLRC(s)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let p = r.plainLyrics, !p.isEmpty {
            return .plain(p.components(separatedBy: .newlines))
        }
        return nil
    }

    static func parseLRC(_ lrc: String) -> [LyricLine] {
        let stamp = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var raw: [(Double, String)] = []
        for line in lrc.components(separatedBy: .newlines) {
            let ns = line as NSString
            let matches = stamp.matches(in: line, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let text = ns.substring(from: last.range.upperBound).trimmingCharacters(in: .whitespaces)
            for m in matches {
                let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
                raw.append((min * 60 + sec, text))
            }
        }
        raw.sort { $0.0 < $1.0 }
        return raw.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}
