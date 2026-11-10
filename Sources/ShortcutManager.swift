import Foundation
import AppKit
import CoreGraphics
import Combine
import SwiftUI

// MARK: - Shortcut Category & Action Definitions

public enum ShortcutCategory: String, CaseIterable, Sendable {
    case all = "all"
    case captureAndClipboard = "capture_clipboard"
    case systemUtilities = "system_utilities"

    public var title: String {
        switch self {
        case .all:                 return tr("Tất cả", "All")
        case .captureAndClipboard: return tr("Chụp ảnh & Clipboard", "Capture & Clipboard")
        case .systemUtilities:     return tr("Tiện ích Hệ thống", "System Utilities")
        }
    }

    public var shortTitle: String {
        switch self {
        case .all:                 return tr("Tất cả", "All")
        case .captureAndClipboard: return tr("Chụp & Clip", "Capture")
        case .systemUtilities:     return tr("Hệ thống", "System")
        }
    }

    public var icon: String {
        switch self {
        case .all:                 return "keyboard"
        case .captureAndClipboard: return "camera.viewfinder"
        case .systemUtilities:     return "sparkles.rectangle.stack"
        }
    }
}

public enum ShortcutAction: String, CaseIterable, Identifiable, Codable, Sendable {
    // 1. Capture & Clipboard
    case screenshotCapture     = "screenshot_capture"
    case screenshotFullScreen  = "screenshot_fullscreen"
    case clipboardHUD          = "clipboard_hud"

    // 2. System Utilities
    case menuBarDrawer         = "menubar_drawer"
    case toggleCaffeinate      = "toggle_caffeinate"
    case finderCut             = "finder_cut"

    public var id: String { rawValue }

    public var category: ShortcutCategory {
        switch self {
        case .screenshotCapture, .screenshotFullScreen, .clipboardHUD:
            return .captureAndClipboard
        case .menuBarDrawer, .toggleCaffeinate, .finderCut:
            return .systemUtilities
        }
    }

    public var title: String {
        switch self {
        case .screenshotCapture:    return tr("Chụp vùng màn hình", "Capture Screen Region")
        case .screenshotFullScreen: return tr("Chụp toàn màn hình vào Studio", "Full Screen to Studio")
        case .clipboardHUD:         return tr("Mở Lịch sử Clipboard HUD", "Open Clipboard HUD")
        case .menuBarDrawer:        return tr("Đóng / Mở Ngăn kéo Menu Bar", "Toggle Menu Bar Drawer")
        case .toggleCaffeinate:     return tr("Bật / Tắt Chống sleep màn hình", "Toggle Keep Awake")
        case .finderCut:            return tr("Cắt tệp trong Finder (kèm ⌘V dán)", "Cut File in Finder")
        }
    }

    public var icon: String {
        switch self {
        case .screenshotCapture:    return "viewfinder"
        case .screenshotFullScreen: return "macwindow.badge.plus"
        case .clipboardHUD:         return "doc.on.clipboard.fill"
        case .menuBarDrawer:        return "menubar.rectangle"
        case .toggleCaffeinate:     return "cup.and.saucer.fill"
        case .finderCut:            return "scissors"
        }
    }

    public var defaultCombo: ShortcutCombo {
        let cmd = CGEventFlags.maskCommand.rawValue
        let shift = CGEventFlags.maskShift.rawValue
        let opt = CGEventFlags.maskAlternate.rawValue
        let ctrl = CGEventFlags.maskControl.rawValue

        switch self {
        case .screenshotCapture:
            return ShortcutCombo(keyCode: 18, modifiers: cmd | shift)        // ⌘⇧1
        case .screenshotFullScreen:
            return ShortcutCombo(keyCode: 19, modifiers: cmd | shift)        // ⌘⇧2
        case .clipboardHUD:
            return ShortcutCombo(keyCode: 8, modifiers: cmd | shift)         // ⌘⇧C
        case .menuBarDrawer:
            return ShortcutCombo(keyCode: 11, modifiers: opt | cmd)          // ⌥⌘B
        case .toggleCaffeinate:
            return ShortcutCombo(keyCode: 1, modifiers: ctrl | opt | cmd)    // ⌃⌥⌘S
        case .finderCut:
            return ShortcutCombo(keyCode: 7, modifiers: cmd)                 // ⌘X
        }
    }
}

