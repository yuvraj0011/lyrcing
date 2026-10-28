import AppKit
import SwiftUI

struct SplitMix {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Pure helpers: word timing, per-word colors, scattered layout. Everything is a function of
/// (lyrics, playback time), so rendering is stateless and survives seeking.
enum Constellation {
    struct Word { let text: String; let start: Double; let end: Double }
    struct LineTiming { let start: Double; let end: Double; let words: [Word]; let hinglish: Bool; let mood: Mood?; let score: Int }
    struct Layout { var points: [CGPoint]; var sizes: [Double]; var links: [[Int]] }

    private static var timingCache: [String: LineTiming?] = [:]

    static func timing(_ lines: [LyricLine], _ idx: Int) -> LineTiming? {
        guard lines.indices.contains(idx) else { return nil }
        let key = "\(lines.count)|\(idx)|\(lines[idx].time)|\(lines[idx].text)"
        if let hit = timingCache[key] { return hit }
        if timingCache.count > 400 { timingCache.removeAll() }
        let t = computeTiming(lines, idx)
        timingCache[key] = t
        return t
    }

    private static func computeTiming(_ lines: [LyricLine], _ idx: Int) -> LineTiming? {
        let ws = lines[idx].text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !ws.isEmpty, lines[idx].text != "♪" else { return nil }
        let start = lines[idx].time
        let next = idx + 1 < lines.count ? lines[idx + 1].time : start + 5
        let end = min(next, start + Double(ws.count) * 1.4 + 3)   // slow songs: words stretch across the whole line instead of racing ahead
        let span = (end - start) * 0.88
        let weights = ws.map { Lexicon.syllables($0) + (",.?!;:".contains($0.last ?? " ") ? 1.2 : 0) }
        let total = weights.reduce(0, +)
        var acc = 0.0
        var words: [Word] = []
        for (i, w) in ws.enumerated() {
            let s = start + span * acc / total
            acc += weights[i]
            let e = i == ws.count - 1 ? end : start + span * acc / total
            words.append(Word(text: w, start: s, end: e))
        }
        let hl = Lexicon.isHinglish(ws)
        let mood = Mood.dominant(of: ws.compactMap { Lexicon.emoji(for: $0, hinglish: hl) })
        return LineTiming(start: start, end: end, words: words, hinglish: hl, mood: mood, score: Sentiment.lineScore(lines[idx].text))
    }

    /// Each emphasised word gets a new hue, walking around the wheel from the album's colors.
    static func color(_ p: Palette, tone: Tone, mode: ColorMode = .colorful, line: Int, word: Int) -> Color {
        if mode == .white { return Color(white: 0.96) }
        let line = mode == .album ? 0 : line, word = mode == .album ? 0 : word
        var r = SplitMix(s: UInt64(truncatingIfNeeded: line &* 7919 &+ word &* 104729 &+ 17))
        let base = NSColor(p.colors[(line + word) % p.colors.count]).usingColorSpace(.deviceRGB) ?? .white
        var h: CGFloat = 0
        base.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
        var hue = (Double(h) + Double(word) * 0.17 + r.unit() * 0.08).truncatingRemainder(dividingBy: 1)
        if tone == .sad { hue = (tone.hues.start + hue * tone.hues.span).truncatingRemainder(dividingBy: 1) }   // cool, soft colors only
        let sat = tone.saturation
        return Color(hue: hue, saturation: sat.lowerBound + r.unit() * (sat.upperBound - sat.lowerBound), brightness: tone.brightness)
    }

