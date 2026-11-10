import Foundation
import CoreGraphics
import AppKit

// Apple standard definitions from ev_keymap.h:
private let NX_SYSDEFINED: UInt32 = 14
private let NX_KEYTYPE_BRIGHTNESS_UP: Int32 = 2
private let NX_KEYTYPE_BRIGHTNESS_DOWN: Int32 = 3

// MARK: - Mouse Chord State Tracking (Session-safe)
private var isLeftMouseDown = false
private var isRightMouseDown = false
private var chordTriggered = false
private var leftDownTime: TimeInterval = 0
private var rightDownTime: TimeInterval = 0

// Fast lock-free flags for eventTapCallback
public var gIsMouseChordEnabled: Bool = true
public var gIsClipboardEnabled: Bool = true
public var gIsClipboardHUDVisible: Bool = false
public var gIsClipboardSearchEmpty: Bool = true
public var gClipboardShortcutKeycode: Int64 = 8
public var gIsCursorBasedBrightnessEnabled: Bool = true
public var gIsScreenshotEnabled: Bool = true
public var gIsScreenshotActive: Bool = false
public var gIsStudioEditorOpen: Bool = false
public var gIsStudioEditingText: Bool = false
public var gIsSpacePressed: Bool = false
private var gCurrentTap: CFMachPort? = nil

/// Maps macOS virtual keycodes for 1...9 to their 0-based clipboard row index.
private func clipboardQuickPasteIndex(for keyCode: Int64) -> Int? {
    switch keyCode {
    case 18: return 0 // 1
    case 19: return 1 // 2
    case 20: return 2 // 3
    case 21: return 3 // 4
    case 23: return 4 // 5
    case 22: return 5 // 6
    case 26: return 6 // 7
    case 28: return 7 // 8
    case 25: return 8 // 9
    default: return nil
    }
}

private func triggerMissionControl() {
    DispatchQueue.main.async {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if error != nil {
                // Fallback: Post Control + Up Arrow via session tap
                let src = CGEventSource(stateID: .combinedSessionState)
                if let down = CGEvent(keyboardEventSource: src, virtualKey: 126, keyDown: true) {
                    down.flags = .maskControl
                    down.post(tap: .cgSessionEventTap)
                }
                if let up = CGEvent(keyboardEventSource: src, virtualKey: 126, keyDown: false) {
                    up.flags = .maskControl
                    up.post(tap: .cgSessionEventTap)
                }
            }
        }
    }
}

