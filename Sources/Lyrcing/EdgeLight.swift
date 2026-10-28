import AppKit
import Combine
import SwiftUI

/// A soft glowing frame around the screen edge, like a ring light for your display.
struct EdgeLightView: View {
    @ObservedObject var model: AppModel

    private func currentColors() -> [Color] {
        if model.lightMode == .album,
           let c = Constellation.emphasisColor(model: model, at: model.monitor.position + 0.1) {
            return [c, c, c.opacity(0.85)]
        }
        return model.lightColors
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !model.isPlaying)) { ctx in
            let now = ctx.date
            let t = now.timeIntervalSinceReferenceDate
            let colors = currentColors()
            let beat = (model.audioSync ? model.audio.pulse(at: AudioReactor.now) : 0) * model.tone.energy
            let w = (18 + model.thickness * 70) * (1 + beat * 0.3)
            let breath = 0.9 + 0.1 * sin(t * 1.4)
            let pulse = model.pulseOnBeat ? exp(-now.timeIntervalSince(model.lastLineChange) * 3.2) : 0
            let gradient = AngularGradient(colors: colors + [colors[0]], center: .center,
                                           angle: .degrees((t * 14).truncatingRemainder(dividingBy: 360)))
            ZStack {
                if model.look.edgeStyle == .glow {
                    Rectangle().strokeBorder(gradient, lineWidth: w * 1.2).blur(radius: w * 0.9).opacity(0.55)
                    Rectangle().strokeBorder(gradient, lineWidth: w * 0.3).blur(radius: w * 0.2)
                }
                Rectangle().strokeBorder(gradient, lineWidth: 3)
            }
            .opacity(min(1, model.intensity * (model.tone == .sad ? 0.8 : 1) * breath + max(pulse * 0.35 * model.tone.energy, beat * 0.4)))
            .scaleEffect(1 + pulse * 0.01)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

@MainActor
final class EdgeLightController {
    private var panels: [NSPanel] = []
    private var bag = Set<AnyCancellable>()
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        model.$lightingEnabled.sink { [weak self] on in
            DispatchQueue.main.async { on ? self?.show() : self?.hide() }
        }.store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, self.model.lightingEnabled else { return }
                self.hide(); self.show()
            }.store(in: &bag)
    }

    private func show() {
        guard panels.isEmpty else { return }
        for screen in NSScreen.screens {
            let p = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.level = .screenSaver
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            p.contentView = NSHostingView(rootView: EdgeLightView(model: model))
            p.setFrame(screen.frame, display: true)
            p.orderFrontRegardless()
            panels.append(p)
        }
    }

    private func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}
