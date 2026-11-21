import AppKit
import SwiftUI

/// Settings window with two tabs: General and Themes. Opens from the menu bar icon.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let recorder: ShortcutRecorder

    init(settings: AppSettings, recorder: ShortcutRecorder, state: KeyboardState) {
        self.recorder = recorder
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape",
                                     GeneralSettingsView(settings: settings, recorder: recorder)))
        tabs.addTabViewItem(Self.tab("Themes", symbol: "paintpalette",
                                     ThemeSettingsView(settings: settings, state: state)))
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("Not used")
    }

    private static func tab<Content: View>(_ label: String, symbol: String, _ view: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        controller.title = label
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }

    func show() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        recorder.cancel()
        // Give the focus back to the app the user worked in.
        DispatchQueue.main.async { NSApp.deactivate() }
    }
}

/// Settings → General: the hotkey.
struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var recorder: ShortcutRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Show or hide the keyboard:")
                Button {
                    if recorder.isRecording {
                        recorder.cancel()
                    } else {
                        recorder.start()
                    }
                } label: {
                    Text(recorder.isRecording ? "Type shortcut…" : settings.hotKey.displayString)
                        .frame(minWidth: 110)
                }
                Button("Reset") {
                    recorder.use(.standard)
                }
                .disabled(settings.hotKey == .standard || recorder.isRecording)
            }
            Text(hint)
                .font(.callout)
                .foregroundStyle(recorder.message == nil ? Color.secondary : Color.red)

            Divider()
                .padding(.vertical, 6)

            Toggle("Show input source in the menu bar", isOn: $settings.showInputSource)
            Text("The KeyView icon shows the current layout, like РУ or EN. Click it to switch layouts. "
                 + "The macOS indicator can then be turned off: System Settings → Keyboard → Text Input → "
                 + "Edit… → “Show Input menu in menu bar”.")
                .font(.callout)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 480, alignment: .leading)
    }

    private var hint: String {
        if let message = recorder.message { return message }
        if recorder.isRecording { return "Press the new shortcut. Esc cancels." }
        return "Works in any app. " + ShortcutRecorder.needsCommandOrControl
    }
}

/// Settings → Themes: how the keys look. Previews show the live keyboard.
struct ThemeSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var state: KeyboardState

    private let previewWidth: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Different shades for left and right index fingers", isOn: $settings.rightIndexShade)
            LazyVGrid(columns: [GridItem(.fixed(previewWidth), spacing: 16), GridItem(.fixed(previewWidth))],
                      spacing: 16) {
                ForEach(Theme.allCases) { theme in
                    card(theme)
                }
            }
        }
        .padding(20)
    }

    private func card(_ theme: Theme) -> some View {
        let selected = settings.theme == theme
        let aspect = KeyboardView.aspect
        return Button {
            settings.theme = theme
        } label: {
            VStack(spacing: 6) {
                KeyboardView(state: state, theme: theme, rightIndexShade: settings.rightIndexShade)
                    .frame(width: previewWidth, height: previewWidth * aspect.height / aspect.width)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3),
                                          lineWidth: selected ? 3 : 1)
                    )
                Text(theme.title)
                    .fontWeight(selected ? .semibold : .regular)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
