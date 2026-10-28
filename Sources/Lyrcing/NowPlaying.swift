import AppKit
import Combine

extension Notification.Name { static let automationDenied = Notification.Name("lyrcing.automationDenied") }

enum PlayerSource: String {
    case music = "Music"
    case spotify = "Spotify"

    var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
}

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var source: PlayerSource
    var id: String { "\(artist)–\(title)" }
}

/// Polls Apple Music / Spotify through AppleScript. Never launches a player that isn't running.
@MainActor
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false

    private var basePosition = 0.0
    private var baseDate = Date()
    private var timer: Timer?
    private let queue = DispatchQueue(label: "lyrcing.nowplaying")

    var position: Double {
        isPlaying ? basePosition + Date().timeIntervalSince(baseDate) : basePosition
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let candidates = [PlayerSource.spotify, .music].filter { running.contains($0.bundleID) }
        queue.async { [weak self] in
            var best: (Track, Bool, Double)?
            for source in candidates {
                guard let r = Self.query(source) else { continue }
                if r.1 { best = r; break }
                if best == nil { best = r }
            }
            DispatchQueue.main.async { self?.apply(best) }
        }
    }

    private func apply(_ result: (Track, Bool, Double)?) {
        guard let (t, playing, pos) = result else {
            track = nil; isPlaying = false; basePosition = 0
            return
        }
        if track != t { track = t }
        if isPlaying != playing { isPlaying = playing }
        basePosition = pos
        baseDate = Date()
    }

    private nonisolated static func query(_ source: PlayerSource) -> (Track, Bool, Double)? {
        let sep = "|||"
        let script = """
        tell application "\(source.rawValue)"
            try
                if player state is stopped then return "stopped"
                set stateText to player state as string
                set theTrack to current track
                return stateText & "\(sep)" & (name of theTrack) & "\(sep)" & (artist of theTrack) & "\(sep)" & (album of theTrack) & "\(sep)" & (duration of theTrack) & "\(sep)" & (player position)
            on error
                return "stopped"
            end try
        end tell
        """
        var err: NSDictionary?
        let out = NSAppleScript(source: script)?.executeAndReturnError(&err)
        if let err {
            let code = err[NSAppleScript.errorNumber] as? Int ?? 0
            Self.log("\(source.rawValue) AppleScript error \(code): \(err)")
            if code == -1743 { DispatchQueue.main.async { NotificationCenter.default.post(name: .automationDenied, object: nil) } }
        }
        guard let result = out?.stringValue, result != "stopped" else { return nil }
        let p = result.components(separatedBy: sep)
        guard p.count == 6 else { return nil }
        func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        var duration = num(p[4])
        if source == .spotify { duration /= 1000 }
        let track = Track(title: p[1], artist: p[2], album: p[3], duration: duration, source: source)
        return (track, p[0] == "playing", num(p[5]))
    }

    nonisolated static func log(_ msg: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Lyrcing.log")
        let line = "\(Date()) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }

    // MARK: Controls

    func run(_ command: String) {
        guard let source = track?.source else { return }
        let src = "tell application \"\(source.rawValue)\" to \(command)"
        queue.async { _ = NSAppleScript(source: src)?.executeAndReturnError(nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.poll() }
    }

    func togglePlay() { run("playpause") }
    func next() { run("next track") }
    func previous() { run("previous track") }
    func seek(to seconds: Double) {
        basePosition = seconds; baseDate = Date()
        run("set player position to \(seconds)")
    }
}
