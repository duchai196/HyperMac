import Foundation
import ApplicationServices
import CoreGraphics
import Security

/// Tự khôi phục quyền Accessibility / Screen Recording khi chữ ký hoặc phiên bản thay đổi.
///
/// Vì sao cần: khi chuyển giữa bản phát hành (ký bằng cert CI) và bản tự build local
/// (ký bằng cert `HyperMac Self-Signed` của máy), hoặc từ bản ad-hoc cũ, Designated
/// Requirement thay đổi nên macOS vô hiệu hoá entry TCC cũ dù công tắc trong System Settings
/// vẫn hiển thị đang bật.
@MainActor
enum AccessibilityRecovery {
    private static let axResetTokenKey = "ax_recovery_signature_token"
    private static let screenResetTokenKey = "screencapture_recovery_signature_token"

    static func handleLaunch() {
        let axTrusted = AXIsProcessTrusted()
        let screenTrusted = CGPreflightScreenCaptureAccess()
        appLog("🔐 Permissions at launch: Accessibility=\(axTrusted), ScreenCapture=\(screenTrusted)")

        let defaults = UserDefaults.standard
        let currentToken = currentSignatureToken()

        // 1. Khôi phục quyền Accessibility độc lập
        if !axTrusted {
            if defaults.string(forKey: axResetTokenKey) != currentToken {
                resetTCCService("Accessibility")
                defaults.set(currentToken, forKey: axResetTokenKey)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                }
            }
        } else {
            defaults.set(currentToken, forKey: axResetTokenKey)
        }

        // 2. Khôi phục quyền ScreenCapture độc lập (ngay cả khi Accessibility đã được cấp trước đó)
        if !screenTrusted {
            if defaults.string(forKey: screenResetTokenKey) != currentToken {
                resetTCCService("ScreenCapture")
                defaults.set(currentToken, forKey: screenResetTokenKey)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    _ = CGRequestScreenCaptureAccess()
                }
            }
        } else {
            defaults.set(currentToken, forKey: screenResetTokenKey)
        }
    }

    /// Trả về chuỗi định danh duy nhất cho phiên bản + Designated Requirement hiện tại của app.
    static func currentSignatureToken() -> String {
        let version = UpdateManager.currentVersion
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let selfCode = code else {
            return version
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &staticCode) == errSecSuccess,
              let sCode = staticCode else {
            return version
        }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(sCode, [], &requirement) == errSecSuccess,
              let req = requirement else {
            return version
        }
        var reqString: CFString?
        guard SecRequirementCopyString(req, [], &reqString) == errSecSuccess,
              let str = reqString as String? else {
            return version
        }
        return "\(version)|\(str)"
    }

    static func resetTCCService(_ service: String) {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleID]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            appLog("🔐 AccessibilityRecovery: reset quyền \(service) cho \(bundleID) (mã \(process.terminationStatus))")
        } catch {
            appLog("⚠️ AccessibilityRecovery: không reset được quyền \(service): \(error.localizedDescription)")
        }
    }
}
