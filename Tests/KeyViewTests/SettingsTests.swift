import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import KeyView

@MainActor
struct SettingsTests {
    private let suiteName = "keyview-tests-\(UUID().uuidString)"
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    private func cleanUp() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: Saved settings

    @Test func startsWithDefaults() {
        defer { cleanUp() }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.theme == .classic)
        #expect(settings.opacity == 1)
        #expect(settings.hotKey == .standard)
    }

    @Test func remembersChanges() {
        defer { cleanUp() }
        let shortcut = Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(controlKey))
        let settings = AppSettings(defaults: defaults)
        settings.theme = .outline
        settings.opacity = 0.5
        settings.hotKey = shortcut

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.theme == .outline)
        #expect(reloaded.opacity == 0.5)
        #expect(reloaded.hotKey == shortcut)
    }

    @Test func keepsOpacityInRange() {
        defer { cleanUp() }
        defaults.set(5.0, forKey: "opacity")
        #expect(AppSettings(defaults: defaults).opacity == 1)
        defaults.set(0.0, forKey: "opacity")
        #expect(AppSettings(defaults: defaults).opacity == 0.2)
    }

    // MARK: Shortcut

    @Test func shortcutNeedsCommandOrControl() {
        let k = UInt16(kVK_ANSI_K)
        #expect(Shortcut(keyCode: k, flags: []) == nil)
        #expect(Shortcut(keyCode: k, flags: [.option]) == nil)
        #expect(Shortcut(keyCode: k, flags: [.option, .shift]) == nil)
        #expect(Shortcut(keyCode: k, flags: [.command, .option]) == .standard)
        #expect(Shortcut(keyCode: k, flags: [.control])?.modifiers == UInt32(controlKey))
    }

    @Test func shortcutDisplay() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey | shiftKey | controlKey | optionKey))
        #expect(shortcut.displayString == "⌃⌥⇧⌘F5")
        #expect(shortcut.menuKeyEquivalent == String(Character(UnicodeScalar(UInt32(NSF5FunctionKey))!)))
        #expect(Shortcut.standard.modifierFlags == [.command, .option])
        #expect(Shortcut(keyCode: UInt32(kVK_Return), modifiers: UInt32(cmdKey)).displayString == "⌘↩")
    }

    // MARK: Recording a shortcut

    private func keyPress(_ code: Int, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
            keyCode: UInt16(code)
        ))
    }

    @Test func recordsShortcutWithCommandOrControl() throws {
        let recorder = ShortcutRecorder()
        var paused = false
        var applied: [Shortcut] = []
        recorder.pause = { paused = true }
        recorder.apply = { applied.append($0); return true }

        recorder.start()
        #expect(paused)
        #expect(recorder.isRecording)

        recorder.record(try keyPress(kVK_ANSI_J, [.option]))
        #expect(recorder.message == ShortcutRecorder.needsCommandOrControl)
        #expect(recorder.isRecording)
        #expect(applied.isEmpty)

        recorder.record(try keyPress(kVK_ANSI_J, [.control, .option]))
        #expect(applied == [Shortcut(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(controlKey | optionKey))])
        #expect(recorder.isRecording == false)
        #expect(recorder.message == nil)
    }

    @Test func reportsRefusedShortcut() throws {
        let recorder = ShortcutRecorder()
        recorder.apply = { _ in false }
        recorder.start()
        recorder.record(try keyPress(kVK_ANSI_J, [.command]))
        #expect(recorder.isRecording == false)
        #expect(recorder.message == ShortcutRecorder.refused)

        recorder.use(.standard)
        #expect(recorder.message == ShortcutRecorder.refused)
    }

    @Test func escapeCancelsAndBringsOldHotKeyBack() throws {
        let recorder = ShortcutRecorder()
        var resumed = false
        var applied = false
        recorder.resume = { resumed = true }
        recorder.apply = { _ in applied = true; return true }

        recorder.start()
        recorder.record(try keyPress(kVK_Escape, []))
        #expect(recorder.isRecording == false)
        #expect(resumed)
        #expect(applied == false)
    }

    // MARK: Themes

    @Test func everyThemeShowsPressedKeys() {
        let fingers: [Finger] = [.pinky, .ring, .middle, .index, .indexInner, .thumb, .neutral]
        for theme in Theme.allCases {
            for dark in [false, true] {
                let palette = theme.palette(dark: dark)
                for finger in fingers {
                    let up = theme.look(finger, pressed: false, in: palette)
                    let down = theme.look(finger, pressed: true, in: palette)
                    #expect(up.fill != down.fill, "\(theme) \(finger) dark: \(dark)")
                }
            }
        }
    }

    @Test func isoReturnIsAnL() throws {
        let key = try #require(Keyboard.iso.first { $0.code == UInt16(kVK_Return) })
        let parts = key.parts.map { $0.insetBy(dx: 0.05, dy: 0.05) }
        let shape = KeyboardView.shape(of: parts, radius: 0.16)
        #expect(shape.contains(CGPoint(x: 14.0, y: 2.5))) // top part
        #expect(shape.contains(CGPoint(x: 14.1, y: 3.5))) // bottom part
        #expect(shape.contains(CGPoint(x: 14.1, y: 3.0))) // joined, no gap between parts
        #expect(shape.contains(CGPoint(x: 13.6, y: 3.5)) == false) // the notch under the top part
    }
}