    /// Best-candidate sampling: spreads words over the screen without clumping.
    static func layout(count: Int, seed: UInt64) -> Layout {
        var rng = SplitMix(s: seed)
        var pts: [CGPoint] = []
        for _ in 0..<count {
            var best = CGPoint(x: 0.5, y: 0.5), bestD = -1.0
            for _ in 0..<30 {
                let c = CGPoint(x: 0.12 + 0.76 * rng.unit(), y: 0.2 + 0.6 * rng.unit())
                let d = pts.map { hypot(($0.x - c.x) * 1.6, $0.y - c.y) }.min() ?? 1
                if d > bestD { bestD = d; best = c }
            }
            pts.append(best)
        }
        let sizes = (0..<count).map { _ in rng.unit() }
        var links = [[Int]](repeating: [], count: count)
        for i in 1..<max(1, count) {
            links[i].append(i - 1)
            if i >= 2, rng.unit() < 0.4 { links[i].append(Int(rng.next() % UInt64(i - 1))) }
        }
        return Layout(points: pts, sizes: sizes, links: links)
    }

    /// Current emphasis color (blended from the previous word's) — drives the screen-edge light.
    @MainActor static func emphasisColor(model: AppModel, at t: Double) -> Color? {
        guard case .synced(let lines) = model.lyrics else { return nil }
        let idx = LyricsView.index(in: lines, at: t)
        guard let tm = timing(lines, idx), t >= tm.start else { return nil }
        let i = tm.words.lastIndex { $0.start <= t } ?? 0
        let cur = color(model.palette, tone: model.tone, mode: model.look.colorMode, line: idx, word: i)
        let prev = i > 0 ? color(model.palette, tone: model.tone, mode: model.look.colorMode, line: idx, word: i - 1) : cur
        let f = min(1, (t - tm.words[i].start) / 0.4)
        let a = NSColor(prev).usingColorSpace(.deviceRGB) ?? .white
        let b = NSColor(cur).usingColorSpace(.deviceRGB) ?? .white
        return Color(nsColor: a.blended(withFraction: CGFloat(f), of: b) ?? b)
    }
}

final class LayoutCache {
    struct Dust { let x, y, phase, speed, twinkle, radius, bright: Double }
    var store: [Int: Constellation.Layout] = [:]
    private(set) var songMood: Mood = .night
    private var prepared = false

    /// The song's overall feeling, from the emoji across all its lyrics; it colours lines that have no direct emoji.
    func prepare(_ lines: [LyricLine]) {
        guard !prepared else { return }
        prepared = true
        var all: [String] = []
        for l in lines {
            let ws = l.text.split(whereSeparator: \.isWhitespace).map(String.init)
            let hl = Lexicon.isHinglish(ws)
            all += ws.compactMap { Lexicon.emoji(for: $0, hinglish: hl) }
        }
        songMood = Mood.dominant(of: all) ?? .night
    }
    func reset() { store = [:]; prepared = false }
    let dust: [Dust] = {
        var r = SplitMix(s: 42)
        return (0..<80).map { _ in
            Dust(x: r.unit(), y: r.unit(), phase: r.unit() * 6.28, speed: 0.2 + r.unit() * 0.8,
                 twinkle: 0.6 + r.unit() * 1.8, radius: 0.5 + r.unit() * 1.3, bright: 0.3 + r.unit() * 0.7)
        }
    }()

    func layout(line: Int, count: Int, seed: UInt64) -> Constellation.Layout {
        if let l = store[line], l.points.count == count { return l }
        let l = Constellation.layout(count: count, seed: UInt64(truncatingIfNeeded: line) &* 0x9E3779B97F4A7C15 ^ seed)
        store[line] = l
        return l
    }
}

struct ConstellationView: View {
    @ObservedObject var model: AppModel
    let lines: [LyricLine]
    private let cache = LayoutCache()

    private var seed: UInt64 {
        var h: UInt64 = 5381
        for b in (model.track?.id ?? "").utf8 { h = h &* 33 &+ UInt64(b) }
        return h
    }

