import Foundation
import AppKit
import CoreGraphics
import Combine
import SwiftUI

// MARK: - Shortcut Actions (Only Kept Core Features)

public enum ShortcutAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case clipboardHUD      = "clipboard_hud"
    case screenshotCapture = "screenshot_capture"
    case toggleCaffeinate  = "toggle_caffeinate"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clipboardHUD:      return tr("Mở lịch sử Clipboard", "Open Clipboard History")
        case .screenshotCapture: return tr("Chụp vùng mở Studio", "Capture Region to Studio")
        case .toggleCaffeinate:  return tr("Bật / Tắt Chống sleep màn", "Toggle Keep Screen Awake")
        }
    }

    public var icon: String {
        switch self {
        case .clipboardHUD:      return "doc.on.clipboard.fill"
        case .screenshotCapture: return "viewfinder"
        case .toggleCaffeinate:  return "cup.and.saucer.fill"
        }
    }

    public var defaultCombo: ShortcutCombo {
        let cmd = CGEventFlags.maskCommand.rawValue
        let shift = CGEventFlags.maskShift.rawValue
        let opt = CGEventFlags.maskAlternate.rawValue
        let ctrl = CGEventFlags.maskControl.rawValue

        switch self {
        case .clipboardHUD:
            return ShortcutCombo(keyCode: 8, modifiers: cmd | shift)         // ⌘⇧C
        case .screenshotCapture:
            return ShortcutCombo(keyCode: 18, modifiers: cmd | shift)        // ⌘⇧1
        case .toggleCaffeinate:
            return ShortcutCombo(keyCode: 1, modifiers: ctrl | opt | cmd)    // ⌃⌥⌘S
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
        case 118, 131: return "F4"
        case 120: return "F2"
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
    @Published public var statusMessage: String? = nil

    private var statusMessageToken: Int = 0
    private var localKeyMonitor: Any? = nil

    private init() {
        loadBindings()
    }

    public func combo(for action: ShortcutAction) -> ShortcutCombo {
        bindings[action] ?? action.defaultCombo
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
        showStatus(tr("Đã đặt lại phím tắt về \(action.defaultCombo.displayString)",
                      "Reset shortcut to \(action.defaultCombo.displayString)"))
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
                      "Restored all shortcuts to defaults"))
    }

    public func handleRecordedKey(keyCode: Int64, flags: CGEventFlags) {
        guard let targetAction = recordingAction else { return }
        if ShortcutCombo.isPureModifierKey(keyCode) { return }

        let cleanMods = flags.rawValue & ShortcutCombo.relevantModifierMask

        if keyCode == 53 && cleanMods == 0 {
            cancelRecording()
            return
        }

        if (keyCode == 51 || keyCode == 117) && cleanMods == 0 {
            resetAction(targetAction)
            return
        }

        if cleanMods == 0 && !ShortcutCombo.isFunctionKey(keyCode) {
            showStatus(tr("Hãy nhấn kèm ⌘, ⌥, ⌃ hoặc ⇧ (hoặc phím F1–F15)",
                          "Include ⌘, ⌥, ⌃, or ⇧ (or use F1–F15)"))
            return
        }

        let existingEnabled = combo(for: targetAction).isEnabled
        let newCombo = ShortcutCombo(keyCode: keyCode, modifiers: cleanMods, isEnabled: existingEnabled)

        if let conflictAction = ShortcutAction.allCases.first(where: {
            $0 != targetAction && combo(for: $0).keyCode == newCombo.keyCode && combo(for: $0).modifiers == newCombo.modifiers
        }) {
            let previousCombo = combo(for: targetAction)
            bindings[conflictAction] = ShortcutCombo(
                keyCode: previousCombo.keyCode,
                modifiers: previousCombo.modifiers,
                isEnabled: combo(for: conflictAction).isEnabled
            )
            bindings[targetAction] = newCombo
            recordingAction = nil
            saveAndSync()
            showStatus(tr("Đã gán \(newCombo.displayString) (hoán đổi với «\(conflictAction.title)»)",
                          "Assigned \(newCombo.displayString) (swapped with «\(conflictAction.title)»)"))
            return
        }

        bindings[targetAction] = newCombo
        recordingAction = nil
        saveAndSync()
        showStatus(tr("Đã lưu phím tắt \(newCombo.displayString)", "Saved shortcut \(newCombo.displayString)"))
    }

    private func loadBindings() {
        var loaded: [ShortcutAction: ShortcutCombo] = [:]
        for action in ShortcutAction.allCases {
            loaded[action] = action.defaultCombo
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
        withAnimation(.easeInOut(duration: 0.16)) {
            statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self, self.statusMessageToken == token else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
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
}
