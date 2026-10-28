import AppKit
let out = CommandLine.arguments[1]
let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
path.addClip()
NSGradient(colors: [NSColor(hue: 0.74, saturation: 0.75, brightness: 0.55, alpha: 1),
                    NSColor(hue: 0.93, saturation: 0.7, brightness: 0.95, alpha: 1)])!.draw(in: rect, angle: -50)
let cfg = NSImage.SymbolConfiguration(pointSize: 420, weight: .bold)
if let sym = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let t = sym.tinted(.white)
    let s = t.size
    t.draw(in: NSRect(x: 512 - s.width / 2, y: 512 - s.height / 2, width: s.width, height: s.height))
}
img.unlockFocus()
extension NSImage {
    func tinted(_ c: NSColor) -> NSImage {
        let i = self.copy() as! NSImage
        i.lockFocus(); c.set()
        NSRect(origin: .zero, size: i.size).fill(using: .sourceAtop)
        i.unlockFocus(); return i
    }
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
