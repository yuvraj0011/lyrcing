import Foundation

/// Word -> emoji for English, Hindi, Punjabi, Urdu and romanized Hindi/Punjabi ("Hinglish").
///
/// Indic scripts are matched through a consonant "skeleton" of their Latin transliteration
/// (ICU), so "प्यार", "ਪਿਆਰ", "pyaar" and "pyar" all land on the same entry. Layers, best first:
/// hand-picked words -> Unicode CLDR annotations (Resources/emoji_index.json).
enum Lexicon {
    enum Script { case latin, indic, other }

    // MARK: Normalisation

    static func script(of w: String) -> Script {
        for u in w.unicodeScalars {
            if u.value >= 0x0600 && u.value <= 0x0DFF { return .indic }       // Arabic, Devanagari ... Malayalam
            if u.value >= 0x0E00 && u.value < 0x1F000 && CharacterSet.letters.contains(u) { return .other }   // Thai, Korean, Japanese, Cyrillic is below
            if u.value >= 0x0400 && u.value <= 0x04FF { return .other }      // Cyrillic
        }
        return .latin
    }

    /// Letters and combining marks only (Indic vowel signs are marks, not letters).
    static func clean(_ w: String) -> String {
        String(w.unicodeScalars.filter { CharacterSet.letters.contains($0) || $0 == "'" }).precomposedStringWithCanonicalMapping.lowercased()
    }

    static func latinize(_ w: String) -> String {
        let l = w.applyingTransform(.toLatin, reverse: false) ?? w
        return (l.applyingTransform(.stripDiacritics, reverse: false) ?? l).lowercased()
    }

    /// Consonant skeleton: vowels and 'h' dropped, look-alike consonants merged, repeats collapsed.
    static func skeleton(_ w: String) -> String {
        var out: [Character] = []
        for ch in latinize(w) {
            var c = ch
            switch c { case "q", "x": c = "k"; case "z": c = "j"; case "f": c = "p"; case "w": c = "v"; default: break }
            if "aeiouh".contains(c) || !c.isLetter { continue }
            if out.last == c { continue }
            out.append(c)
        }
        if out.count > 2, let l = out.last, l == "m" || l == "n" { out.removeLast() }
        return String(out)
    }

    /// Syllables for timing; Indic words are counted on their transliteration.
    static func syllables(_ w: String) -> Double {
        let lat = latinize(w).filter(\.isLetter)
        if lat.isEmpty { return 1 }
        var groups = 0, prev = false
        for ch in lat {
            let v = "aeiouy".contains(ch)
            if v && !prev { groups += 1 }
            prev = v
        }
        if script(of: w) == .indic, lat.hasSuffix("a"), groups > 1 { groups -= 1 }   // schwa deletion
        return Double(max(1, groups))
    }

    // MARK: Data

