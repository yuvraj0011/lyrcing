import SwiftUI

/// Menu-bar menus: everything in Settings is also reachable here, with keyboard shortcuts.
struct LyrcingCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandMenu("Playback") {
            Button(model.isPlaying ? "Pause" : "Play") { model.monitor.togglePlay() }.keyboardShortcut(.space, modifiers: [])
            Button("Next Track") { model.monitor.next() }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("Previous Track") { model.monitor.previous() }.keyboardShortcut(.leftArrow, modifiers: [])
            Divider()
            Toggle("Sync Effects to the Beat", isOn: $model.audioSync).keyboardShortcut("b", modifiers: [.command, .option])
        }

        CommandMenu("Look") {
            Menu("Lyric Style") {
                Picker("Lyric Style", selection: $model.viewMode) { ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
            }
            Menu("Preset") {
                Button("Full") { model.apply(.full) }.keyboardShortcut("1")
                Button("Balanced") { model.apply(.balanced) }.keyboardShortcut("2")
                Button("Minimal (words, nodes & lines only)") { model.apply(.minimal) }.keyboardShortcut("3")
            }
            Divider()
            Section("Words") {
                Toggle("Pump the Current Word", isOn: $model.look.emphasis)
                Toggle("Rings & Beat Ripples", isOn: $model.look.rings)
                Toggle("Entrance Animations", isOn: $model.look.entrance)
                Menu("Word Colors") {
                    Picker("Word Colors", selection: $model.look.colorMode) { ForEach(ColorMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
                }
            }
            Section("Scene") {
                Toggle("Connection Lines", isOn: $model.look.connections)
                Toggle("Light Sparks on Lines", isOn: $model.look.sparks)
                Toggle("Sparkle Burst", isOn: $model.look.burst)
                Toggle("Color Glow", isOn: $model.look.colorWash)
                Toggle("Twinkling Stars", isOn: $model.look.stars)
                Toggle("Ambient Particles", isOn: $model.look.moodParticles)
                Toggle("Camera Motion", isOn: $model.look.cameraMotion)
            }
            Section("Emoji") {
                Toggle("Emoji for Lyric Words", isOn: $model.showEmoji).keyboardShortcut("e", modifiers: [.command, .option])
                Toggle("Emoji Explosions", isOn: $model.look.emojiExplosions)
            }
            Divider()
            Menu("Effects Strength") {
                Picker("Effects Strength", selection: $model.effects) { ForEach(Effects.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
            }
            Menu("Mood") {
                Picker("Mood", selection: $model.toneChoice) {
                    Text("Auto (from lyrics)").tag("Auto")
                    ForEach(Tone.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.pickerStyle(.inline)
            }
            Toggle("Prefer English / Roman Lyrics", isOn: $model.preferRoman)
            Divider()
            Button("Larger Text") { model.fontScale = min(1.5, model.fontScale + 0.1) }.keyboardShortcut("+")
            Button("Smaller Text") { model.fontScale = max(0.6, model.fontScale - 0.1) }.keyboardShortcut("-")
            Button("Actual Size") { model.fontScale = 1 }.keyboardShortcut("0")
        }

        CommandMenu("Edge Light") {
            Toggle("Show Edge Light", isOn: $model.lightingEnabled).keyboardShortcut("l")
            Menu("Style") {
                Picker("Style", selection: $model.look.edgeStyle) { ForEach(EdgeStyle.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
            }
            Menu("Color") {
                Picker("Color", selection: $model.lightMode) { ForEach(LightMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
            }
            Menu("Brightness") {
                Button("Low") { model.intensity = 0.4 }; Button("Medium") { model.intensity = 0.7 }; Button("High") { model.intensity = 1 }
            }
            Menu("Thickness") {
                Button("Thin") { model.thickness = 0.1 }; Button("Medium") { model.thickness = 0.4 }; Button("Thick") { model.thickness = 0.8 }
            }
            Toggle("Pulse on Each Lyric Line", isOn: $model.pulseOnBeat)
        }

        CommandGroup(after: .windowArrangement) {
            Toggle("Keep Window on Top", isOn: $model.alwaysOnTop).keyboardShortcut("t", modifiers: [.command, .option])
            Menu("Player Bar") {
                Picker("Player Bar", selection: $model.look.playerBar) { ForEach(PlayerBarMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
            }
        }
    }
}
