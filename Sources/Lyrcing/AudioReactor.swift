import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

/// Listens to system audio (ScreenCaptureKit, audio only — no video is read) and turns it into
/// a beat pulse and loudness level. Needs the Screen Recording permission.
final class AudioReactor: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    @Published private(set) var status = "Off"
    private(set) var level = 0.0
    private(set) var lastBeat = 0.0
    private var beatStrength = 0.0

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "lyrcing.audio")
    private var lowpass: Float = 0
    private var bassAvg = 0.0

    static var now: Double { ProcessInfo.processInfo.systemUptime }

    /// 1 right on a strong beat, decaying to 0.
    func pulse(at t: Double) -> Double {
        if Self.simulated { return exp(-((t * 2.8).truncatingRemainder(dividingBy: 1)) * 5.5) }
        return beatStrength * exp(-(t - lastBeat) * 5.5)
    }
    /// Debug hook (LYRCING_FAKE_BEAT=1) to preview the effects without the Screen Recording permission.
    static let simulated = ProcessInfo.processInfo.environment["LYRCING_FAKE_BEAT"] != nil

    private func setStatus(_ s: String) { DispatchQueue.main.async { self.status = s } }

    func start() {
        guard stream == nil else { return }
        setStatus("Starting…")
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return setStatus("No display found") }
                let cfg = SCStreamConfiguration()
                cfg.capturesAudio = true
                cfg.excludesCurrentProcessAudio = true
                cfg.sampleRate = 48000
                cfg.channelCount = 2
                cfg.width = 2; cfg.height = 2
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                let s = SCStream(filter: SCContentFilter(display: display, excludingApplications: [], exceptingWindows: []),
                                 configuration: cfg, delegate: self)
                try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
                try await s.startCapture()
                stream = s
                setStatus("Listening")
            } catch {
                stream = nil
                setStatus("Allow Screen Recording in System Settings › Privacy & Security")
            }
        }
    }

    func stop() {
        let s = stream; stream = nil
        Task { try? await s?.stopCapture() }
        beatStrength = 0; level = 0
        setStatus("Off")
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        setStatus("Stopped: \(error.localizedDescription)")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sb.isValid else { return }
        try? sb.withAudioBufferList { list, _ in
            guard let buf = list.first, let raw = buf.mData else { return }
            let n = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
            guard n > 0 else { return }
            let p = raw.assumingMemoryBound(to: Float.self)
            var sum: Float = 0, bassSum: Float = 0
            for i in 0..<n {
                let x = p[i]
                lowpass += 0.02 * (x - lowpass)       // ~150 Hz one-pole low-pass
                sum += x * x
                bassSum += lowpass * lowpass
            }
            let rms = Double(sqrt(sum / Float(n)))
            let bass = Double(sqrt(bassSum / Float(n)))
            level += (rms - level) * 0.2
            let t = Self.now
            if bass > bassAvg * 1.35 + 0.0015, t - lastBeat > 0.25 {
                lastBeat = t
                beatStrength = min(1, max(0.35, bass / max(bassAvg, 1e-4) - 1))
            }
            bassAvg += (bass - bassAvg) * 0.04
        }
    }
}
