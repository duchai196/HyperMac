import SwiftUI
import AppKit

// MARK: - Lightweight App Delegate (Releases Popover View Tree When Closed)

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 356, height: 455)
        pop.behavior = .transient
        pop.delegate = self
        self.popover = pop

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.circle.fill", accessibilityDescription: "HyperMac")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Auto-recover TCC entries if signing identity changed
        AccessibilityRecovery.handleLaunch()

        // Initialize only the 3 core features + shortcuts + permissions
        _ = ShortcutManager.shared
        _ = ClipboardManager.shared
        _ = ScreenshotManager.shared
        _ = CaffeinateManager.shared
        _ = PermissionsManager.shared

        // Start lightweight keyboard-only event tap
        KeyInterceptor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CaffeinateManager.shared.disable()
        KeyInterceptor.shared.stop()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Instantiate MainView on demand so closed popover holds 0 MB
            let host = NSHostingController(
                rootView: MainView(onClosePopover: { [weak self] in
                    self?.popover.performClose(nil)
                })
                .background(Color(nsColor: .windowBackgroundColor))
            )
            popover.contentViewController = host
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            }
        }
    }

    func popoverDidShow(_ notification: Notification) {
        PermissionsManager.shared.setPopoverVisible(true)
        LaunchAtLoginManager.shared.checkSystemStatus()
    }

    func popoverDidClose(_ notification: Notification) {
        ShortcutManager.shared.cancelRecording()
        PermissionsManager.shared.setPopoverVisible(false)
        // Release SwiftUI hosting tree & window backing store immediately
        popover.contentViewController = nil
    }
}

// MARK: - App Main

@main
@MainActor
enum HyperMacMain {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