    /// Hand-picked words. A leading "=" means exact spelling only (too ambiguous for skeleton matching).
    private static let curated: [(String, [String])] = [
        ("❤️", ["pyaar", "pyar", "pyara", "ishq", "ishk", "mohabbat", "muhabbat", "prem", "इश्क़", "ਇਸ਼ਕ", "ਮੁਹੱਬਤ"]),
        ("💖", ["chahat", "chaah", "chahe", "chahen", "chahna", "chaahe"]),
        ("💗", ["dil", "dilbar", "dilruba", "dilli", "ਦਿਲ"]),
        ("💞", ["=jaan", "=jaanu", "=जान", "=जानू", "=ਜਾਨ", "sanam", "sajna", "sajan", "mahi", "mahiya", "mitwa", "humdum", "hamdam", "balam", "piya", "saajan"]),
        ("🤝", ["yaara", "yaar", "yaari", "dost", "dosti", "yaaran", "ਯਾਰ", "ਯਾਰੀ"]),
        ("🙏", ["rab", "khuda", "ram", "bhagwan", "allah", "ਰੱਬ"]), ("🤲", ["dua", "duaa", "ibadat", "ardaas"]),
        ("👀", ["aankhen", "aankhein", "aankhon", "akhiyan", "akhian", "nazar", "nazrein", "nigaah", "nigahen", "nain", "naina", "nainon", "ਅੱਖ", "ਅੱਖਾਂ", "ਨਜ਼ਰ"]),
        ("🌙", ["raat", "raaton", "chand", "chaand", "chandni", "chanda", "ਰਾਤ", "ਚੰਨ"]),
        ("⭐", ["=taare", "=tare", "=taara", "=tara", "=sitare", "=sitara", "=तारे", "=तारा", "=सितारे", "=सितारा", "=ਤਾਰੇ", "=ਤਾਰਾ"]),
        ("🌌", ["aasman", "asman", "aasmaan", "falak", "gagan", "ambar", "ਅਸਮਾਨ"]),
        ("☀️", ["suraj", "dhoop", "dhup", "surya", "ਸੂਰਜ"]), ("🌅", ["subah", "savera", "sawera", "sehar", "bhor"]),
        ("🌇", ["shaam", "shaam", "sham", "dhalti"]),
        ("✨", ["roshni", "roshan", "noor", "jaadu", "jadoo", "chamak", "chamakna", "jagmag", "ujala", "ਰੋਸ਼ਨੀ"]),
        ("🌧️", ["baarish", "barsaat", "barkha", "saawan", "sawan", "badra", "megha", "ਬਾਰਿਸ਼", "ਮੀਂਹ"]),
        ("💧", ["paani", "pani", "boond", "boondein", "ਪਾਣੀ"]), ("🌊", ["samundar", "sagar", "darya", "dariya", "lehar", "lehren", "kinara", "sahil"]),
        ("😭", ["aansu", "ansu", "aansoo", "ashq", "rona", "roye", "rote", "roti", "roon", "ਹੰਝੂ", "ਅੱਥਰੂ"]),
        ("💔", ["dard", "judai", "judaai", "bichhad", "bichhadna", "bichhde", "bewafa", "bewafai", "toota", "tootna", "dhokha", "ਦਰਦ", "ਜੁਦਾਈ"]),
        ("😔", ["gham", "ghum", "udaas", "udas", "afsos", "pareshan", "pareshaan"]),
        ("🥀", ["tanha", "tanhai", "tanhaai", "akela", "akeli", "adhoora", "adhura", "adhuri", "ਇਕੱਲਾ"]),
        ("😊", ["khushi", "khushiyan", "khush", "muskaan", "muskan", "hasi", "haseen", "ਖ਼ੁਸ਼ੀ"]),
        ("💭", ["yaad", "yaadein", "yaadon", "yaadan", "khwab", "khwaab", "sapna", "sapne", "khayal", "khayaal", "ਯਾਦ", "ਸੁਪਨਾ"]),
        ("⏳", ["intezaar", "intezar", "intzaar", "intazaar", "ਉਡੀਕ"]), ("⏰", ["waqt", "vakt", "samay", "pal", "lamha", "lamhe", "ghadi", "ਵੇਲਾ"]),
        ("💋", ["honth", "hontho", "labon", "lab", "chumma", "bosa", "ਬੁੱਲ੍ਹ"]), ("🥰", ["chehra", "chehre", "mukhda", "sohni", "sohna", "ਸੋਹਣੀ", "ਸੋਹਣਾ"]),
        ("🌹", ["phool", "phoolon", "gulab", "gulaab", "kali", "bahaar", "bahar", "ਫੁੱਲ"]), ("🍃", ["hawa", "hawaa", "pawan", "havaa", "fiza", "ਹਵਾ"]),
        ("☁️", ["badal", "baadal", "badli", "ghata", "ਬੱਦਲ"]), ("🌪️", ["toofan", "tufan", "aandhi", "tufaan"]),
        ("🔥", ["aag", "agni", "junoon", "jalna", "jale", "jalta", "shola", "sholay", "angaar", "ਅੱਗ"]),
        ("💨", ["dhuan", "dhuaan", "dhua", "udna", "udta", "ud"]), ("🕊️", ["parinda", "panchi", "pankh", "pankhon", "udaan", "ਪੰਛੀ"]),
        ("🌟", ["zindagi", "zindgi", "jindagi", "jeevan", "jeena", "ਜ਼ਿੰਦਗੀ"]), ("🌍", ["duniya", "dunia", "jahan", "jahaan", "jag", "ਦੁਨੀਆ"]),
        ("🏠", ["ghar", "makaan", "ghar", "ਘਰ"]), ("🛣️", ["safar", "raasta", "rasta", "raah", "raahein", "raaste", "ਸਫ਼ਰ"]), ("🎯", ["manzil", "manzilein", "ਮੰਜ਼ਿਲ"]),
        ("🤪", ["pagal", "deewana", "deewani", "diwana", "diwani", "mastana", "mastani", "ਪਾਗਲ"]), ("💃", ["naach", "naachna", "naacho", "nachna", "nachde", "nache", "gidha", "giddha", "ਨੱਚ"]),
        ("🕺", ["bhangra", "balle", "ਭੰਗੜਾ"]), ("🥁", ["dhol", "dholki", "tabla", "damru", "ਢੋਲ"]), ("🎵", ["gaana", "gana", "geet", "sur", "taal", "raag", "dhun", "ghazal", "nagma"]),
        ("🍻", ["sharab", "daaru", "daru", "peg", "jaam", "nasha", "nashe", "madira", "ਸ਼ਰਾਬ", "ਦਾਰੂ"]),
        ("👧", ["kudi", "kudiye", "ਕੁੜੀ", "ladki", "gori"]), ("👦", ["munda", "mundey", "ਮੁੰਡਾ", "ladka", "gabru", "ਗੱਭਰੂ"]), ("😎", ["jatt", "jat", "ਜੱਟ", "swag", "rangbaaz"]),
        ("👑", ["raja", "rani", "badshah", "shehzada", "malika", "ਰਾਜਾ"]), ("💰", ["paisa", "paise", "daulat", "rupaye", "rupay", "lakh", "crore", "ਪੈਸਾ"]),
        ("💍", ["shaadi", "vivah", "mangni", "doli", "baraat", "mehndi", "ਵਿਆਹ"]),
        ("🌈", ["rang", "rangon", "rangeen", "rangila", "rangeela", "ਰੰਗ"]), ("🪔", ["diya", "deepak", "diwali", "deep"]),
        ("💬", ["baat", "baatein", "baten", "kehna", "kehte", "keh", "bolna", "bole", "bol", "afsana", "kahani", "kissa", "kisse", "ਗੱਲ"]),
        ("📱", ["phone", "mobile", "call"]), ("📸", ["photo", "tasveer", "tasvir", "ਤਸਵੀਰ"]),
        ("❤️", ["=प्यार", "=प्यारा", "=इश्क", "=इश्क़", "=मोहब्बत", "=मुहब्बत", "=प्रेम"]),
        ("💗", ["=दिल", "=दिलों", "=दिलबर", "=दिलरुबा"]), ("🌙", ["=रात", "=रातें", "=रातों", "=चांद", "=चाँद", "=चंदा", "=चाँदनी", "=चांदनी"]),
        ("👀", ["=आँखें", "=आंखें", "=आँखों", "=आंखों", "=नज़र", "=नजर", "=नज़रें", "=निगाहें", "=नैना", "=नैन"]),
        ("😭", ["=आँसू", "=आंसू", "=आँसुओं", "=रोना", "=रोये", "=रोते"]), ("💔", ["=दर्द", "=जुदाई", "=बेवफा", "=बेवफ़ा", "=धोखा", "=टूटा", "=टूटे"]),
        ("😔", ["=ग़म", "=गम", "=उदास", "=अफ़सोस"]), ("💭", ["=याद", "=यादें", "=यादों", "=ख़्वाब", "=ख्वाब", "=सपना", "=सपने", "=ख़याल", "=खयाल"]),
        ("🌟", ["=ज़िंदगी", "=जिंदगी", "=ज़िन्दगी", "=जिन्दगी", "=जीवन"]), ("🌍", ["=दुनिया", "=जहाँ", "=जहां", "=जहान"]),
        ("🙏", ["=रब", "=रब्बा", "=ख़ुदा", "=खुदा", "=भगवान", "=अल्लाह"]), ("🤲", ["=दुआ", "=दुआएँ", "=इबादत"]),
        ("🔥", ["=आग", "=जुनून", "=जलना", "=जले", "=जलता", "=शोला", "=अंगार"]), ("☀️", ["=सूरज", "=धूप"]), ("🌅", ["=सुबह", "=सवेरा"]),
        ("🌌", ["=आसमान", "=आसमां", "=गगन", "=फ़लक", "=फलक"]), ("🌧️", ["=बारिश", "=बरसात", "=बरखा", "=सावन", "=बादल"]),
        ("😊", ["=ख़ुशी", "=खुशी", "=ख़ुशियाँ", "=मुस्कान", "=मुस्कुराना", "=हँसी"]), ("🥀", ["=तन्हा", "=तन्हाई", "=अकेला", "=अकेली", "=अधूरा", "=अधूरी"]),
        ("✨", ["=रोशनी", "=नूर", "=जादू", "=चमक", "=उजाला"]), ("⏳", ["=इंतज़ार", "=इंतजार", "=इन्तज़ार", "=इन्तजार"]), ("⏰", ["=वक़्त", "=वक्त", "=लम्हा", "=लम्हे", "=पल"]),
        ("🌹", ["=फूल", "=फूलों", "=गुलाब", "=बहार"]), ("🍃", ["=हवा", "=हवाओं", "=पवन", "=फ़िज़ा"]), ("🛣️", ["=सफ़र", "=सफर", "=रास्ता", "=रास्ते", "=राह", "=राहें"]),
        ("🤪", ["=पागल", "=दीवाना", "=दीवानी", "=मस्ताना"]), ("💃", ["=नाच", "=नाचो", "=नाचना", "=नाचे"]), ("🥁", ["=ढोल", "=तबला"]), ("🍻", ["=शराब", "=दारू", "=जाम", "=नशा", "=नशे"]),
        ("🤝", ["=यार", "=यारा", "=यारी", "=दोस्त", "=दोस्ती"]), ("💬", ["=बात", "=बातें", "=कहानी", "=क़िस्सा", "=किस्से", "=अफ़साना"]),
        ("💞", ["=साजन", "=सनम", "=पिया", "=बालम", "=हमदम", "=मितवा", "=साजना", "=सजना"]), ("🥰", ["=चेहरा", "=चेहरे", "=मुखड़ा"]), ("💋", ["=होंठ", "=होठों", "=लबों"]),
        ("🌈", ["=रंग", "=रंगों", "=रंगीन"]), ("🏠", ["=घर"]), ("💧", ["=पानी", "=बूंद", "=बूँद"]), ("🌊", ["=समंदर", "=सागर", "=दरिया", "=लहर", "=किनारा", "=साहिल"]),
        ("🫂", ["=बाहों", "=बाँहों", "=आग़ोश", "=गले"]), ("🙈", ["=शर्म", "=हया"]), ("💍", ["=शादी", "=विवाह", "=डोली", "=बारात", "=मेहंदी"]), ("⭐", ["=तारे", "=तारा", "=सितारे", "=सितारा", "=तारों"]),
        ("💀", ["maut", "qatl", "qabr", "kafan", "मौत"]), ("🔥🔥", []), ("🩸", ["khoon", "lahu", "ਖੂਨ"]), ("💊", ["ilaaj", "dawa", "dawaa", "marz", "ਦਵਾਈ"]),
        ("🙈", ["sharam", "sharmana", "sharmaye", "sharmaana", "haya", "ਸ਼ਰਮ"]), ("😍", ["haseen", "khoobsurat", "khubsurat", "husn", "husna", "ਹੁਸਨ"]),
        ("🤞", ["umeed", "ummeed", "aas", "ummid", "dua", "ਉਮੀਦ"]), ("🎬", ["filmy", "film", "kahaani"]),
        ("🏃", ["bhaag", "bhaagna", "daud", "daudna", "bhaagte"]), ("🧿", ["nazar", "nazarlag", "buri"]),
        ("🫂", ["gale", "galey", "aagosh", "baahon", "bahon", "baahein", "baanhein", "baah"]), ("🤲", ["jholi", "jholiyan"]),
        ("🌹", ["gulaab", "gulabi"]), ("🌺", ["kamal", "kamla"]), ("🐦", ["bulbul", "koyal", "kauwa", "mor", "ਮੋਰ"]),
    ]

