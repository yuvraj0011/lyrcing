import Foundation
import NaturalLanguage

/// The song's overall feeling. It decides which ambient effects and emoji are appropriate:
/// a sad song never gets confetti or floating hearts.
enum Tone: String, CaseIterable, Identifiable {
    case sad = "Sad", mixed = "Mixed", happy = "Happy"
    var id: String { rawValue }

    /// Allowed decorative emoji for words with no literal match.
    var vibes: [String] {
        switch self {
        case .sad: return ["🥀", "💧", "🌙", "🌑", "🖤", "🥲"]
        case .mixed: return ["✨", "💫", "🌙", "⭐", "🌌", "🫧"]
        case .happy: return ["✨", "💫", "🌈", "🎉", "😄", "🔥", "🎶"]
        }
    }

    /// How big the explosions, drift and camera moves get.
    var energy: Double { self == .sad ? 0.55 : self == .mixed ? 0.85 : 1.15 }

    /// Hue range (0...1) the per-word colors may use, and their saturation / brightness.
    var hues: (start: Double, span: Double) {
        switch self {
        case .sad: return (0.52, 0.28)       // teal -> blue -> violet
        case .mixed: return (0.0, 1.0)
        case .happy: return (0.0, 1.0)
        }
    }
    var saturation: ClosedRange<Double> { self == .sad ? 0.35...0.6 : self == .mixed ? 0.5...0.85 : 0.65...0.95 }
    var brightness: Double { self == .sad ? 0.9 : 1 }

    private static let celebratory = Set("🎉🎊🪩🍻🥂💃🕺🥳😄😁😂🤪🎈".unicodeScalars)

    /// Literal emoji that would clash with the song's feeling (no confetti in a sad song).
    func allows(_ emoji: String) -> Bool {
        self != .sad || !emoji.unicodeScalars.contains { Tone.celebratory.contains($0) }
    }

    /// Ambient mood actually shown for a line, filtered so the scene never contradicts the song's feeling.
    func ambient(for line: Mood?, lineScore: Int) -> Mood {
        switch self {
        case .sad:
            return line == .sad ? .sad : line == .cold ? .cold : line == .water ? .water : .night
        case .mixed:
            // Unsure songs stay calm: hearts, fire and confetti only on lines that are clearly positive.
            guard let line else { return .night }
            if line == .love || line == .party || line == .fire { return lineScore > 0 ? line : .night }
            return line
        case .happy:
            guard let line else { return .night }
            return line == .sad ? .night : line
        }
    }
}