    var body: some View {
        // Redraws stop while paused, so an idle window costs ~0 CPU.
        TimelineView(.animation(minimumInterval: nil, paused: !model.isPlaying)) { tl in
            Canvas { ctx, size in
                let clock = tl.date.timeIntervalSinceReferenceDate
                let t = model.monitor.position + 0.1
                cache.prepare(lines)
                let look = model.look
                if look.stars { drawDust(ctx, size, clock, tone: model.tone) }
                let idx = LyricsView.index(in: lines, at: t)
                guard let tm = Constellation.timing(lines, idx) else { return }
                let beat = model.audioSync ? model.audio.pulse(at: AudioReactor.now) : 0
                let tone = model.tone
                let fx = model.effects.factor * tone.energy
                if look.moodParticles, t >= tm.start {
                    let mood = tone.ambient(for: tm.mood ?? cache.songMood, lineScore: tm.score)
                    let fade = min(1, (t - tm.start) / 0.6) * (1 - min(1, max(0, (t - tm.end) / 0.5)))
                    drawMood(ctx, size, mood, clock: clock, alpha: fade, fx: fx)
                }
                var cam = ctx   // slow camera drift + a little zoom punch on every beat
                let motion = look.cameraMotion ? 1.0 : 0.0
                cam.translateBy(x: size.width / 2 + sin(clock * 0.21) * 10 * fx * motion, y: size.height / 2 + cos(clock * 0.17) * 7 * fx * motion)
                let zoom = 1 + 0.014 * beat * fx * motion
                cam.scaleBy(x: zoom, y: zoom)
                cam.translateBy(x: -size.width / 2, y: -size.height / 2)
                if idx > 0, let prev = Constellation.timing(lines, idx - 1), tm.start - prev.end < 0.3 {
                    let fade = 1 - (t - tm.start) / 0.6
                    if fade > 0 { drawLine(cam, size, idx - 1, prev, t: prev.end, clock: clock, alpha: fade, beat: beat, fx: fx) }
                }
                let alpha = 1 - min(1, max(0, (t - tm.end) / 0.5))
                if alpha > 0, t >= tm.start { drawLine(cam, size, idx, tm, t: t, clock: clock, alpha: alpha, beat: beat, fx: fx) }
            }
        }
        .onChange(of: lines) { cache.reset() }
    }

    // MARK: Helpers

    private func ease(_ x: Double) -> Double { let c = min(1, max(0, x)); return 1 - pow(1 - c, 3) }
    private func easeOutBack(_ x: Double) -> Double {
        let c = min(1, max(0, x)), c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(c - 1, 3) + c1 * pow(c - 1, 2)
    }

    private func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        let k = r * 0.22
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func drawDust(_ ctx: GraphicsContext, _ size: CGSize, _ clock: Double, tone: Tone) {
        let dim = tone == .sad ? 0.6 : tone == .happy ? 1.2 : 1.0
        for d in cache.dust {
            let x = ((d.x + clock * d.speed * 0.003).truncatingRemainder(dividingBy: 1)) * size.width
            let y = d.y * size.height + sin(clock * 0.3 + d.phase) * 6
            let tw = 0.5 + 0.5 * sin(clock * d.twinkle + d.phase)
            ctx.fill(circle(CGPoint(x: x, y: y), d.radius), with: .color(.white.opacity((0.06 + 0.32 * tw * d.bright) * dim)))
        }
    }

    // MARK: Mood