    private static let hinglishMarkers: Set<String> = [
        "hai", "hain", "mein", "tu", "tum", "tera", "teri", "tere", "mera", "meri", "mere", "ko", "ka", "ki", "ke", "nahi", "nahin",
        "kya", "hum", "aur", "mujhe", "tujhe", "tujhko", "kyun", "kyu", "kaise", "yaara", "yaar", "sanam", "dil", "pyaar", "ishq",
        "zindagi", "phir", "jab", "tab", "hoon", "raha", "rahi", "woh", "yeh", "bhi", "toh", "tumhe", "humein", "hume", "bas",
        "saath", "baat", "bata", "batao", "jaane", "jaana", "koi", "kuch", "sab", "abhi", "tak", "wala", "wali", "ni", "nu", "nai",
        "tenu", "mainu", "menu", "sanu", "ae", "ve", "oye", "ohda", "ohdi", "kuri", "kyun", "dass", "aaja", "aaya", "gaya", "gayi", "ishq", "mahiya", "sajna", "sohnya",
    ]

    static func isHinglish(_ words: [String]) -> Bool { words.contains { hinglishMarkers.contains(clean($0)) } }

    /// Function words whose skeletons must never get an emoji (e.g. "tera" collides with "taara").
    private static let skeletonBlock: Set<String> = ["tr", "mr", "tm", "hm", "kc", "kn", "ks", "kb", "jb", "tb", "ph", "ab", "sb", "bs", "kh", "ky", "tj", "mj", "hl"]