enum Sentiment {
    private static let negEnglish: Set<String> = [
        "sad", "cry", "cried", "crying", "tears", "tear", "pain", "hurt", "hurting", "broken", "break", "breaking", "lonely", "alone",
        "goodbye", "gone", "lost", "die", "dead", "death", "dying", "hate", "miss", "missing", "empty", "dark", "cold", "bleed", "blood",
        "ghost", "regret", "sorry", "lie", "lies", "liar", "leave", "leaving", "left", "never", "nobody", "nothing", "fade", "fading",
        "drown", "drowning", "cruel", "afraid", "fear", "scared", "heartbreak", "heartbroken", "torn", "wound", "ache", "grief", "sorrow",
        "sob", "weep", "numb", "apart", "farewell", "hollow", "scar", "shatter", "shattered", "bitter", "tired", "hopeless", "anymore",
        "cried", "suffer", "suffering", "misery", "tragic", "bury", "grave", "lonesome", "heavy", "ashes", "burning", "bruise", "damn",
    ]
    private static let posEnglish: Set<String> = [
        "happy", "smile", "smiling", "laugh", "laughing", "joy", "dance", "dancing", "party", "shine", "shining",
        "bright", "sun", "sunshine", "beautiful", "beauty", "free", "freedom", "alive", "wonderful", "fun", "celebrate", "together",
        "hope", "heaven", "paradise", "magic", "sweet", "golden", "glow", "lit", "vibe", "vibes", "good", "best", "win", "winner", "rich",
        "summer", "sexy", "yes", "party", "bounce", "jump", "shake", "gorgeous", "perfect", "lucky", "clap",
    ]
    // Romanized Hindi / Punjabi / Urdu
    private static let negRoman = [
        "dard", "gham", "ghum", "aansu", "ansu", "judai", "judaai", "bichhad", "bichhdna", "bichhde", "tanha", "tanhai", "akela", "akeli",
        "rona", "roye", "roya", "rote", "udaas", "udas", "bewafa", "bewafai", "dhokha", "toota", "tootna", "toote", "maut", "marna", "afsos",
        "tadap", "tadapna", "tadpa", "zakhm", "ruswa", "barbaad", "barbad", "rulaya", "rulana", "viraan", "veeran", "siskiyan", "bebas",
        "majboor", "majbur", "mayoos", "nafrat", "shikwa", "shikayat", "khoya", "bikhar", "ujad", "alvida", "alvidaa", "dukh", "dukhi",
        "birha", "vichhoda", "hanju", "hanjhu", "rondi", "ronda", "sitam", "sitamgar", "tabaah", "tabah", "intezaar", "yaadon",
        "bechain", "bekarar", "bekaraar", "tadpaya", "tadpati", "zakhmi", "dukhda", "viyog", "firaaq", "firaq", "hijr", "bhula", "bhoola", "bhulaya", "tanhaaiyan", "kho", "khoye", "pyaasa", "pyasa", "tarse", "tarasna", "tarsa", "bebasi", "laachaar", "ghamgeen", "gamgeen", "judaa", "juda", "alag", "door", "doori", "dooriyan", "faasle", "fasle", "faasla", "rulati", "rulata", "ro", "royi", "aahein", "aah", "ashk", "ashqon", "mazboor", "bewaja", "tootte", "bikhra", "bikhre", "sannata", "andhera", "andheri", "ghutan", "ghut", "chhod", "chhoda", "chhodke", "chhod", "jhooth", "jhoot", "dhoka", "gila", "gile", "sitamgar", "kasam", "pachhtaye", "pachtaya",
    ]
    private static let posRoman = [
        "khushi", "khush", "hasna", "hasi", "muskaan", "muskurana", "naach", "naacho", "nachna", "nache", "jashn", "jashan", "masti", "mastana",
        "mast", "party", "dhamaal", "dhamaka", "jeet", "mubarak", "badhai", "roshan", "roshni", "noor", "jannat", "khoobsurat", "haseen",
        "rangeen", "rangeela", "bahaar", "bahar", "sawera", "savera", "dhoom", "balle", "bhangra", "gidda", "giddha", "dhol", "daaru", "daru",
        "peg", "nasha", "dance", "swag", "gabru", "kudi", "munda", "jatt", "patola", "sohni", "sohna", "chamak", "jagmag", "diwali",
        "chaiyya", "thumka", "thumke", "dhamaal", "badtameez", "kamaal", "zabardast", "mauj", "mouj", "maza", "maje", "nashili", "jhoom", "jhoomo", "jhoomna", "gaao", "gao", "naacho", "ghoomo", "josh", "lehra", "lehrao", "uda", "udo", "udaan", "pyaara", "pyara", "mithi", "meethi", "mehfil", "raunak", "raunaq", "shaadi", "baraat", "tyohaar", "holi", "fatafat", "dil-e-nadan",
    ]
    // Native script, exact spellings
    private static let negNative: Set<String> = [
        "दर्द", "ग़म", "गम", "आँसू", "आंसू", "जुदाई", "बिछड़", "तन्हा", "तन्हाई", "अकेला", "अकेली", "रोना", "रोया", "रोये", "उदास", "बेवफा",
        "बेवफ़ा", "धोखा", "टूटा", "टूटे", "मौत", "मरना", "अफ़सोस", "तड़प", "तड़पना", "ज़ख्म", "बर्बाद", "रुलाया", "वीरान", "सिसकियाँ", "बेबस",
        "मजबूर", "नफ़रत", "शिकवा", "अलविदा", "ਦਰਦ", "ਗ਼ਮ", "ਹੰਝੂ", "ਜੁਦਾਈ", "ਇਕੱਲਾ", "ਦੁੱਖ", "ਵਿਛੋੜਾ", "ਬੇਵਫ਼ਾ", "ਰੋਣਾ", "غم", "درد", "آنسو", "جدائی", "تنہا", "تنہائی",
    ]
    private static let posNative: Set<String> = [
        "ख़ुशी", "खुशी", "मुस्कान", "हँसी", "नाच", "जश्न", "मस्ती", "रोशनी", "जन्नत", "बहार", "रंगीन", "धूम", "ਖ਼ੁਸ਼ੀ", "ਨੱਚ", "ਭੰਗੜਾ", "ਜਸ਼ਨ", "خوشی", "ہنسی", "رقص", "جشن",
    ]

