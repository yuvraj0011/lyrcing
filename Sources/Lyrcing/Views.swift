import SwiftUI

/// View-local state. (`@State` needs the SwiftUI macro plugin that only ships with full Xcode.)
final class LocalState: ObservableObject {
    @Published var current = 0
    @Published var showSettings = false
    @Published var hover = false
}

// MARK: Background

struct AmbientBackground: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    Color(white: 0.04)
                    ForEach(0..<4, id: \.self) { i in
                        let f = Double(i)
                        Circle()
                            .fill(colors[i % colors.count])
                            .frame(width: geo.size.width * 0.75)
                            .offset(x: cos(t * 0.11 + f * 1.7) * geo.size.width * 0.3,
                                    y: sin(t * 0.09 + f * 2.3) * geo.size.height * 0.3)
                            .opacity(0.55)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .blur(radius: 110)
                .overlay(Color.black.opacity(0.35))
            }
        }
        .animation(.easeInOut(duration: 1.2), value: colors)
        .ignoresSafeArea()
    }
}

// MARK: Lyrics

struct LyricsView: View {
    @ObservedObject var model: AppModel
    @StateObject private var ui = LocalState()

    var body: some View {
        GeometryReader { geo in
            let size = max(26, min(66, geo.size.width * 0.052)) * model.fontScale
            switch model.lyrics {
            case .idle:
                message("music.note", "Play a song in Apple Music or Spotify")
            case .loading:
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .none:
                message("text.badge.xmark", "No lyrics found for this track")
            case .plain(let lines):
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: size * 0.4) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                            Text(l.isEmpty ? " " : l)
                                .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(.vertical, 60).padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .synced(let lines):
                synced(lines, size: size, height: geo.size.height)
            }
        }
    }

    private func message(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44, weight: .light))
            Text(text).font(.title3.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func synced(_ lines: [LyricLine], size: Double, height: Double) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: size * 0.45) {
                    Spacer().frame(height: height * 0.3)
                    ForEach(lines) { line in
                        let d = abs(line.id - ui.current)
                        let active = d == 0
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: size, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(active ? 1 : max(0.12, 0.5 - Double(d) * 0.1))
                            .blur(radius: active ? 0 : min(5, Double(d) * 1.4))
                            .scaleEffect(active ? 1 : 0.94, anchor: .leading)
                            .shadow(color: active ? .white.opacity(0.35) : .clear, radius: 18)
                            .contentShape(Rectangle())
                            .onTapGesture { model.monitor.seek(to: line.time) }
                            .id(line.id)
                    }
                    Spacer().frame(height: height * 0.6)
                }
                .padding(.horizontal, 8)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                         .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                let idx = Self.index(in: lines, at: model.monitor.position + 0.15)
                if idx != ui.current {
                    ui.current = idx
                    model.lastLineChange = Date()
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                        proxy.scrollTo(idx, anchor: UnitPoint(x: 0.5, y: 0.36))
                    }
                }
            }
            .onChange(of: lines) { ui.current = -1 }
        }
    }

    static func index(in lines: [LyricLine], at t: Double) -> Int {
        var lo = 0, hi = lines.count - 1, ans = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= t { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return ans
    }
}

// MARK: Main

struct ContentView: View {
    @ObservedObject var model: AppModel
    @StateObject private var ui = LocalState()

    var body: some View {
        Group {
            if model.viewMode == .classic { classic } else { constellation }
        }
        .frame(minWidth: 820, minHeight: 520)
        .preferredColorScheme(.dark)
    }

    // MARK: Constellation (default)

