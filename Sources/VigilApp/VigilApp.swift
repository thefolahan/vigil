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
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(rootView: PanelView().environmentObject(model).background(.regularMaterial))
            window.setContentSize(window.contentView!.fittingSize)
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
