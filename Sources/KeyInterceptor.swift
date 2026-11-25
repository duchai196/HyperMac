import Foundation
import CoreGraphics
import AppKit

// Fast lock-free flags for eventTapCallback
public var gIsClipboardEnabled: Bool = true
public var gIsClipboardHUDVisible: Bool = false
public var gIsClipboardSearchEmpty: Bool = true
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

// MARK: - Event Tap Callback (Keyboard-only, minimal overhead, zero leaks)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByUserInput {
        appLog("⚠️ EventTap was disabled by user/system in Accessibility settings. Stopping.")
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                KeyInterceptor.shared.stop()
            }
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout {
        if let tap = gCurrentTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    // 1. Shortcut Recorder Interception
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

    // 2. Spacebar tracking while selecting screenshot region
    if gIsScreenshotActive && (type == .keyDown || type == .keyUp) {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        if keycode == 49 { // Space
            let isDown = (type == .keyDown)
            if gIsSpacePressed != isDown {
                gIsSpacePressed = isDown
                DispatchQueue.main.async {
                    ScreenshotManager.shared.isSpaceHeld = isDown
                }
            }
            return nil
        }
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // 3. Active Screenshot Region Overlay Keys (Esc cancel, Tab switch screen)
    if gIsScreenshotActive {
        let hasMod = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskShift)
        if !hasMod && keycode == 53 { // Esc
            DispatchQueue.main.async {
                ScreenshotManager.shared.cancelCapture()
            }
            return nil
        }
        if !hasMod && keycode == 48 { // Tab -> switch display
            DispatchQueue.main.async {
                ScreenshotManager.shared.switchScreen()
            }
            return nil
        }
        return nil
    }

    // 4. Studio Editor Hotkeys (⌘C copy & close, ⌘S save, ⌘⇧S save as, ⌘Z undo, ⌘W close, ↵ copy & close, ⎋ close)
    if gIsStudioEditorOpen && !gIsStudioEditingText {
        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasAlt = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        let isStudioHotkey =
            (hasCmd && !hasCtrl && !hasAlt && !hasShift && (keycode == 8 || keycode == 1 || keycode == 13)) ||
            (hasCmd && !hasCtrl && !hasAlt && hasShift && keycode == 1) ||
            (hasCmd && !hasCtrl && !hasAlt && keycode == 6) ||
            (!hasCmd && !hasCtrl && !hasAlt && !hasShift && (keycode == 36 || keycode == 76 || keycode == 53))

        if isStudioHotkey {
            DispatchQueue.main.async {
                _ = ScreenshotManager.shared.handleStudioKeyCommand(keyCode: keycode, flags: flags)
            }
            return nil
        }
    }

    // 5. Screenshot Region Capture Trigger
    if gIsScreenshotEnabled && !gIsScreenshotActive {
        let captureCombo = gShortcutSnapshot[.screenshotCapture] ?? ShortcutAction.screenshotCapture.defaultCombo
        if captureCombo.matches(keyCode: keycode, flags: flags) {
            DispatchQueue.main.async {
                ScreenshotManager.shared.startCapture()
            }
            return nil
        }
    }

    // 6. Toggle Keep Screen Awake Shortcut
    let caffeinateCombo = gShortcutSnapshot[.toggleCaffeinate] ?? ShortcutAction.toggleCaffeinate.defaultCombo
    if caffeinateCombo.matches(keyCode: keycode, flags: flags) {
        DispatchQueue.main.async {
            CaffeinateManager.shared.toggle()
        }
        return nil
    }

    // 7. Toggle Clipboard HUD Shortcut
    let clipCombo = gShortcutSnapshot[.clipboardHUD] ?? ShortcutAction.clipboardHUD.defaultCombo
    if gIsClipboardEnabled && clipCombo.matches(keyCode: keycode, flags: flags) {
        DispatchQueue.main.async {
            ClipboardManager.shared.toggleHUD()
        }
        return nil
    }

    // 8. Clipboard HUD Active Keys
    if gIsClipboardHUDVisible {
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        if hasCommand && !hasControl && !hasOption && !hasShift {
            if keycode == 126 {
                DispatchQueue.main.async { ClipboardManager.shared.moveSelectedPinned(direction: .up) }
                return nil
            } else if keycode == 125 {
                DispatchQueue.main.async { ClipboardManager.shared.moveSelectedPinned(direction: .down) }
                return nil
            }
        }

        if !hasCommand && !hasControl {
            if !hasOption && !hasShift && gIsClipboardSearchEmpty, let quickIdx = clipboardQuickPasteIndex(for: keycode) {
                DispatchQueue.main.async { ClipboardManager.shared.pasteItemAt(index: quickIdx) }
                return nil
            }
            if keycode == 53 { // Esc
                gIsClipboardHUDVisible = false
                DispatchQueue.main.async { ClipboardManager.shared.hideHUD() }
                return nil
            } else if keycode == 126 { // Up
                DispatchQueue.main.async { ClipboardManager.shared.selectPrevious() }
                return nil
            } else if keycode == 125 { // Down
                DispatchQueue.main.async { ClipboardManager.shared.selectNext() }
                return nil
            } else if keycode == 36 || keycode == 76 { // Return / Enter
                DispatchQueue.main.async { ClipboardManager.shared.pasteSelectedItem() }
                return nil
            } else if hasOption && keycode == 35 { // ⌥P
                DispatchQueue.main.async { ClipboardManager.shared.togglePinSelected() }
                return nil
            } else if hasOption && (keycode == 51 || keycode == 117) { // ⌥⌫
                DispatchQueue.main.async { ClipboardManager.shared.deleteSelectedItem() }
                return nil
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

    private init() {}

    public func updateSettings() {
        _ = ShortcutManager.shared
        gIsClipboardEnabled = (UserDefaults.standard.object(forKey: "clipboard_monitoring_enabled") as? Bool) ?? true
        gIsScreenshotEnabled = (UserDefaults.standard.object(forKey: "screenshot_enabled") as? Bool) ?? true
    }

    public func start() {
        guard eventTap == nil else { return }
        updateSettings()

        // Only listen for keyboard events (no mouse click or media key overhead)
        let mask: UInt64 = (1 << CGEventType.keyDown.rawValue) |
                           (1 << CGEventType.keyUp.rawValue)

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
            appLog("⚠️ KeyInterceptor: Could not create session CGEventTap. AXIsProcessTrusted=\(trusted). Retrying in 2s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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
        appLog("✅ KeyInterceptor: Active (keyboard-only lightweight mode).")
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
