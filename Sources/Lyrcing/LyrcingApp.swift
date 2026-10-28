import AppKit
import SwiftUI

@main
struct LyrcingApp: App {
    @StateObject private var model = AppModel()
    private let holder = LightsHolder()

    var body: some Scene {
        WindowGroup("Lyrcing") {
            ContentView(model: model)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    model.applyWindowLevel()
                    NSApp.activate(ignoringOtherApps: true)
                    if holder.lights == nil { holder.lights = EdgeLightController(model: model) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 720)
        .commands { LyrcingCommands(model: model) }

        Settings { SettingsView(model: model) }

        MenuBarExtra("Lyrcing", systemImage: "music.note.list") {
            Toggle("Edge light", isOn: $model.lightingEnabled)
            Picker("Color", selection: $model.lightMode) {
                ForEach(LightMode.allCases) { Text($0.rawValue).tag($0) }
            }
            Divider()
            Button("Quit Lyrcing") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

@MainActor final class LightsHolder { var lights: EdgeLightController? }