// MARK: - Event Tap Callback (Session level, zero main-sync)
//
// The tap only borrows `event` from WindowServer — always hand it back with
// passUnretained. passRetained adds an extra retain that is never balanced, so
// every key/mouse event (plus its HIDEvent) leaks and memory grows forever.

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // 0. Synthetic event bypass: allow HyperMac-synthesized events (e.g. Cmd+C, Opt+Cmd+V) to pass through without interception
    if gIsSynthesizingEvent {
        return Unmanaged.passUnretained(event)
    }

    // 1. Safety handler for system tap disable
    if type == .tapDisabledByUserInput {
        // User revoked permission in System Settings -> STOP cleanly! Do NOT fight WindowServer!
        appLog("⚠️ EventTap was disabled by user/system in Accessibility settings. Stopping.")
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                KeyInterceptor.shared.stop()
            }
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout {
        // Timeout from macOS -> Re-enable safely
        if let tap = gCurrentTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    // 1b. Shortcut Recorder Interception (when user is recording a custom shortcut in UI)
    if gIsRecordingShortcut && type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if !ShortcutCombo.isPureModifierKey(keyCode) {
            DispatchQueue.main.async {
                ShortcutManager.shared.handleRecordedKey(keyCode: keyCode, flags: flags)
            }
            return nil
        }
    }

    // 2. Mouse Chording: Simultaneous Left + Right Click -> F3 (Mission Control)
    if gIsMouseChordEnabled {
        let now = Date().timeIntervalSince1970
        let chordWindow: TimeInterval = 0.5

        switch type {
        case .leftMouseDown:
            isLeftMouseDown = true
            leftDownTime = now
            if isRightMouseDown && (now - rightDownTime <= chordWindow) {
                chordTriggered = true
                triggerMissionControl()
                return nil // Swallow left click
            }

        case .rightMouseDown:
            isRightMouseDown = true
            rightDownTime = now
            if isLeftMouseDown && (now - leftDownTime <= chordWindow) {
                chordTriggered = true
                triggerMissionControl()
                return nil // Swallow right click
            }

        case .leftMouseUp:
            isLeftMouseDown = false
            if chordTriggered {
                if !isRightMouseDown { chordTriggered = false }
                return nil
            }

        case .rightMouseUp:
            isRightMouseDown = false
            if chordTriggered {
                if !isLeftMouseDown { chordTriggered = false }
                return nil
            }

        default:
            break
        }
    }

    // 3. Media Keys (Brightness UP/DOWN F1/F2)
    if type.rawValue == NX_SYSDEFINED {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.subtype.rawValue == 8 {
            let data1 = nsEvent.data1
            let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
            let keyFlags = (data1 & 0x0000FFFF)
            let keyState = (((keyFlags & 0xFF00) >> 8)) == 0x0A

            if keyState && (keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN) {
                // If cursor-based brightness is disabled, do NOT intercept! Pass through to macOS native.
                if !gIsCursorBasedBrightnessEnabled {
                    return Unmanaged.passUnretained(event)
                }
                let isUp = (keyCode == NX_KEYTYPE_BRIGHTNESS_UP)
                DispatchQueue.main.async {
                    _ = DisplayManager.shared.handleBrightnessKey(isUp: isUp)
                }
                // Return nil if external monitor was targeted or pass to macOS
                return nil
            }
        }
    }

    // 5. Spacebar tracking for Screenshot Mode (Holding Space to Move Selection)
    if type == .keyDown || type == .keyUp {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        if keycode == 49 { // Space
            let isDown = (type == .keyDown)
            if gIsSpacePressed != isDown {
                gIsSpacePressed = isDown
                DispatchQueue.main.async {
                    ScreenshotManager.shared.isSpaceHeld = isDown
                }
            }
            if gIsScreenshotActive {
                return nil // Swallow Space in screenshot mode
            }
        }
    }

    // 6. Standard F1/F2 KeyDowns & Window Snapping
    if type == .keyDown {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Screenshot Active Hotkeys (LightShot Mode: Esc to cancel, ⌘C to copy, ⌘V/⌘S to save, ⌘Z to undo)
        if gIsScreenshotActive {
            let hasCmd = flags.contains(.maskCommand)
            let hasCtrl = flags.contains(.maskControl)
            let hasAlt = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)

            // Esc (keycode 53) -> Cancel capture
            if keycode == 53 && !hasCmd && !hasCtrl && !hasAlt && !hasShift {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.cancelCapture()
                }
                return nil
            }

            // ⌘C (keycode 8) -> Copy high-res cropped screenshot to clipboard
            if hasCmd && !hasCtrl && !hasAlt && !hasShift && keycode == 8 {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.copyToClipboard()
                }
                return nil
            }

            // ⌘V (keycode 9) -> Save high-res screenshot to Downloads/Screenshots
            if hasCmd && !hasCtrl && !hasAlt && !hasShift && keycode == 9 {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.saveToDownloads()
                }
                return nil
            }

            // ⌘S (keycode 1) -> Save high-res screenshot to Downloads/Screenshots
            if hasCmd && !hasCtrl && !hasAlt && !hasShift && keycode == 1 {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.saveToDownloads()
                }
                return nil
            }

            // Enter / Return (keycode 36 or 76) or ⌘E (keycode 14) -> Open Snapzy Studio Editor (or Quick Copy if in QuickCopyMode)
            if (!hasCmd && !hasCtrl && !hasAlt && !hasShift && (keycode == 36 || keycode == 76))
                || (hasCmd && !hasCtrl && !hasAlt && !hasShift && keycode == 14) {
                DispatchQueue.main.async {
                    if ScreenshotManager.shared.isQuickCopyMode && keycode != 14 {
                        if ScreenshotManager.shared.hasSelection {
                            ScreenshotManager.shared.copyToClipboard()
                        } else {
                            ScreenshotManager.shared.captureFullScreenToClipboard()
                        }
                    } else {
                        ScreenshotManager.shared.openStudioEditor()
                    }
                }
                return nil
            }

            // ⌘Z (keycode 6) -> Undo last stroke, ⌘⇧Z -> Redo
            if hasCmd && !hasCtrl && !hasAlt && keycode == 6 {
                DispatchQueue.main.async {
                    if hasShift {
                        ScreenshotManager.shared.redoLastStroke()
                    } else {
                        ScreenshotManager.shared.undoLastStroke()
                    }
                }
                return nil
            }

            // Tab (keycode 48) -> Switch to next screen if multiple displays connected
            if !hasCmd && !hasCtrl && !hasAlt && !hasShift && keycode == 48 {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.switchScreen()
                }
                return nil
            }

            // In screenshot mode, swallow all other bare typing to prevent accidental shortcuts
            return nil
        }

        // Screenshot Studio Editor Active Hotkeys (⌘C to Copy & Close, ⌘S to Save, ⌘Z to Undo, ↵, ⎋)
        if gIsStudioEditorOpen && !gIsStudioEditingText {
            let hasCmd = flags.contains(.maskCommand)
            let hasCtrl = flags.contains(.maskControl)
            let hasAlt = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)

            let isStudioHotkey =
                (hasCmd && !hasCtrl && !hasAlt && !hasShift && (keycode == 8 || keycode == 1 || keycode == 13)) ||
                (hasCmd && !hasCtrl && !hasAlt && hasShift && keycode == 1) ||
                (hasCmd && !hasCtrl && !hasAlt && keycode == 6) ||
                (!hasCmd && !hasCtrl && !hasAlt && !hasShift && (keycode == 36 || keycode == 76 || keycode == 53 || keycode == 51 || keycode == 117))

            if isStudioHotkey {
                DispatchQueue.main.async {
                    _ = ScreenshotManager.shared.handleStudioKeyCommand(keyCode: keycode, flags: flags)
                }
                return nil
            }
        }

        // Screenshot Trigger (Customizable + bare F4 fallback)
        if gIsScreenshotEnabled && !gIsScreenshotActive {
            let hasCmd = flags.contains(.maskCommand)
            let hasCtrl = flags.contains(.maskControl)
            let hasAlt = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)

            let captureCombo = gShortcutSnapshot[.screenshotCapture] ?? ShortcutAction.screenshotCapture.defaultCombo
            if captureCombo.matches(keyCode: keycode, flags: flags) {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.startCapture(quickCopy: false)
                }
                return nil
            }

            let quickCopyCombo = gShortcutSnapshot[.screenshotQuickCopy] ?? ShortcutAction.screenshotQuickCopy.defaultCombo
            if quickCopyCombo.matches(keyCode: keycode, flags: flags) {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.startCapture(quickCopy: true)
                }
                return nil
            }

            let fullScreenCombo = gShortcutSnapshot[.screenshotFullScreen] ?? ShortcutAction.screenshotFullScreen.defaultCombo
            if fullScreenCombo.matches(keyCode: keycode, flags: flags) {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.captureFullScreenToStudio()
                }
                return nil
            }

            let activeWindowCombo = gShortcutSnapshot[.screenshotActiveWindow] ?? ShortcutAction.screenshotActiveWindow.defaultCombo
            if activeWindowCombo.matches(keyCode: keycode, flags: flags) {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.captureActiveWindowToStudio()
                }
                return nil
            }

            // Secondary: bare F4
            if !hasCmd && !hasShift && !hasCtrl && !hasAlt && (keycode == 118 || keycode == 131) && captureCombo.isEnabled {
                DispatchQueue.main.async {
                    ScreenshotManager.shared.startCapture()
                }
                return nil
            }
        }

        // Toggle Caffeinate (Keep Screen Awake) Shortcut
        let caffeinateCombo = gShortcutSnapshot[.toggleCaffeinate] ?? ShortcutAction.toggleCaffeinate.defaultCombo
        if caffeinateCombo.matches(keyCode: keycode, flags: flags) {
            DispatchQueue.main.async {
                CaffeinateManager.shared.toggle()
            }
            return nil
        }

        // Toggle Menu Bar Drawer Shortcut
        let drawerCombo = gShortcutSnapshot[.menuBarDrawer] ?? ShortcutAction.menuBarDrawer.defaultCombo
        if gIsMenuBarHiderEnabled && drawerCombo.matches(keyCode: keycode, flags: flags) {
            DispatchQueue.main.async {
                MenuBarHiderManager.shared.toggle()
            }
            return nil
        }

        // F1/F2 Brightness
        if keycode == 145 || keycode == 120 || keycode == 144 || keycode == 122 {
            // If cursor-based brightness is disabled, do NOT intercept! Pass through to macOS native.
            if !gIsCursorBasedBrightnessEnabled {
                return Unmanaged.passUnretained(event)
            }
            let isUp = (keycode == 145 || keycode == 120)
            DispatchQueue.main.async {
                _ = DisplayManager.shared.handleBrightnessKey(isUp: isUp)
            }
            return nil
        }

        // Finder Cut & Paste (Windows-style ⌘X ➔ ⌘V)
        if gIsFinderCutPasteEnabled {
            let hasCmd = flags.contains(.maskCommand)
            let hasCtrl = flags.contains(.maskControl)
            let hasAlt = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)

            // Esc (keycode 53) -> Cancel pending cut in Finder
            if keycode == 53 && gIsFinderCutActive && !hasCmd && !hasCtrl && !hasAlt {
                if FinderCutPasteManager.isFinderFrontmost() {
                    DispatchQueue.main.async {
                        FinderCutPasteManager.shared.cancelCut(quiet: false)
                    }
                    return nil
                }
            }

            let finderCutCombo = gShortcutSnapshot[.finderCut] ?? ShortcutAction.finderCut.defaultCombo
            if finderCutCombo.matches(keyCode: keycode, flags: flags) {
                if FinderCutPasteManager.isFinderFrontmost() && !FinderCutPasteManager.isFinderEditingText() {
                    DispatchQueue.main.async {
                        FinderCutPasteManager.shared.triggerCut()
                    }
                    return nil
                }
            }

            // Command-only shortcuts (no Option, no Control, no Shift)
            if hasCmd && !hasCtrl && !hasAlt && !hasShift {
                // ⌘V (keycode 9) -> Paste/Move cut file(s) in Finder
                if keycode == 9 && gIsFinderCutActive {
                    if FinderCutPasteManager.isFinderFrontmost() {
                        if !FinderCutPasteManager.isFinderEditingText() {
                            DispatchQueue.main.async {
                                FinderCutPasteManager.shared.triggerPaste()
                            }
                            return nil // Swallow ⌘V
                        }
                    }
                }

                // ⌘C (keycode 8) -> Manual copy cancels any cut state
                if keycode == 8 && gIsFinderCutActive {
                    DispatchQueue.main.async {
                        FinderCutPasteManager.shared.cancelCut(quiet: true)
                    }
                }
            }
        }

        // Toggle Clipboard Manager HUD (Customizable, default ⌘⇧C)
        let clipCombo = gShortcutSnapshot[.clipboardHUD] ?? ShortcutAction.clipboardHUD.defaultCombo
        if gIsClipboardEnabled && clipCombo.matches(keyCode: keycode, flags: flags) {
            DispatchQueue.main.async {
                ClipboardManager.shared.toggleHUD()
            }
            return nil
        }

        // Clipboard HUD Active Keys
        if gIsClipboardHUDVisible {
            let hasCommand = flags.contains(.maskCommand)
            let hasControl = flags.contains(.maskControl)
            let hasOption = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)

            // Command + Up/Down (⌘↑ / ⌘↓) -> Reorder selected pinned item
            if hasCommand && !hasControl && !hasOption && !hasShift {
                if keycode == 126 { // Up Arrow (⌘↑)
                    DispatchQueue.main.async {
                        ClipboardManager.shared.moveSelectedPinned(direction: .up)
                    }
                    return nil
                } else if keycode == 125 { // Down Arrow (⌘↓)
                    DispatchQueue.main.async {
                        ClipboardManager.shared.moveSelectedPinned(direction: .down)
                    }
                    return nil
                }
            }

            // Let system-level shortcuts (⌘C, ⌘V, ⌘A...) pass through untouched.
            if !hasCommand && !hasControl {
                if keycode == 53 { // Esc -> Close HUD
                    gIsClipboardHUDVisible = false
                    DispatchQueue.main.async {
                        ClipboardManager.shared.hideHUD()
                    }
                    return nil
                } else if keycode == 126 { // Up Arrow -> previous clip
                    DispatchQueue.main.async {
                        ClipboardManager.shared.selectPrevious()
                    }
                    return nil
                } else if keycode == 125 { // Down Arrow -> next clip
                    DispatchQueue.main.async {
                        ClipboardManager.shared.selectNext()
                    }
                    return nil
                } else if keycode == 36 || keycode == 76 { // Return / Numpad Enter -> paste selection
                    DispatchQueue.main.async {
                        ClipboardManager.shared.pasteSelectedItem()
                    }
                    return nil
                } else if hasOption && keycode == 35 { // ⌥P -> pin / unpin selection
                    DispatchQueue.main.async {
                        ClipboardManager.shared.togglePinSelected()
                    }
                    return nil
                } else if hasOption && (keycode == 51 || keycode == 117) { // ⌥⌫ -> delete selection
                    DispatchQueue.main.async {
                        ClipboardManager.shared.deleteSelectedItem()
                    }
                    return nil
                }
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - KeyInterceptor Singleton

@MainActor
public class KeyInterceptor {
    public static let shared = KeyInterceptor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public var currentTap: CFMachPort? {
        return eventTap
    }

    private init() {}

    public func updateSettings() {
        _ = ShortcutManager.shared
        gIsMouseChordEnabled = (UserDefaults.standard.object(forKey: "mouse_chord_enabled") as? Bool) ?? true
        gIsClipboardEnabled = (UserDefaults.standard.object(forKey: "clipboard_monitoring_enabled") as? Bool) ?? true
        gIsFinderCutPasteEnabled = (UserDefaults.standard.object(forKey: "finder_cut_paste_enabled") as? Bool) ?? true
        let shortcut = UserDefaults.standard.string(forKey: "clipboard_hud_shortcut") ?? "cmd_shift_c"
        gClipboardShortcutKeycode = (shortcut == "cmd_shift_v") ? 9 : 8
        gIsCursorBasedBrightnessEnabled = (UserDefaults.standard.object(forKey: "cursor_based_brightness") as? Bool) ?? true
        gIsScreenshotEnabled = (UserDefaults.standard.object(forKey: "screenshot_enabled") as? Bool) ?? true
    }

    public func start() {
        guard eventTap == nil else { return }

        updateSettings()

        // Listen for Media Keys, KeyDowns, KeyUps, FlagsChanged, and Mouse Left/Right
        let mask: UInt64 = (1 << NX_SYSDEFINED) |
                           (1 << CGEventType.keyDown.rawValue) |
                           (1 << CGEventType.keyUp.rawValue) |
                           (1 << CGEventType.flagsChanged.rawValue) |
                           (1 << CGEventType.leftMouseDown.rawValue) |
                           (1 << CGEventType.leftMouseUp.rawValue) |
                           (1 << CGEventType.rightMouseDown.rawValue) |
                           (1 << CGEventType.rightMouseUp.rawValue)

        // EXCLUSIVELY use .cgSessionEventTap for user-session safety!
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback,
            userInfo: nil
        )

        guard let validTap = tap else {
            let trusted = AXIsProcessTrusted()
            appLog("⚠️ KeyInterceptor: Could not create session CGEventTap. AXIsProcessTrusted=\(trusted). Retrying in 1.5s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.start()
            }
            return
        }

        self.eventTap = validTap
        gCurrentTap = validTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: validTap, enable: true)
        appLog("✅ KeyInterceptor: Active on Session level (Safe, no deadlocks).")
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
            gCurrentTap = nil
            appLog("⏹ KeyInterceptor stopped.")
        }
    }
}