    private static let negSkeleton: Set<String> = Set(negRoman.map(Lexicon.skeleton).filter { $0.count >= 3 })
    private static let posSkeleton: Set<String> = Set(posRoman.map(Lexicon.skeleton).filter { $0.count >= 3 })
    private static let negRomanSet = Set(negRoman), posRomanSet = Set(posRoman)

    /// +1 positive, -1 negative, 0 neutral.
    static func valence(_ raw: String) -> Int {
        let w = Lexicon.clean(raw)
        guard w.count > 1 else { return 0 }
        switch Lexicon.script(of: w) {
        case .latin:
            if negEnglish.contains(w) || negRomanSet.contains(w) { return -1 }
            if posEnglish.contains(w) || posRomanSet.contains(w) { return 1 }
            for suf in ["ing", "ed", "s", "es"] where w.hasSuffix(suf) {
                let stem = String(w.dropLast(suf.count))
                if negEnglish.contains(stem) { return -1 }
                if posEnglish.contains(stem) { return 1 }
            }
            return 0
        case .indic:
            if negNative.contains(w) { return -1 }
            if posNative.contains(w) { return 1 }
            let sk = Lexicon.skeleton(w)
            if sk.count >= 3 { if negSkeleton.contains(sk) { return -1 }; if posSkeleton.contains(sk) { return 1 } }
            return 0
        case .other: return 0
        }
    }

    static func lineScore(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).reduce(0) { $0 + valence(String($1)) }
    }

    /// Apple's on-device sentiment model (-1...1). Reliable for English only.
    private static func englishScore(_ line: String) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = line
        let (tag, _) = tagger.tag(at: line.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return tag.flatMap { Double($0.rawValue) }
    }

    /// Combines Apple's English sentiment (when the lyrics are English) with word lists for Hinglish /
    /// Punjabi / Urdu / native scripts. When unsure it returns `.mixed`, the calm, never-cheery default.
    static func tone(of lines: [String]) -> Tone {
        var pos = 0, neg = 0, nlSum = 0.0, nlCount = 0
        var chunk: [String] = []
        func flush() {   // 4-line stanzas give the model enough context; single lines are too noisy
            defer { chunk = [] }
            guard chunk.count >= 2, let sc = englishScore(chunk.joined(separator: "\n")) else { return }
            nlSum += sc; nlCount += 1
        }
        for l in lines {
            let words = l.split(whereSeparator: \.isWhitespace).map(String.init)
            for w in words { let v = valence(w); if v > 0 { pos += 1 } else if v < 0 { neg += 1 } }
            if !Lexicon.isHinglish(words), words.count >= 2, LyricsService.latinRatio(l) >= 0.9 { chunk.append(l) }
            if chunk.count == 4 { flush() }
        }
        flush()
        var parts: [Double] = []
        if nlCount >= 4 { parts.append(nlSum / Double(nlCount) * 1.6) }
        if pos + neg >= 4 { parts.append(Double(pos - neg) / Double(pos + neg + 4)) }
        guard !parts.isEmpty else { return .mixed }
        let v = parts.reduce(0, +) / Double(parts.count)
        if v <= -0.12 { return .sad }
        // Word-list-only evidence (Hinglish etc.) is never enough to call a song happy.
        if v >= 0.25, nlCount >= 4 || (pos >= 8 && v >= 0.4) { return .happy }
        return .mixed
    }
}
