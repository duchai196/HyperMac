import Foundation
import AppKit
import CoreGraphics
import CoreBluetooth
import ApplicationServices
import Combine

// MARK: - Permission Item Model

public struct PermissionDetailItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let tag: String
    public let isRequired: Bool
    public let isGranted: Bool
    public let reason: String
    public let settingsURLString: String
}

// MARK: - Permissions Manager (Centralized TCC & System Permissions Hub)

@MainActor
public class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public var hasAccessibility: Bool = false
    @Published public var hasScreenCapture: Bool = false
    @Published public var hasSMCHelper: Bool = false
    @Published public var hasBluetooth: Bool = false

    @Published public var isExpanded: Bool = false
    @Published public var isProbing: Bool = false

    private var pollTimer: Timer?
    private var isFirstCheck = true
    private var btManager: CBCentralManager?

    public var allGranted: Bool {
        hasAccessibility && hasScreenCapture && hasSMCHelper
    }

    public var requiredGranted: Bool {
        hasAccessibility
    }

    public var missingCount: Int {
        var count = 0
        if !hasAccessibility { count += 1 }
        if !hasScreenCapture { count += 1 }
        if !hasSMCHelper { count += 1 }
        return count
    }

    private init() {
        refreshStatus()
        // Auto-expand if accessibility is missing so new users see it immediately
        if !hasAccessibility {
            self.isExpanded = true
        }

        // Poll every 1.5s so when user toggles permission in System Settings, UI instantly updates
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Screen Recording Permission Check

    nonisolated public static func checkScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        // Khi người dùng vừa bật quyền Ghi màn hình trong System Settings mà chọn "Để sau" (chưa khởi động lại app),
        // CGPreflightScreenCaptureAccess() vẫn cache giá trị false cho tới khi mở lại tiến trình,
        // nhưng WindowServer lập tức cho phép đọc kCGWindowName của các cửa sổ ứng dụng (layer == 0).
        // Lưu ý: phải lọc chặt layer == 0 và loại trừ "Window Server" (layer 24 "Menubar") để không bao giờ báo dương tính giả.
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

    // MARK: - Live Permission Checks

    public func refreshStatus() {
        // 1. Accessibility (Trợ năng)
        let axTrusted = AXIsProcessTrusted()
        if self.hasAccessibility != axTrusted {
            self.hasAccessibility = axTrusted
            appLog("🔐 PermissionsManager: Accessibility changed -> \(axTrusted)")
            if axTrusted {
                KeyInterceptor.shared.start()
            }
        }

        // 2. Screen Capture (Ghi màn hình)
        let screenTrusted = Self.checkScreenCaptureAccess()
        if self.hasScreenCapture != screenTrusted {
            self.hasScreenCapture = screenTrusted
            appLog("🔐 PermissionsManager: ScreenCapture changed -> \(screenTrusted)")
        }

        // 3. SMC Helper (Khóa sạc 80%)
        let smcInstalled = BatteryManager.shared.isHelperInstalled
        if self.hasSMCHelper != smcInstalled {
            self.hasSMCHelper = smcInstalled
            appLog("🔐 PermissionsManager: SMCHelper changed -> \(smcInstalled)")
        }

        // 4. Bluetooth (Sleep Guard)
        if #available(macOS 10.15, *) {
            let btStatus = CBCentralManager.authorization
            let btTrusted = (btStatus == .allowedAlways) || (btStatus == .notDetermined && BluetoothManager.shared.isAvailable)
            if self.hasBluetooth != btTrusted {
                self.hasBluetooth = btTrusted
            }
        } else {
            self.hasBluetooth = true
        }

        // Auto-collapse when user has granted all required permissions for the first time
        if isFirstCheck {
            isFirstCheck = false
            if requiredGranted {
                self.isExpanded = false
            }
        }
    }

    // MARK: - Deep Probe (Kiểm tra thật sự toàn bộ quyền)

    public func runDeepProbe() {
        guard !isProbing else { return }
        self.isProbing = true
        BatteryManager.shared.checkHelperStatus { [weak self] _ in
            self?.refreshStatus()
            if self?.hasAccessibility == true {
                KeyInterceptor.shared.start()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self?.isProbing = false
            }
        }
    }

    /// Xoá entry TCC cũ bị kẹt (do đổi chữ ký/cập nhật) và yêu cầu macOS cấp lại quyền mới.
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

    // MARK: - Actions

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

    public func installSMCHelper() {
        BatteryManager.shared.installHelper { [weak self] _ in
            self?.refreshStatus()
        }
    }

    public func openBluetoothSettings() {
        if btManager == nil {
            btManager = CBCentralManager(delegate: nil, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }
}

