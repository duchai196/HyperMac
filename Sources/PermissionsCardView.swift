import SwiftUI
import AppKit

// MARK: - Compact Permissions Card (Accessibility & Screen Recording Only)

public struct PermissionsCardView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    public init(permissionsManager: PermissionsManager) {
        self.permissionsManager = permissionsManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    permissionsManager.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: permissionsManager.allGranted ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.system(size: FS.title, weight: .semibold))
                        .foregroundStyle(permissionsManager.allGranted ? Tone.good : Tone.warn)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(permissionsManager.allGranted
                             ? tr("Quyền hệ thống đầy đủ", "Permissions Ready")
                             : tr("Thiếu \(permissionsManager.missingCount) quyền hệ thống", "Missing \(permissionsManager.missingCount) permission(s)"))
                            .font(.system(size: FS.label, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(tr("Trợ năng (phím tắt) & Ghi màn hình (chụp vùng)", "Accessibility (shortcuts) & Screen Recording (capture)"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: permissionsManager.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if permissionsManager.isExpanded {
                VStack(spacing: 6) {
                    Divider().opacity(0.3)

                    permissionRow(
                        title: tr("Trợ năng (Accessibility)", "Accessibility"),
                        reason: tr("Dùng cho phím tắt Clipboard, Chụp ảnh, Chống sleep", "For global Clipboard, Screenshot & Keep Awake shortcuts"),
                        isGranted: permissionsManager.hasAccessibility,
                        action: { permissionsManager.openAccessibilitySettings() }
                    )

                    permissionRow(
                        title: tr("Ghi màn hình (Screen Recording)", "Screen Recording"),
                        reason: tr("Dùng để chụp vùng màn hình mở Studio", "For capturing screen region into Studio"),
                        isGranted: permissionsManager.hasScreenCapture,
                        action: { permissionsManager.openScreenCaptureSettings() }
                    )

                    if !permissionsManager.allGranted {
                        HStack(spacing: 6) {
                            Button {
                                permissionsManager.resetStuckPermissions()
                            } label: {
                                Text(tr("Làm mới TCC", "Reset TCC"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(Tone.warn)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Tone.warn.opacity(0.15)))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                permissionsManager.runDeepProbe()
                            } label: {
                                Text(tr("Kiểm tra lại", "Re-check"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .cardBackground()
    }

    private func permissionRow(title: String, reason: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: FS.caption, weight: .semibold))
                Text(reason)
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isGranted {
                HStack(spacing: 4) {
                    Circle().fill(Tone.good).frame(width: 6, height: 6)
                    Text(tr("Đã cấp", "OK"))
                        .font(.system(size: FS.caption, weight: .semibold))
                }
                .foregroundStyle(Tone.good)
            } else {
                Button(action: action) {
                    Text(tr("Cấp quyền", "Grant"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
    }
}
