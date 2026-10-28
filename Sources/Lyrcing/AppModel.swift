import AppKit
import Combine
import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case constellation = "Constellation", classic = "Classic"
    var id: String { rawValue }
}

enum ColorMode: String, CaseIterable, Identifiable, Codable {
    case colorful = "Colorful", album = "Album color", white = "White"
    var id: String { rawValue }
}
enum EdgeStyle: String, CaseIterable, Identifiable, Codable {
    case glow = "Soft glow", line = "Thin line"
    var id: String { rawValue }
}
enum PlayerBarMode: String, CaseIterable, Identifiable, Codable {
    case auto = "Auto-hide", always = "Always show", hidden = "Hidden"
    var id: String { rawValue }
}
enum Preset: String, CaseIterable, Identifiable {
    case full = "Full", balanced = "Balanced", minimal = "Minimal"
    var id: String { rawValue }
}

/// Every visual element of the lyric view can be switched off individually.
struct Look: Codable, Equatable {
    var emphasis = true          // current word grows and glows
    var rings = true             // rings around the current word, beat ripples
    var burst = true             // sparkle burst + shockwave when a word lands
    var emojiExplosions = true   // emoji thrown out of emoji words
    var moodParticles = true     // hearts, rain, embers, confetti ...
    var stars = true             // twinkling background stars
    var connections = true       // lines between words
    var sparks = true            // light travelling along the lines
    var entrance = true          // slam / spin / zoom word entrances
    var cameraMotion = true      // slow drift and beat zoom
    var colorWash = true         // soft glow of the word's color behind it
    var colorMode = ColorMode.colorful
    var edgeStyle = EdgeStyle.glow
    var playerBar = PlayerBarMode.auto
}

enum Effects: String, CaseIterable, Identifiable {
    case calm = "Calm", normal = "Normal", wild = "Wild"
    var id: String { rawValue }
    var factor: Double { self == .calm ? 0.5 : self == .normal ? 1 : 1.7 }
}

enum LightMode: String, CaseIterable, Identifiable {
    case album = "Follow lyrics", warm = "Warm white", custom = "Custom"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    let monitor = NowPlayingMonitor()
    let audio = AudioReactor()

    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var lyrics: LyricsState = .idle
    @Published private(set) var artwork: NSImage?
    @Published private(set) var autoTone: Tone = .mixed
    @Published private(set) var palette: Palette = .fallback

    // Settings (persisted)
    @Published var lightingEnabled: Bool { didSet { save(lightingEnabled, "lightingEnabled"); NowPlayingMonitor.log("lightingEnabled=\(lightingEnabled)") } }
    @Published var lightMode: LightMode { didSet { save(lightMode.rawValue, "lightMode") } }
    @Published var customHue: Double { didSet { save(customHue, "customHue") } }
    @Published var intensity: Double { didSet { save(intensity, "intensity") } }
    @Published var thickness: Double { didSet { save(thickness, "thickness") } }
    @Published var pulseOnBeat: Bool { didSet { save(pulseOnBeat, "pulseOnBeat") } }
    @Published var viewMode: ViewMode { didSet { save(viewMode.rawValue, "viewMode") } }
    @Published var effects: Effects { didSet { save(effects.rawValue, "effects") } }
    @Published var showEmoji: Bool { didSet { save(showEmoji, "showEmoji") } }
    @Published var audioSync: Bool {
        didSet { save(audioSync, "audioSync"); audioSync ? audio.start() : audio.stop() }
    }
    @Published var preferRoman: Bool { didSet { save(preferRoman, "preferRoman"); if let t = track { trackChanged(t) } } }
    /// "Auto" follows the lyrics' sentiment; otherwise a fixed mood the listener picked.
    @Published var toneChoice: String { didSet { save(toneChoice, "toneChoice") } }
    var tone: Tone { Tone(rawValue: toneChoice) ?? autoTone }
    @Published var look: Look { didSet { if let d = try? JSONEncoder().encode(look) { UserDefaults.standard.set(d, forKey: "look") } } }
    @Published var alwaysOnTop: Bool { didSet { save(alwaysOnTop, "alwaysOnTop"); applyWindowLevel() } }
    @Published var fontScale: Double { didSet { save(fontScale, "fontScale") } }