    /// Roman Hindi / Punjabi / Urdu grammar words: never decorated, whatever a dictionary says.
    private static let functionWords: Set<String> = [
        "hai", "hain", "hoon", "ho", "hota", "hoti", "hote", "tha", "thi", "the", "raha", "rahi", "rahe", "main", "mai", "mein", "me", "tu", "tum",
        "tera", "teri", "tere", "mera", "meri", "mere", "tumhara", "hamara", "ko", "ka", "ki", "ke", "se", "pe", "par", "bhi", "toh", "to", "jo", "bas",
        "ab", "phir", "jab", "tab", "kya", "kyun", "kyu", "kaise", "kitna", "itna", "jitna", "koi", "kuch", "sab", "abhi", "tak", "na", "ni", "nu", "nai",
        "nahi", "nahin", "woh", "wo", "yeh", "ye", "hum", "aur", "mujhe", "tujhe", "tumhe", "humein", "hume", "mujhko", "tujhko", "usse", "isse", "unhe",
        "unko", "inhe", "tenu", "mainu", "menu", "sanu", "ae", "ve", "oye", "hi", "ek", "do", "kar", "karo", "kiya", "gaya", "gayi", "jaana", "jaane",
        "aaya", "aaja", "le", "de", "dena", "lena", "wala", "wali", "sa", "si", "se", "agar", "lekin", "magar", "ya", "yaa", "jaise", "waise", "bin", "bina",
    ]