    private var constellation: some View {
        ZStack(alignment: .bottom) {
            Color(white: 0.012).ignoresSafeArea()
            if case .synced(let lines) = model.lyrics {
                ConstellationView(model: model, lines: lines)
            } else {
                LyricsView(model: model).padding(.horizontal, 80).padding(.vertical, 60)
            }
            VStack { Spacer(); playerBar.padding(.bottom, 18) }
                .frame(height: 150).frame(maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .onHover { ui.hover = $0 }
                .opacity(model.look.playerBar == .always || (model.look.playerBar == .auto && ui.hover) ? 1 : 0)
                .allowsHitTesting(model.look.playerBar != .hidden)
                .animation(.easeInOut(duration: 0.25), value: ui.hover)
        }
    }

    private var playerBar: some View {
        HStack(spacing: 16) {
            Group {
                if let art = model.artwork { Image(nsImage: art).resizable().scaledToFill() }
                else { Color.white.opacity(0.1) }
            }
            .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(model.track?.title ?? "Nothing playing").font(.headline).lineLimit(1)
                Text(model.track?.artist ?? "Open Apple Music or Spotify")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .frame(maxWidth: 200, alignment: .leading)
            HStack(spacing: 8) {
                control("backward.fill") { model.monitor.previous() }
                control(model.isPlaying ? "pause.fill" : "play.fill", big: true) { model.monitor.togglePlay() }
                control("forward.fill") { model.monitor.next() }
            }
            .disabled(model.track == nil)
            Divider().frame(height: 28)
            toolButtons
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1)))
    }

    private var toolButtons: some View {
        HStack(spacing: 14) {
            Button { model.viewMode = model.viewMode == .classic ? .constellation : .classic } label: {
                Image(systemName: model.viewMode == .classic ? "sparkles" : "text.alignleft")
            }
            Button { model.audioSync.toggle() } label: {
                Image(systemName: model.audioSync ? "waveform" : "waveform.slash")
            }
            .help("Sync effects to the music's beat (A)")
            Button { model.lightingEnabled.toggle() } label: {
                Image(systemName: model.lightingEnabled ? "light.max" : "light.min")
            }
            Button { ui.showSettings.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                .popover(isPresented: $ui.showSettings, arrowEdge: .top) { SettingsView(model: model) }
        }
        .buttonStyle(.plain).font(.system(size: 16)).foregroundStyle(.white.opacity(0.75))
    }

    // MARK: Classic

    private var classic: some View {
        ZStack {
            AmbientBackground(colors: model.palette.colors)
            HStack(alignment: .center, spacing: 56) {
                sidebar.frame(width: 300)
                LyricsView(model: model)
            }
            .padding(.horizontal, 56)
            .padding(.top, 36).padding(.bottom, 24)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Group {
                if let art = model.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.08))
                        .overlay(Image(systemName: "music.note").font(.system(size: 54, weight: .light))
                            .foregroundStyle(.white.opacity(0.4)))
                }
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: (model.palette.colors.first ?? .black).opacity(0.5), radius: 40, y: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.track?.title ?? "Nothing playing").font(.title2.weight(.bold)).lineLimit(2)
                Text(model.track?.artist ?? "Open Apple Music or Spotify")
                    .font(.headline).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }

            HStack(spacing: 28) {
                control("backward.fill") { model.monitor.previous() }
                control(model.isPlaying ? "pause.fill" : "play.fill", big: true) { model.monitor.togglePlay() }
                control("forward.fill") { model.monitor.next() }
            }
            .disabled(model.track == nil)
            .frame(maxWidth: .infinity)

            Spacer()
            toolButtons
        }
    }

    private func control(_ icon: String, big: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: big ? 26 : 18)).frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            look.tabItem { Label("Look", systemImage: "sparkles") }
            edge.tabItem { Label("Edge Light", systemImage: "light.max") }
            lyrics.tabItem { Label("Lyrics", systemImage: "text.quote") }
            sound.tabItem { Label("Window & Sound", systemImage: "macwindow") }
        }
        .frame(width: 460, height: 460)
    }

    private func flag(_ title: String, _ help: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Text(title); Text(help).font(.caption).foregroundStyle(.secondary) }
    }

    private var look: some View {
        Form {
            Section("Preset") {
                Picker("Preset", selection: Binding(get: { Optional<Preset>.none }, set: { if let p = $0 { model.apply(p) } })) {
                    Text("Choose…").tag(Optional<Preset>.none)
                    ForEach(Preset.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                Text("Minimal shows only words, nodes and connecting lines.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Words") {
                flag("Pump the current word", "Grows and glows while it's sung", $model.look.emphasis)
                flag("Rings & beat ripples", "Circles around the current word", $model.look.rings)
                flag("Entrance animations", "Slam, spin and zoom-in per word", $model.look.entrance)
                Picker("Word colors", selection: $model.look.colorMode) { ForEach(ColorMode.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Effects strength", selection: $model.effects) { ForEach(Effects.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            }
            Section("Scene") {
                flag("Connection lines", "Lines joining the words", $model.look.connections)
                flag("Light sparks on lines", "Little lights travelling along them", $model.look.sparks)
                flag("Sparkle burst", "Burst and shockwave as each word lands", $model.look.burst)
                flag("Color glow", "Soft glow of the word's color behind it", $model.look.colorWash)
                flag("Twinkling stars", "Background stars", $model.look.stars)
                flag("Ambient particles", "Rain, embers, snow, hearts (never in sad songs)", $model.look.moodParticles)
                flag("Camera motion", "Slow drift and beat zoom", $model.look.cameraMotion)
            }
            Section("Emoji") {
                flag("Emoji for lyric words", "Show an emoji for matching words", $model.showEmoji)
                flag("Emoji explosions", "Emoji thrown out when an emoji word is sung", $model.look.emojiExplosions)
            }
        }.formStyle(.grouped)
    }

    private var edge: some View {
        Form {
            Section("Edge light") {
                Toggle("Show edge light", isOn: $model.lightingEnabled)
                Picker("Style", selection: $model.look.edgeStyle) { ForEach(EdgeStyle.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Color", selection: $model.lightMode) { ForEach(LightMode.allCases) { Text($0.rawValue).tag($0) } }
                if model.lightMode == .custom { Slider(value: $model.customHue, in: 0...1) { Text("Hue") } }
                Slider(value: $model.intensity, in: 0.2...1) { Text("Brightness") }
                Slider(value: $model.thickness, in: 0...1) { Text("Thickness") }
                flag("Pulse on each lyric line", "Edge flashes as lines change", $model.pulseOnBeat)
            }.disabled(false)
        }.formStyle(.grouped)
    }

    private var lyrics: some View {
        Form {
            Section("Style") {
                Picker("Lyric style", selection: $model.viewMode) { ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) } }
                Slider(value: $model.fontScale, in: 0.6...1.5) { Text("Text size") }
            }
            Section("Language") {
                flag("Prefer English / roman lyrics", "Hindi & Punjabi in English letters when available", $model.preferRoman)
            }
            Section("Mood") {
                Picker("Mood", selection: $model.toneChoice) {
                    Text("Auto").tag("Auto")
                    ForEach(Tone.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.pickerStyle(.segmented)
                Text(model.toneChoice == "Auto" ? "Detected from the lyrics: \(model.autoTone.rawValue.lowercased())" : "Fixed by you")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var sound: some View {
        Form {
            Section("Beat sync") {
                flag("Sync effects to the beat", "Listens to your Mac's audio output (needs Screen Recording permission)", $model.audioSync)
                AudioStatus(audio: model.audio)
            }
            Section("Window") {
                Picker("Player bar", selection: $model.look.playerBar) { ForEach(PlayerBarMode.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Keep window on top", isOn: $model.alwaysOnTop)
            }
            Section { Button("Reset everything to defaults", role: .destructive) { model.resetAll() } }
        }.formStyle(.grouped)
    }
}

struct AudioStatus: View {
    @ObservedObject var audio: AudioReactor
    var body: some View {
        Text(audio.status == "Off" ? "Beat sync needs the Screen Recording permission. Only audio is used." : audio.status)
            .font(.caption).foregroundStyle(.secondary)
    }
}