    /// Ambient particles that express the line's feeling: hearts rise, rain falls, embers glow...
    private func drawMood(_ ctx: GraphicsContext, _ size: CGSize, _ mood: Mood, clock: Double, alpha: Double, fx: Double) {
        guard alpha > 0.01 else { return }
        let scale = min(1.8, max(0.7, min(size.width / 900, size.height / 560)))
        let count = Int(22 * fx)
        var rng = SplitMix(s: 7)
        let heart = ctx.resolve(Text("❤️").font(.system(size: 28)))
        let heart2 = ctx.resolve(Text("💗").font(.system(size: 28)))
        let spark = ctx.resolve(Text("✨").font(.system(size: 28)))
        for k in 0..<count {
            let x0 = rng.unit(), sp = 0.05 + 0.09 * rng.unit(), ph = rng.unit(), sz = rng.unit()
            let prog = (clock * sp + ph).truncatingRemainder(dividingBy: 1)
            let fade = sin(prog * .pi)
            let sway = sin(clock * 0.8 + ph * 6.28) * 22 * scale
            var m = ctx
            switch mood {
            case .love:
                m.opacity = alpha * fade * 0.55
                m.translateBy(x: x0 * size.width + sway, y: size.height * (1.05 - prog * 1.15))
                let sc = (10 + 16 * sz) * scale / 28
                m.scaleBy(x: sc, y: sc)
                m.rotate(by: .radians(sin(clock + ph * 6) * 0.3))
                m.draw(k % 3 == 0 ? heart2 : heart, at: .zero, anchor: .center)
            case .sad:
                let y = size.height * ((prog * 3).truncatingRemainder(dividingBy: 1) * 1.1 - 0.05)
                var p = Path(); p.move(to: CGPoint(x: x0 * size.width, y: y)); p.addLine(to: CGPoint(x: x0 * size.width - 3 * scale, y: y + (10 + 14 * sz) * scale))
                m.opacity = alpha * 0.4
                m.stroke(p, with: .color(Color(hue: 0.58, saturation: 0.5, brightness: 1)), lineWidth: 1.2)
            case .fire:
                m.opacity = alpha * (1 - prog) * 0.8
                let pos = CGPoint(x: x0 * size.width + sway * 1.5, y: size.height * (1.02 - prog * 1.1))
                m.fill(circle(pos, (1.2 + 2.6 * sz) * scale * (1 - prog * 0.6)), with: .color(Color(hue: 0.05 + 0.06 * sz, saturation: 0.9, brightness: 1)))
            case .party:
                let y = size.height * ((prog * 1.6).truncatingRemainder(dividingBy: 1) * 1.1 - 0.05)
                m.opacity = alpha * 0.8
                m.translateBy(x: x0 * size.width + sway, y: y)
                m.rotate(by: .radians(clock * (2 + 3 * sz) + ph * 6))
                m.fill(Path(CGRect(x: -4 * scale, y: -2 * scale, width: 8 * scale, height: 4 * scale)),
                       with: .color(Color(hue: Double(k) / Double(count), saturation: 0.8, brightness: 1)))
            case .night:
                let tw = 0.5 + 0.5 * sin(clock * (0.8 + 1.6 * sz) + ph * 6.28)
                m.opacity = alpha * tw * 0.8
                let pos = CGPoint(x: x0 * size.width, y: ((ph * 7.3).truncatingRemainder(dividingBy: 1)) * size.height)
                m.fill(star(pos, (2 + 5 * sz) * scale), with: .color(.white))
                if k % 7 == 0 { m.translateBy(x: pos.x, y: pos.y); m.scaleBy(x: 0.5, y: 0.5); m.draw(spark, at: .zero, anchor: .center) }
            case .cold:
                m.opacity = alpha * 0.7
                let y = size.height * ((prog * 1.5).truncatingRemainder(dividingBy: 1) * 1.1 - 0.05)
                m.fill(circle(CGPoint(x: x0 * size.width + sway, y: y), (1.5 + 2.5 * sz) * scale), with: .color(.white))
            case .water:
                m.opacity = alpha * fade * 0.6
                m.stroke(circle(CGPoint(x: x0 * size.width + sway, y: size.height * (1.05 - prog * 1.15)), (3 + 8 * sz) * scale),
                         with: .color(Color(hue: 0.55, saturation: 0.4, brightness: 1)), lineWidth: 1)
            }
        }
    }

    // MARK: Line