// MARK: - Shortcut Combo Model

public struct ShortcutCombo: Codable, Equatable, Sendable {
    public var keyCode: Int64
    public var modifiers: UInt64
    public var isEnabled: Bool

    public static let relevantModifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskControl.rawValue

    public init(keyCode: Int64, modifiers: UInt64, isEnabled: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.relevantModifierMask
        self.isEnabled = isEnabled
    }

    public func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isEnabled else { return false }
        let normalized = flags.rawValue & Self.relevantModifierMask
        return self.keyCode == keyCode && self.modifiers == normalized
    }

    /// Matches even when Shift is additionally held (used for AltTab forward/backward cycling).
    public func matchesAllowingShift(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isEnabled else { return false }
        let maskWithoutShift = Self.relevantModifierMask & ~CGEventFlags.maskShift.rawValue
        let normalized = flags.rawValue & maskWithoutShift
        let target = self.modifiers & maskWithoutShift
        return self.keyCode == keyCode && target == normalized
    }

    public var primaryModifierFlag: CGEventFlags {
        if (modifiers & CGEventFlags.maskCommand.rawValue) != 0 {
            return .maskCommand
        } else if (modifiers & CGEventFlags.maskAlternate.rawValue) != 0 {
            return .maskAlternate
        } else if (modifiers & CGEventFlags.maskControl.rawValue) != 0 {
            return .maskControl
        }
        return .maskCommand
    }

    public var displayString: String {
        var parts = ""
        if (modifiers & CGEventFlags.maskControl.rawValue) != 0 { parts += "⌃" }
        if (modifiers & CGEventFlags.maskAlternate.rawValue) != 0 { parts += "⌥" }
        if (modifiers & CGEventFlags.maskShift.rawValue) != 0 { parts += "⇧" }
        if (modifiers & CGEventFlags.maskCommand.rawValue) != 0 { parts += "⌘" }
        parts += Self.keyLabel(for: keyCode)
        return parts
    }

    public var spacedDisplayString: String {
        var tokens: [String] = []
        if (modifiers & CGEventFlags.maskControl.rawValue) != 0 { tokens.append("⌃") }
        if (modifiers & CGEventFlags.maskAlternate.rawValue) != 0 { tokens.append("⌥") }
        if (modifiers & CGEventFlags.maskShift.rawValue) != 0 { tokens.append("⇧") }
        if (modifiers & CGEventFlags.maskCommand.rawValue) != 0 { tokens.append("⌘") }
        tokens.append(Self.keyLabel(for: keyCode))
        return tokens.joined(separator: " ")
    }

    public static func isPureModifierKey(_ keyCode: Int64) -> Bool {
        switch keyCode {
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63:
            return true
        default:
            return false
        }
    }

    public static func isFunctionKey(_ keyCode: Int64) -> Bool {
        switch keyCode {
        case 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90, 131:
            return true
        default:
            return false
        }
    }

    public static func keyLabel(for keyCode: Int64) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 76: return "⌤"
        case 82: return "Num0"
        case 83: return "Num1"
        case 84: return "Num2"
        case 85: return "Num3"
        case 86: return "Num4"
        case 87: return "Num5"
        case 88: return "Num6"
        case 89: return "Num7"
        case 91: return "Num8"
        case 92: return "Num9"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 115: return "↖"
        case 116: return "⇞"
        case 117: return "⌦"
        case 118, 131: return "F4"
        case 119: return "↘"
        case 120: return "F2"
        case 121: return "⇟"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key\(keyCode)"
        }
    }
}

// MARK: - Lock-Free Global Snapshot for CGEventTap Callback

public var gIsRecordingShortcut: Bool = false
public var gShortcutSnapshot: [ShortcutAction: ShortcutCombo] = {
    var dict: [ShortcutAction: ShortcutCombo] = [:]
    for action in ShortcutAction.allCases {
        dict[action] = action.defaultCombo
    }
    return dict
}()

// MARK: - Centralized Shortcut Manager

