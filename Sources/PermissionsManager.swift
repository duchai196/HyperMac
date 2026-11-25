import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import Combine

// MARK: - Lightweight Permissions Manager (Accessibility & Screen Recording Only)

@MainActor
public class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public var hasAccessibility: Bool = false
    @Published public var hasScreenCapture: Bool = false
    @Published public var isExpanded: Bool = false
    @Published public var isProbing: Bool = false

    private var pollTimer: Timer?

    public var allGranted: Bool {
        hasAccessibility && hasScreenCapture
    }

    public var missingCount: Int {
        (hasAccessibility ? 0 : 1) + (hasScreenCapture ? 0 : 1)
    }

    private init() {
        refreshStatus()
        if !allGranted {
            self.isExpanded = true
        }
    }

    /// Only poll permissions while the popover is visible and a permission is missing (zero idle wakeups).
    public func setPopoverVisible(_ visible: Bool) {
        if visible {
            refreshStatus()
            if !allGranted {
                startPolling()
            }
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshStatus()
                if self.allGranted {
                    self.stopPolling()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Screen Recording Check

    nonisolated public static func checkScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for entry in windowList {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t, ownerPID != myPID else { continue }
            let ownerName = (entry[kCGWindowOwnerName as String] as? String) ?? ""
            if ownerName == "Window Server" || ownerName == "WindowServer" || ownerName == "Dock" { continue }
            if let winName = entry[kCGWindowName as String] as? String, !winName.isEmpty {
                return true
            }
        }
        return false
    }

    public func refreshStatus() {
        let axTrusted = AXIsProcessTrusted()
        if self.hasAccessibility != axTrusted {
            self.hasAccessibility = axTrusted
            appLog("🔐 PermissionsManager: Accessibility -> \(axTrusted)")
            if axTrusted {
                KeyInterceptor.shared.start()
            }
        }

        let screenTrusted = Self.checkScreenCaptureAccess()
        if self.hasScreenCapture != screenTrusted {
            self.hasScreenCapture = screenTrusted
            appLog("🔐 PermissionsManager: ScreenCapture -> \(screenTrusted)")
        }
    }

    public func runDeepProbe() {
        guard !isProbing else { return }
        isProbing = true
        refreshStatus()
        if hasAccessibility {
            KeyInterceptor.shared.start()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isProbing = false
        }
    }

    public func resetStuckPermissions() {
        if !hasAccessibility {
            AccessibilityRecovery.resetTCCService("Accessibility")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
        }
        if !hasScreenCapture {
            AccessibilityRecovery.resetTCCService("ScreenCapture")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                _ = CGRequestScreenCaptureAccess()
            }
        }
        runDeepProbe()
    }

    public func openAccessibilitySettings() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openScreenCaptureSettings() {
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
