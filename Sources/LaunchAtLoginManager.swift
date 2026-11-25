import Foundation
import AppKit
import ServiceManagement

@MainActor
public class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public var isEnabled: Bool = false
    @Published public var requiresApproval: Bool = false

    private init() {
        checkSystemStatus()
    }

    public func toggle() {
        if requiresApproval {
            openSystemSettings()
        } else {
            setEnabled(!isEnabled)
        }
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            appLog("⚠️ LaunchAtLoginManager: SMAppService \(enabled ? "register" : "unregister") error: \(error.localizedDescription)")
        }

        checkSystemStatus()

        // Nếu macOS đang chặn (disallowed / requiresApproval), mở thẳng Cài đặt Mục đăng nhập để người dùng bật lại
        if enabled && requiresApproval {
            openSystemSettings()
        }
    }

    public func checkSystemStatus() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            self.isEnabled = true
            self.requiresApproval = false
        case .requiresApproval:
            self.isEnabled = false
            self.requiresApproval = true
        case .notRegistered, .notFound:
            self.isEnabled = false
            self.requiresApproval = false
        @unknown default:
            self.isEnabled = false
            self.requiresApproval = false
        }
        UserDefaults.standard.set(self.isEnabled, forKey: "launch_at_login_enabled")
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