    /// Very common words that CLDR happens to tag with an emoji; they should stay plain text.
    private static let plain: Set<String> = ["तुम", "तुझे", "तुझको", "मुझे", "मुझको", "हम", "बस", "पर", "मिल", "इतना", "और", "नहीं", "ਪਰ", "ਉੱਤੇ", "ਸਿਰ", "ਨਾਮ", "लंबी", "ਬੂਟਾ", "कोई", "ਕੋਈ"]

    private struct Index {
        var curatedExact: [String: String] = [:]
        var curatedSkeleton: [String: String] = [:]
        var cldrExact: [String: String] = [:]          // hi, pa, ur, hl keys as written
        var english: [String: String] = [:]
        var other: [String: String] = [:]               // every other non-Latin language, exact words
    }

    private static let index: Index = {
        var ix = Index()
        for (e, ws) in curated {
            for w in ws {
                if w.hasPrefix("=") { ix.curatedExact[clean(String(w.dropFirst()))] = e; continue }
                ix.curatedExact[clean(w)] = e
                let sk = skeleton(w)
                if sk.count >= 4, ix.curatedSkeleton[sk] == nil, !skeletonBlock.contains(sk) { ix.curatedSkeleton[sk] = e }
            }
        }
        let path = ProcessInfo.processInfo.environment["LEXICON_JSON"] ?? Bundle.main.path(forResource: "emoji_index", ofType: "json")
        if let path, let data = FileManager.default.contents(atPath: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            ix.english = json["en"] ?? [:]
            for lang in ["hl", "hi", "pa", "ur", "pk"] {
                for (w, e) in json[lang] ?? [:] where ix.cldrExact[w] == nil { ix.cldrExact[w] = e }
            }
            for lang in ["gu", "mr", "bn", "ta", "te", "kn", "ml", "ne", "ar", "fa", "ko", "ja", "ru", "th"] {
                for (w, e) in json[lang] ?? [:] where ix.other[w] == nil { ix.other[w] = e }
            }
        }
        return ix
    }()