    private func drawLine(_ ctx: GraphicsContext, _ size: CGSize, _ idx: Int, _ tm: Constellation.LineTiming,
                          t: Double, clock: Double, alpha: Double, beat: Double, fx: Double) {
        let n = tm.words.count
        let lay = cache.layout(line: idx, count: n, seed: seed)
        let look = model.look
        let scale = min(1.8, max(0.7, min(size.width / 900, size.height / 560))) * model.fontScale
        let pt = { (i: Int) -> CGPoint in
            CGPoint(x: size.width * lay.points[i].x + sin(clock * 0.9 + Double(i) * 1.7) * 4 * scale,
                    y: size.height * lay.points[i].y + cos(clock * 0.7 + Double(i) * 2.3) * 4 * scale)
        }
        let col = { (i: Int) in Constellation.color(model.palette, tone: model.tone, mode: look.colorMode, line: idx, word: i) }

        // Soft color wash behind the active word
        if look.colorWash, let ai = tm.words.firstIndex(where: { t >= $0.start && t < $0.end }) {
            let k = ease((t - tm.words[ai].start) / 0.5) * alpha
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [col(ai).opacity(0.24 * k + 0.2 * beat * alpha), col(ai).opacity(0)]),
                                           center: pt(ai), startRadius: 0, endRadius: 380 * scale))
        }

        // Connections with travelling sparks
        for (i, w) in tm.words.enumerated() where look.connections && t >= w.start {
            let grow = ease((t - w.start) / 0.45)
            for j in lay.links[i] {
                let a = pt(j), b = pt(i)
                var p = Path()
                p.move(to: a)
                p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * grow, y: a.y + (b.y - a.y) * grow))
                ctx.stroke(p, with: .color(col(i).opacity(0.35 * alpha)), lineWidth: 1)
                if grow >= 1, look.sparks {
                    let ph = (clock * 0.45 + Double(i) * 0.37 + Double(j) * 0.11).truncatingRemainder(dividingBy: 1)
                    ctx.fill(circle(CGPoint(x: a.x + (b.x - a.x) * ph, y: a.y + (b.y - a.y) * ph), 2 * scale),
                             with: .color(col(i).opacity(0.8 * alpha)))
                }
            }
        }

        // Nodes
        for (i, w) in tm.words.enumerated() where t >= w.start {
            let age = t - w.start
            let active = t < w.end
            let emph = active ? 1 : max(0, 1 - (t - w.end) / 0.5)
            let ev = ease(emph)                      // always-on brightness emphasis
            let e = look.emphasis ? ev : 0           // size + glow only when "pump" is on
            let appear = easeOutBack(age / 0.4)
            let c = col(i)
            let p = pt(i)
            let a = alpha * min(1, age / 0.2)
            let fs = ((13 + lay.sizes[i] * 10) * (1 - e) + 54 * e) * scale * max(0.01, appear)
            var emoji = model.showEmoji ? Lexicon.emoji(for: w.text, hinglish: tm.hinglish).flatMap { model.tone.allows($0) ? $0 : nil } : nil
            if model.showEmoji, emoji == nil, w.text.count > 2, abs(idx &* 5 &+ i &* 11) % 3 == 0 {
                let vibes = model.tone.vibes
                emoji = vibes[abs(idx &+ i) % vibes.count]   // vibe emoji for words with no literal match
            }
            let starR = (4 + 6 * e) * scale * appear * (1 + 0.2 * beat * e)
            let emojiSize = ((20 + lay.sizes[i] * 8) * (1 - e) + 68 * e) * scale * max(0.01, appear) * (1 + 0.16 * beat * e)

            var g = ctx
            g.opacity = a
            if e > 0.2 { g.addFilter(.shadow(color: c.opacity(0.9), radius: 16 * e)) }

            // Burst + shockwave on entry
            if look.burst, age < 0.9 {
                let u = age / 0.9, eu = ease(u)
                var burst = ctx
                burst.opacity = alpha
                let bursts = max(4, Int(10 * fx))
                for k in 0..<bursts {
                    let ang = Double(k) / Double(bursts) * 2 * .pi + Double(i)
                    let dist = eu * (55 + 45 * lay.sizes[(i + k) % n]) * scale * (0.8 + 0.3 * fx)
                    let pos = CGPoint(x: p.x + cos(ang) * dist, y: p.y + sin(ang) * dist)
                    burst.fill(k % 2 == 0 ? star(pos, 5 * (1 - u) * scale + 0.5) : circle(pos, 2 * (1 - u) * scale + 0.3),
                               with: .color(c.opacity(1 - u)))
                }
                burst.stroke(circle(p, eu * 120 * scale), with: .color(c.opacity(0.55 * (1 - u))), lineWidth: 0.5 + 2 * (1 - u))
            }

            var labelGap = starR + (4 + 10 * e) * scale
            if let emoji {
                let wobble = active ? sin(age * 9) * 0.2 * exp(-age * 1.6) + sin(age * 3) * 0.05 : sin(clock * 1.3 + Double(i)) * 0.07
                var eg = g
                eg.translateBy(x: p.x, y: p.y)
                eg.rotate(by: .radians(wobble))
                eg.draw(g.resolve(Text(emoji).font(.system(size: max(1, emojiSize)))), at: .zero, anchor: .center)
                labelGap = emojiSize * 0.62 + 4 * scale
                // Emoji explosion: a fan of copies thrown up and out, falling back with gravity
                if look.emojiExplosions, age < 1.8 {
                    let u = age / 1.8
                    var rs = SplitMix(s: UInt64(truncatingIfNeeded: idx &* 31 &+ i &* 977 &+ 5))
                    let base = 30 * scale
                    let glyph = ctx.resolve(Text(emoji).font(.system(size: base)))
                    for _ in 0..<max(4, Int(12 * fx)) {
                        let ang = -Double.pi / 2 + (rs.unit() - 0.5) * 2.4
                        let speed = (180 + rs.unit() * 260) * scale * (0.7 + 0.3 * fx)
                        let spin = (rs.unit() - 0.5) * 8
                        let sz = (14 + rs.unit() * 20) * scale * (1 - 0.4 * u)
                        var m = ctx
                        m.opacity = alpha * (1 - u) * (1 - u * 0.3)
                        m.translateBy(x: p.x + cos(ang) * speed * age, y: p.y + sin(ang) * speed * age + 0.5 * 520 * scale * age * age)
                        m.rotate(by: .radians(spin * age))
                        m.scaleBy(x: sz / base, y: sz / base)
                        m.draw(glyph, at: .zero, anchor: .center)
                    }
                }
            } else {
                let tw = 1 + 0.15 * sin(clock * 2 + Double(i))   // idle twinkle
                g.fill(star(p, starR * tw), with: .color(c))
            }

            if active, look.rings, beat > 0.05 {   // expanding ring on each beat
                g.stroke(circle(p, (1 - beat) * 170 * scale + 20 * scale), with: .color(c.opacity(0.55 * beat)), lineWidth: 1 + 2 * beat)
            }
            if active, look.rings {
                let pulse = 1 + 0.12 * sin(age * 7)
                let ringR = (emoji == nil ? starR * 2.2 : emojiSize * 0.7) * pulse
                g.stroke(circle(p, ringR), with: .color(c.opacity(0.8)), lineWidth: 1.2)
            }

            let text = Text(w.text).font(.system(size: max(1, fs), weight: e > 0.5 ? .heavy : .semibold)).foregroundColor(c)
            let resolved = g.resolve(text)
            let ts = resolved.measure(in: CGSize(width: 4000, height: 400))
            let x = min(max(p.x, ts.width / 2 + 16), size.width - ts.width / 2 - 16)
            g.opacity = a * (0.72 + 0.28 * ev)
            // Entrance style varies per word: pop, slam from above, spin in, zoom out of the dark
            let style = look.entrance ? abs(idx &* 7 &+ i &* 13) % 4 : 0
            let u = min(1, age / 0.45)
            var dy = 0.0, rot = 0.0, zoom = 1.0
            if age < 0.45 {
                switch style {
                case 1: dy = -150 * scale * (1 - easeOutBack(u))
                case 2: rot = -0.9 * (1 - ease(u))
                case 3: zoom = 1 + 1.4 * (1 - ease(u))
                default: break
                }
            }
            g.translateBy(x: x, y: p.y - labelGap + dy)
            g.rotate(by: .radians(rot))
            g.scaleBy(x: zoom, y: zoom)
            g.draw(resolved, at: .zero, anchor: .bottom)
        }
    }
}
