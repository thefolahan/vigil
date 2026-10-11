import AppKit
import SwiftUI

@main
struct VigilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(delegate.model)
        } label: {
            MenuBarLabel().environmentObject(delegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(delegate.model)
        }
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let count = model.heldBy.count
        HStack(spacing: 2) {
            Image(nsImage: Candle.menuBarImage(lit: model.isAwake, lidHeld: model.lidHeldOpen))
            if count > 0 { Text("\(count)").monospacedDigit() }
        }
        .accessibilityLabel(model.isAwake ? "Vigil, keeping the Mac awake" : "Vigil, the Mac can sleep")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // `-VigilPreviewWindow YES` shows the panel in a normal window, which
        // is how the screenshots in the README are taken.
        if let style = UserDefaults.standard.string(forKey: "VigilAppearance") {
            NSApp.appearance = NSAppearance(named: style == "dark" ? .darkAqua : .aqua)
        }
        if UserDefaults.standard.bool(forKey: "VigilPreviewWindow") {
            let window = PreviewWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isMovableByWindowBackground = true
            window.hasShadow = true
            let hosting = NSHostingView(rootView: PanelView().environmentObject(model))
            let size = hosting.fittingSize
            if #available(macOS 26.0, *) {
                // The same glass the menu bar panel sits on.
                let glass = NSGlassEffectView()
                glass.cornerRadius = 16
                glass.contentView = hosting
                window.isOpaque = false
                window.backgroundColor = .clear
                window.contentView = glass
            } else {
                let effect = NSVisualEffectView()
                effect.material = .popover
                effect.state = .active
                hosting.translatesAutoresizingMaskIntoConstraints = false
                effect.addSubview(hosting)
                NSLayoutConstraint.activate([
                    hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                    hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                    hosting.topAnchor.constraint(equalTo: effect.topAnchor),
                    hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
                ])
                window.contentView = effect
            }
            window.setContentSize(size)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            previewWindow = window
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutDown()
    }
}

/// A borderless window that can still be key, so controls draw as active.
final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