    /// Builds the index off the main thread so the first lyric line never stutters.
    static func warmUp() { DispatchQueue.global(qos: .utility).async { _ = index } }

    private static var memo: [String: String?] = [:]

    static func emoji(for raw: String, hinglish: Bool) -> String? {
        let key = (hinglish ? "h:" : "l:") + raw
        if let m = memo[key] { return m }
        let r = lookup(raw, hinglish: hinglish).map(present)
        memo[key] = r
        return r
    }

    /// Force emoji (not text) presentation for single-scalar dingbats.
    private static func present(_ e: String) -> String {
        let s = e.unicodeScalars
        return s.count == 1 && s.first!.value < 0x1F000 ? e + "\u{FE0F}" : e
    }

    private static func lookup(_ raw: String, hinglish: Bool) -> String? {
        let w = clean(raw)
        guard w.count > 1, !plain.contains(w), !functionWords.contains(w) else { return nil }
        let ix = index
        if script(of: w) == .other { return ix.other[w] ?? ix.cldrExact[w] }
        if script(of: w) == .indic {
            if let e = ix.curatedExact[w] { return e }
            let sk = skeleton(w)
            if !skeletonBlock.contains(sk) {
                if let e = ix.curatedSkeleton[sk] { return e }
                if let e = ix.cldrExact[w] { return e }
            } else if let e = ix.cldrExact[w] { return e }
            return ix.other[w]
        }
        if let e = Emoji.lookup(w) { return e }
        if hinglish {
            if let e = ix.curatedExact[w] { return e }
            let sk = skeleton(w)
            if !skeletonBlock.contains(sk) {
                if let e = ix.curatedSkeleton[sk] { return e }
            }
            if let e = ix.cldrExact[w] { return e }
        } else if let e = ix.curatedExact[w], w.count > 3 { return e }
        if let e = ix.english[w] { return e }
        return nil
    }
}

/// Ambient scene mood derived from the emoji in a lyric line.
enum Mood {
    case love, sad, fire, party, night, cold, water

    private static let table: [(Mood, String)] = [
        (.love, "❤💗💕💞💖💘💟😍🥰😘💋💍🌹💝💓💌🤍💛🫂👀🤝"), (.sad, "😭😢💔🥀😔🥲☔🌧"), (.fire, "🔥💥🌶⚡🧨🌋"),
        (.party, "💃🕺🎉🪩🍻🥂🎵🎶🎤🥁🎸🎊🎧🪔"), (.night, "🌙🌃🌌⭐🌟✨💫🌠🌑🌕💭"), (.cold, "❄🧊⛄☃"), (.water, "🌊💧🏖"),
    ]

    /// Decorative emoji that suit the feeling, used on words with no literal emoji of their own.
    var vibes: [String] {
        switch self {
        case .love: return ["💫", "💕", "🥺", "✨", "🫶", "💗"]
        case .sad: return ["🥀", "💧", "🖤", "🌑", "🥲"]
        case .fire: return ["🔥", "💥", "⚡", "😤", "🌋"]
        case .party: return ["🎉", "💃", "🪩", "🔥", "🎶", "🕺"]
        case .night: return ["🌙", "✨", "💫", "⭐", "🌌"]
        case .cold: return ["❄️", "🧊", "💙", "✨"]
        case .water: return ["🌊", "💧", "🫧", "✨"]
        }
    }

    static func dominant(of emojis: [String]) -> Mood? {
        var counts: [Mood: Int] = [:]
        for e in emojis {
            for s in e.unicodeScalars where s.value != 0xFE0F {
                if let m = table.first(where: { $0.1.unicodeScalars.contains(s) })?.0 { counts[m, default: 0] += 1; break }
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }
}
