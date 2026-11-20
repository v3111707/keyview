// TEMPORARY: renders the keyboard to PNG for a visual check. Delete after use.
import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import KeyView

@MainActor
@Test func snapshotTemp() throws {
    func source(_ id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return list?.first
    }
    let cases: [(name: String, layout: String, scheme: ColorScheme, pressed: [Int], shift: Bool)] = [
        ("en-light", "com.apple.keylayout.ABC", .light, [kVK_ANSI_F, kVK_ANSI_J], false),
        ("en-dark", "com.apple.keylayout.ABC", .dark, [kVK_ANSI_T], false),
        ("ru-light", "com.apple.keylayout.RussianWin", .light, [], false),
        ("ru-dark-shift", "com.apple.keylayout.RussianWin", .dark, [kVK_Shift], true),
    ]
    for c in cases {
        let state = KeyboardState()
        state.labels = try #require(LayoutReader.labels(for: source(c.layout)))
        state.pressed = Set(c.pressed.map { UInt16($0) })
        state.shift = c.shift
        let view = KeyboardView(state: state)
            .environment(\.colorScheme, c.scheme)
            .frame(width: 760, height: 332)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/tmp/keyview-check/\(c.name).png"))
    }
}