@MainActor
public class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()

    private let storageKey = "hypermac_custom_shortcuts_v1"

    @Published public var bindings: [ShortcutAction: ShortcutCombo] = [:]
    @Published public var recordingAction: ShortcutAction? = nil {
        didSet {
            gIsRecordingShortcut = (recordingAction != nil)
            updateLocalMonitor()
        }
    }
    @Published public var selectedCategory: ShortcutCategory = .all
    @Published public var selectedSubTab: Int = 0 // 0 = Tất cả phím tắt (1 màn hình), 1 = Cài đặt tính năng
    @Published public var searchQuery: String = ""
    @Published public var statusMessage: String? = nil

    private var statusMessageToken: Int = 0
    private var localKeyMonitor: Any? = nil
    private var standaloneWindow: NSWindow? = nil

    private init() {
        loadBindings()
    }

    public func combo(for action: ShortcutAction) -> ShortcutCombo {
        return bindings[action] ?? action.defaultCombo
    }

    public func isCustomized(_ action: ShortcutAction) -> Bool {
        guard let current = bindings[action] else { return false }
        let def = action.defaultCombo
        return current.keyCode != def.keyCode || current.modifiers != def.modifiers
    }

    public var customizedCount: Int {
        ShortcutAction.allCases.filter { isCustomized($0) }.count
    }

    public func startRecording(_ action: ShortcutAction) {
        if recordingAction == action {
            cancelRecording()
        } else {
            recordingAction = action
        }
    }

    public func cancelRecording() {
        recordingAction = nil
    }

    public func toggleActionEnabled(_ action: ShortcutAction) {
        var current = combo(for: action)
        current.isEnabled.toggle()
        bindings[action] = current
        saveAndSync()
    }

    public func setActionEnabled(_ action: ShortcutAction, _ enabled: Bool) {
        var current = combo(for: action)
        current.isEnabled = enabled
        bindings[action] = current
        saveAndSync()
    }

    public func resetAction(_ action: ShortcutAction) {
        bindings[action] = action.defaultCombo
        if recordingAction == action {
            recordingAction = nil
        }
        saveAndSync()
        showStatus(tr("Đã đặt lại \(action.title) về \(action.defaultCombo.displayString)",
                      "Reset \(action.title) to \(action.defaultCombo.displayString)"))
    }

    public func resetAllToDefaults() {
        recordingAction = nil
        var fresh: [ShortcutAction: ShortcutCombo] = [:]
        for action in ShortcutAction.allCases {
            fresh[action] = action.defaultCombo
        }
        bindings = fresh
        saveAndSync()
        showStatus(tr("Đã khôi phục toàn bộ phím tắt về mặc định",
                      "Restored all shortcuts to default"))
    }

    /// Xử lý phím người dùng vừa nhấn khi đang ở chế độ ghi phím tắt.
    public func handleRecordedKey(keyCode: Int64, flags: CGEventFlags) {
        guard let targetAction = recordingAction else { return }

        // Bỏ qua nếu chỉ mới nhấn phím bổ trợ (⌘, ⌥, ⌃, ⇧)
        if ShortcutCombo.isPureModifierKey(keyCode) {
            return
        }

        let cleanMods = flags.rawValue & ShortcutCombo.relevantModifierMask

        // Esc không kèm modifier -> Huỷ ghi phím
        if keyCode == 53 && cleanMods == 0 {
            cancelRecording()
            return
        }

        // Delete / Backspace không kèm modifier -> Đặt lại mặc định cho mục này
        if (keyCode == 51 || keyCode == 117) && cleanMods == 0 {
            resetAction(targetAction)
            return
        }

        // Bắt buộc có ít nhất 1 phím bổ trợ (⌘, ⌥, ⌃, ⇧) trừ khi là phím chức năng F1..F19
        if cleanMods == 0 && !ShortcutCombo.isFunctionKey(keyCode) {
            showStatus(tr("Hãy nhấn kèm phím ⌘, ⌥, ⌃ hoặc ⇧ (hoặc dùng phím F1–F19)",
                          "Please include ⌘, ⌥, ⌃, or ⇧ (or use F1–F19)"))
            return
        }

        let existingEnabled = combo(for: targetAction).isEnabled
        let newCombo = ShortcutCombo(keyCode: keyCode, modifiers: cleanMods, isEnabled: existingEnabled)

        // Kiểm tra trùng lặp với hành động khác
        if let conflictAction = ShortcutAction.allCases.first(where: {
            $0 != targetAction && combo(for: $0).keyCode == newCombo.keyCode && combo(for: $0).modifiers == newCombo.modifiers
        }) {
            // Hoán đổi phím cũ của targetAction sang conflictAction để không bao giờ bị kẹt trùng phím
            let previousCombo = combo(for: targetAction)
            bindings[conflictAction] = ShortcutCombo(
                keyCode: previousCombo.keyCode,
                modifiers: previousCombo.modifiers,
                isEnabled: combo(for: conflictAction).isEnabled
            )
            bindings[targetAction] = newCombo
            recordingAction = nil
            saveAndSync()
            showStatus(tr("Đã gán \(newCombo.displayString) cho «\(targetAction.title)» (đổi «\(conflictAction.title)» sang \(previousCombo.displayString))",
                          "Assigned \(newCombo.displayString) to «\(targetAction.title)» (swapped «\(conflictAction.title)» to \(previousCombo.displayString))"))
            return
        }

        bindings[targetAction] = newCombo
        recordingAction = nil
        saveAndSync()
        showStatus(tr("Đã lưu phím tắt \(newCombo.displayString) cho «\(targetAction.title)»",
                      "Saved \(newCombo.displayString) for «\(targetAction.title)»"))
    }

    // MARK: - Persistence & Synchronization

    private func loadBindings() {
        var loaded: [ShortcutAction: ShortcutCombo] = [:]
        for action in ShortcutAction.allCases {
            loaded[action] = action.defaultCombo
        }

        // Tương thích ngược với cài đặt clipboard_hud_shortcut cũ
        if let legacyClip = UserDefaults.standard.string(forKey: "clipboard_hud_shortcut"),
           legacyClip == "cmd_shift_v" {
            let cmdShift = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
            loaded[.clipboardHUD] = ShortcutCombo(keyCode: 9, modifiers: cmdShift)
        }

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ShortcutCombo].self, from: data) {
            for (rawKey, combo) in decoded {
                if let action = ShortcutAction(rawValue: rawKey) {
                    loaded[action] = combo
                }
            }
        }

        self.bindings = loaded
        gShortcutSnapshot = loaded
    }

    private func saveAndSync() {
        var rawDict: [String: ShortcutCombo] = [:]
        for (action, combo) in bindings {
            rawDict[action.rawValue] = combo
        }
        if let data = try? JSONEncoder().encode(rawDict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        gShortcutSnapshot = bindings
    }

    private func showStatus(_ message: String) {
        statusMessageToken &+= 1
        let token = statusMessageToken
        withAnimation(.easeInOut(duration: 0.18)) {
            statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            guard let self, self.statusMessageToken == token else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                self.statusMessage = nil
            }
        }
    }

    private func updateLocalMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        guard recordingAction != nil else { return }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recordingAction != nil else { return event }
            let keyCode = Int64(event.keyCode)
            var cgFlags = CGEventFlags()
            if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
            if event.modifierFlags.contains(.shift) { cgFlags.insert(.maskShift) }
            if event.modifierFlags.contains(.option) { cgFlags.insert(.maskAlternate) }
            if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }
            self.handleRecordedKey(keyCode: keyCode, flags: cgFlags)
            return nil
        }
    }

    // MARK: - Standalone Full-Screen / Wide Window Customizer

    public func openStandaloneWindow() {
        if let existing = standaloneWindow {
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let winW: CGFloat = min(780, visible.width - 80)
        let winH: CGFloat = min(640, visible.height - 80)
        let rect = NSRect(
            x: visible.midX - winW / 2,
            y: visible.midY - winH / 2,
            width: winW,
            height: winH
        )

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = tr("HyperMac — Trung tâm Tuỳ chỉnh Phím tắt", "HyperMac — Keyboard Shortcuts Center")
        window.minSize = NSSize(width: 620, height: 480)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(rootView: StandaloneShortcutWindowView(shortcutManager: self))
        self.standaloneWindow = window

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
