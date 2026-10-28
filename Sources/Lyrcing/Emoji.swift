import Foundation

/// Maps lyric words to emoji. Handles simple suffixes (loving, tears, kissed) and a few Hindi/Punjabi words.
enum Emoji {
    private static let table: [String: String] = {
        let groups: [(String, [String])] = [
            ("❤️", ["love", "lover", "loving", "heart", "pyaar", "pyar", "ishq", "mohabbat"]),
            ("💗", ["dil", "darling", "crush"]), ("💔", ["broken", "break", "breakup", "heartbreak", "hurt", "pain"]),
            ("🔥", ["fire", "burn", "burning", "flame", "hot", "heat", "lit"]),
            ("🌙", ["moon", "night", "midnight", "raat", "chand", "tonight"]), ("⭐", ["star", "stars", "tara", "tare"]),
            ("☀️", ["sun", "sunshine", "morning", "day", "summer"]), ("✨", ["shine", "shining", "sparkle", "glow", "magic", "light", "lights"]),
            ("👀", ["eye", "eyes", "look", "looking", "see", "watch", "stare"]), ("😭", ["cry", "crying", "tear", "tears", "sad", "weep"]),
            ("😊", ["smile", "smiling", "happy", "joy"]), ("😘", ["kiss", "kissing", "lips", "mwah"]),
            ("💃", ["dance", "dancing", "dancer", "groove"]), ("🕺", ["bhangra", "move", "moves"]),
            ("🎵", ["music", "song", "songs", "melody", "tune"]), ("🎤", ["sing", "singing", "voice", "mic"]),
            ("🥁", ["beat", "beats", "drum", "bass"]), ("👶", ["baby", "babe", "bae"]), ("👑", ["king", "queen", "crown", "royal"]),
            ("💰", ["money", "cash", "rich", "paid", "bank", "dollar", "dollars"]), ("💎", ["diamond", "diamonds", "gold", "golden", "jewel"]),
            ("💍", ["ring", "wedding", "marry"]), ("🌧️", ["rain", "raining", "storm", "pour"]), ("⚡", ["thunder", "lightning", "electric", "shock"]),
            ("❄️", ["snow", "cold", "ice", "freeze", "winter", "frozen"]), ("🕊️", ["fly", "flying", "wings", "bird", "soar", "free", "freedom"]),
            ("😇", ["heaven", "angel", "pray", "praying", "holy", "god"]), ("😈", ["devil", "demon", "sin", "wicked", "bad"]),
            ("💬", ["baatein", "baat", "talk", "talking", "words", "say", "said", "whisper"]),
            ("👁️", ["nazar", "nazrein", "nigahen", "aankhen", "aankhon", "akhiyan"]), ("💭", ["yaadein", "yaad", "khwab", "sapna", "sapne"]),
            ("🌟", ["zindagi", "life", "tu", "tera", "mera"]), ("👻", ["ghost", "haunt", "haunted"]), ("💀", ["dead", "die", "dying", "death", "skull", "kill"]),
            ("💭", ["dream", "dreams", "dreaming", "think", "thought", "imagine"]), ("😴", ["sleep", "sleeping", "tired", "bed"]),
            ("🏃", ["run", "running", "chase", "race"]), ("🚗", ["car", "drive", "driving", "ride", "road", "highway"]),
            ("🏠", ["home", "house", "ghar"]), ("🌍", ["world", "earth", "duniya"]), ("🌌", ["sky", "universe", "space", "galaxy", "heavens"]),
            ("🌊", ["ocean", "sea", "wave", "waves", "water", "drown", "drowning"]), ("🏖️", ["beach", "sand", "island"]),
            ("🍷", ["wine", "champagne", "cheers"]), ("🍻", ["drink", "drinks", "drinking", "drunk", "beer", "party", "bottle"]),
            ("📱", ["phone", "call", "calling", "text", "message", "dial"]), ("⏰", ["time", "clock", "wait", "waiting", "late"]),
            ("♾️", ["forever", "infinity", "always", "endless"]), ("💨", ["gone", "leave", "leaving", "away", "vanish"]),
            ("🥀", ["lost", "alone", "lonely", "empty", "fade", "fading"]), ("🩸", ["blood", "bleed", "bleeding"]),
            ("🤝", ["hand", "hands", "hold", "holding", "yaar", "friend", "friends"]), ("🫂", ["tight", "hug", "embrace", "close"]),
            ("🧠", ["mind", "brain", "know", "knew", "remember"]), ("🤪", ["crazy", "mad", "wild", "insane", "pagal"]),
            ("🥊", ["fight", "fighting", "war", "battle"]), ("🔫", ["gun", "shoot", "bullet"]), ("💣", ["bomb", "explode", "boom"]),
            ("🌹", ["rose", "roses", "flower", "flowers"]), ("🌳", ["tree", "trees", "forest"]), ("🍂", ["fall", "falling", "fell", "autumn", "leaves"]),
            ("💊", ["overdose", "overdosed", "pill", "pills", "drug", "drugs", "high"]), ("❌", ["wrong", "no", "never", "stop", "don't", "dont"]),
            ("✅", ["right", "yes", "true", "truth"]), ("📸", ["photo", "photos", "picture", "camera", "snap"]),
            ("🛍️", ["buy", "purchase", "shop", "shopping", "sale"]), ("🎬", ["movie", "film", "scene", "cinema", "show"]),
            ("🪩", ["disco", "club", "dj", "floor"]), ("🎸", ["guitar", "rock", "band"]), ("🌈", ["rainbow", "colors", "color", "colour"]),
            ("🧊", ["chill", "cool", "calm"]), ("🦋", ["butterfly", "butterflies", "free"]), ("🔑", ["key", "keys", "lock", "locked"]),
            ("🕯️", ["candle", "darkness", "dark", "shadow", "shadows"]), ("🍯", ["sweet", "honey", "sugar", "candy"]),
            ("🫠", ["melt", "melting", "tease", "tempt"]), ("💫", ["dizzy", "spin", "spinning", "float", "floating", "high"]),
            ("🤞", ["hope", "wish", "wishing", "pray"]), ("😎", ["swag", "style", "slay", "fresh", "ice"]), ("🎯", ["aim", "target", "focus"]),
            ("🥂", ["toast", "celebrate", "celebration"]), ("🌶️", ["spicy", "tikha", "mirchi"]), ("👋", ["hello", "hi", "bye", "goodbye", "wave"]),
        ]
        var t: [String: String] = [:]
        for (e, ws) in groups { for w in ws where t[w] == nil { t[w] = e } }
        return t
    }()

    static func lookup(_ raw: String) -> String? {
        let w = raw.lowercased().filter { $0.isLetter || $0 == "'" }
        guard w.count > 1 else { return nil }
        if let e = table[w] { return e }
        for suffix in ["ing", "ed", "es", "s", "ly", "er", "d"] where w.hasSuffix(suffix) {
            let stem = String(w.dropLast(suffix.count))
            if stem.count < 3 { continue }
            if let e = table[stem] ?? table[stem + "e"] { return e }
        }
        return nil
    }
}