    var lastLineChange = Date.distantPast
    private var bag = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    init() {
        let d = UserDefaults.standard
        lightingEnabled = d.object(forKey: "lightingEnabled") as? Bool ?? true
        lightMode = LightMode(rawValue: d.string(forKey: "lightMode") ?? "") ?? .album
        customHue = d.object(forKey: "customHue") as? Double ?? 0.08
        intensity = d.object(forKey: "intensity") as? Double ?? 0.8
        thickness = d.object(forKey: "thickness") as? Double ?? 0.3
        pulseOnBeat = d.object(forKey: "pulseOnBeat") as? Bool ?? true
        viewMode = ViewMode(rawValue: d.string(forKey: "viewMode") ?? "") ?? .constellation
        effects = Effects(rawValue: d.string(forKey: "effects") ?? "") ?? .normal
        showEmoji = d.object(forKey: "showEmoji") as? Bool ?? true
        audioSync = d.object(forKey: "audioSync") as? Bool ?? false
        preferRoman = d.object(forKey: "preferRoman") as? Bool ?? true
        toneChoice = d.string(forKey: "toneChoice") ?? "Auto"
        look = d.data(forKey: "look").flatMap { try? JSONDecoder().decode(Look.self, from: $0) } ?? Look()
        alwaysOnTop = d.object(forKey: "alwaysOnTop") as? Bool ?? false
        fontScale = d.object(forKey: "fontScale") as? Double ?? 1.0

        monitor.$isPlaying.removeDuplicates().sink { [weak self] in self?.isPlaying = $0 }.store(in: &bag)
        monitor.$track.removeDuplicates().sink { [weak self] in self?.trackChanged($0) }.store(in: &bag)
        Lexicon.warmUp()
        monitor.start()
        if audioSync || AudioReactor.simulated { audioSync = true; audio.start() }
    }

    private func save(_ v: Any, _ key: String) { UserDefaults.standard.set(v, forKey: key) }

    func applyWindowLevel() {
        for w in NSApp.windows where !(w is NSPanel) && w.canBecomeMain { w.level = alwaysOnTop ? .floating : .normal }
    }

    func apply(_ preset: Preset) {
        switch preset {
        case .full:
            look = Look(playerBar: look.playerBar); showEmoji = true; lightingEnabled = true; pulseOnBeat = true
        case .balanced:
            look = Look(emphasis: true, rings: false, burst: false, emojiExplosions: true, moodParticles: true, stars: true,
                        connections: true, sparks: false, entrance: false, cameraMotion: false, colorWash: true,
                        colorMode: .colorful, edgeStyle: .glow, playerBar: look.playerBar)
            showEmoji = true; lightingEnabled = true; pulseOnBeat = false
        case .minimal:   // words + nodes + connecting lines, nothing else
            look = Look(emphasis: false, rings: false, burst: false, emojiExplosions: false, moodParticles: false, stars: false,
                        connections: true, sparks: false, entrance: false, cameraMotion: false, colorWash: false,
                        colorMode: .album, edgeStyle: .line, playerBar: look.playerBar)
            showEmoji = false; lightingEnabled = false; pulseOnBeat = false
        }
    }

    func resetAll() {
        apply(.full)
        lightMode = .album; customHue = 0.08; intensity = 0.8; thickness = 0.3
        effects = .normal; fontScale = 1; toneChoice = "Auto"; preferRoman = true; viewMode = .constellation
        look = Look(); alwaysOnTop = false
    }

    private func trackChanged(_ t: Track?) {
        track = t
        loadTask?.cancel()
        artwork = nil
        guard let t else { lyrics = .idle; palette = .fallback; return }
        lyrics = .loading
        palette = ArtworkService.palette(seed: t.id)
        let roman = preferRoman
        loadTask = Task { [weak self] in
            async let l = LyricsService.fetch(for: t, preferRoman: roman)
            async let a = ArtworkService.fetch(for: t)
            let (lyr, art) = await (l, a)
            guard !Task.isCancelled, let self, self.track == t else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                self.lyrics = lyr
                switch lyr {
                case .synced(let l): self.autoTone = Sentiment.tone(of: l.map(\.text))
                case .plain(let l): self.autoTone = Sentiment.tone(of: l)
                default: self.autoTone = .mixed
                }
                NowPlayingMonitor.log("tone=\(self.autoTone.rawValue) title=\(t.title)")
                if let (img, pal) = art { self.artwork = img; self.palette = pal }
            }
        }
    }

    var lightColors: [Color] {
        switch lightMode {
        case .album: return palette.colors
        case .warm: return [Color(red: 1, green: 0.86, blue: 0.68), Color(red: 1, green: 0.95, blue: 0.86)]
        case .custom:
            return [Color(hue: customHue, saturation: 0.75, brightness: 1),
                    Color(hue: (customHue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 1)]
        }
    }
}
