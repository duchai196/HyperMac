import SwiftUI
import AppKit

// MARK: - Lightweight Main Popover View (Clipboard 10 + Region Studio + Keep Awake)

public struct MainView: View {
    @ObservedObject var clipboardManager: ClipboardManager = ClipboardManager.shared
    @ObservedObject var screenshotManager: ScreenshotManager = ScreenshotManager.shared
    @ObservedObject var caffeinateManager: CaffeinateManager = CaffeinateManager.shared
    @ObservedObject var shortcutManager: ShortcutManager = ShortcutManager.shared
    @ObservedObject var permissionsManager: PermissionsManager = PermissionsManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject var languageManager: LanguageManager = LanguageManager.shared

    var onClosePopover: (() -> Void)? = nil

    public init(onClosePopover: (() -> Void)? = nil) {
        self.onClosePopover = onClosePopover
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider().opacity(0.25)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Active shortcut recording / status banner
                    if let recording = shortcutManager.recordingAction {
                        recordingBanner(for: recording)
                    } else if let status = shortcutManager.statusMessage {
                        statusBanner(status)
                    }

                    // Launch at login approval banner (when macOS Background Items disallowed HyperMac)
                    if launchAtLoginManager.requiresApproval {
                        loginApprovalBanner
                    }

                    // Permissions (chỉ hiện khi còn thiếu quyền Trợ năng hoặc Ghi màn hình)
                    if !permissionsManager.allGranted {
                        PermissionsCardView(permissionsManager: permissionsManager)
                    }

                    // 1. Clipboard History (10 most recent, no categories)
                    clipboardCard

                    // 2. Region Screenshot -> Studio (Arrow & Text)
                    screenshotCard

                    // 3. Keep Screen Awake (Anti-Sleep)
                    caffeinateCard
                }
                .padding(12)
            }
        }
        .frame(width: 356, height: 455)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "command.circle.fill")
                .font(.system(size: FS.subhead, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("HyperMac")
                .font(.system(size: FS.title, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Launch at login toggle
            Button {
                launchAtLoginManager.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: launchAtLoginManager.isEnabled
                          ? "checkmark.circle.fill"
                          : (launchAtLoginManager.requiresApproval ? "exclamationmark.circle.fill" : "circle"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(
                            launchAtLoginManager.isEnabled
                                ? Tone.good
                                : (launchAtLoginManager.requiresApproval ? Tone.warn : .secondary)
                        )
                    Text(tr("Khởi động cùng Mac", "Login"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(launchAtLoginManager.requiresApproval ? Tone.warn : .secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(launchAtLoginManager.requiresApproval
                  ? tr("macOS đang chặn khởi động nền — bấm để mở Mục đăng nhập", "Blocked in macOS Login Items — click to approve")
                  : tr("Tự động chạy khi bật máy", "Launch at login"))

            // Language switch (VI / EN)
            Button {
                languageManager.toggleLanguage()
            } label: {
                Text(languageManager.currentLanguage == .vi ? "VI" : "EN")
                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(tr("Chuyển ngôn ngữ VI / EN", "Switch language VI / EN"))

            // Refresh Permissions & Status
            Button {
                permissionsManager.runDeepProbe()
                launchAtLoginManager.checkSystemStatus()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(permissionsManager.isProbing ? 360 : 0))
                    .animation(permissionsManager.isProbing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: permissionsManager.isProbing)
                    .padding(4)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .disabled(permissionsManager.isProbing)
            .help(tr("Làm mới quyền hệ thống & trạng thái", "Refresh permissions & status"))

            // Quit App
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(tr("Thoát HyperMac", "Quit HyperMac"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Shortcut Recording & Status Banners

    private func recordingBanner(for action: ShortcutAction) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: FS.body))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Đang gán phím: \(action.title)", "Recording: \(action.title)"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .lineLimit(1)
                Text(tr("Nhấn tổ hợp phím mới • ⎋ Huỷ • ⌫ Mặc định", "Press new combo • ⎋ Cancel • ⌫ Default"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(tr("Huỷ", "Cancel")) {
                shortcutManager.cancelRecording()
            }
            .font(.system(size: FS.caption, weight: .semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm)
                .fill(Color.accentColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Rad.sm).stroke(Color.accentColor.opacity(0.45), lineWidth: 1))
        )
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: FS.caption))
                .foregroundStyle(Tone.good)
            Text(message)
                .font(.system(size: FS.caption, weight: .medium))
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Tone.good.opacity(0.12)))
    }

    private var loginApprovalBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: FS.body))
                .foregroundStyle(Tone.warn)

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("macOS đang chặn khởi động cùng máy", "Launch at Login requires macOS approval"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(Tone.warn)
                Text(tr("Bật công tắc HyperMac trong Mục đăng nhập & Phần mở rộng", "Enable HyperMac in Login Items & Extensions"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button {
                launchAtLoginManager.openSystemSettings()
            } label: {
                Text(tr("Mở Cài đặt", "Open Settings"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Tone.warn))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Tone.warn.opacity(0.12)))
    }

    // MARK: - Card 1: Clipboard History (10 Most Recent)

    private var clipboardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: FS.body))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Lịch sử Clipboard", "Clipboard History"))
                        .font(.system(size: FS.body, weight: .semibold))
                    Text(tr("Lưu \(clipboardManager.items.count)/\(ClipboardManager.maxItemsCount) bản ghi gần nhất",
                            "Keeping \(clipboardManager.items.count)/\(ClipboardManager.maxItemsCount) most recent clips"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $clipboardManager.isMonitoringEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            Divider().opacity(0.3)

            shortcutControlRow(action: .clipboardHUD)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                Text(tr("Bỏ qua mật khẩu (1Password, Keychain)", "Ignore passwords (1Password, Keychain)"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Toggle("", isOn: $clipboardManager.ignoreConcealedTypes)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            HStack(spacing: 6) {
                Button {
                    onClosePopover?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        clipboardManager.showHUD()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: FS.caption))
                        Text(tr("Mở Clipboard", "Open Clipboard"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Button {
                    clipboardManager.clearAllHistory()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: FS.caption))
                        Text(tr("Xoá lịch sử", "Clear"))
                            .font(.system(size: FS.caption, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(clipboardManager.items.isEmpty)
            }
        }
        .padding(10)
        .cardBackground()
    }

    // MARK: - Card 2: Region Screenshot Studio (Arrow & Text)

    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: FS.body))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Chụp vùng Studio", "Region Studio Capture"))
                        .font(.system(size: FS.body, weight: .semibold))
                    Text(tr("Kéo chọn vùng ➔ thêm mũi tên & nhập chữ", "Drag region ➔ add arrows & text"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $screenshotManager.isScreenshotEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            Divider().opacity(0.3)

            shortcutControlRow(action: .screenshotCapture)

            Button {
                onClosePopover?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    screenshotManager.startCapture()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: FS.caption, weight: .semibold))
                    Text(tr("Chụp vùng màn hình ngay", "Capture Region Now"))
                        .font(.system(size: FS.caption, weight: .semibold))
                }
                .padding(.vertical, 5.5)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!screenshotManager.isScreenshotEnabled)
        }
        .padding(10)
        .cardBackground()
    }

    // MARK: - Card 3: Keep Screen Awake (Anti-Sleep)

    private var caffeinateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: caffeinateManager.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: FS.body))
                    .foregroundStyle(caffeinateManager.isActive ? Tone.good : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(tr("Chống sleep màn hình", "Keep Screen Awake"))
                            .font(.system(size: FS.body, weight: .semibold))
                        if caffeinateManager.isActive {
                            Text(caffeinateManager.remainingFormatted)
                                .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Tone.good.opacity(0.16)))
                                .foregroundStyle(Tone.good)
                        }
                    }
                    Text(caffeinateManager.isActive
                         ? tr("Đang giữ màn hình luôn sáng", "Preventing display sleep")
                         : tr("Màn hình tự tắt theo cài đặt macOS", "Following macOS display sleep"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding<Bool>(
                    get: { caffeinateManager.isActive },
                    set: { $0 ? caffeinateManager.enable(duration: caffeinateManager.selectedDuration) : caffeinateManager.disable() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            Divider().opacity(0.3)

            // Duration Presets
            HStack(spacing: 5) {
                ForEach(CaffeinateDuration.allCases) { dur in
                    let isSelected = caffeinateManager.selectedDuration == dur
                    Button {
                        caffeinateManager.setDuration(dur)
                    } label: {
                        Text(dur.title)
                            .font(.system(size: FS.caption, weight: isSelected ? .semibold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            shortcutControlRow(action: .toggleCaffeinate)
        }
        .padding(10)
        .cardBackground()
    }

    // MARK: - Inline Shortcut Recorder Row

    private func shortcutControlRow(action: ShortcutAction) -> some View {
        let combo = shortcutManager.combo(for: action)
        let isRecording = shortcutManager.recordingAction == action
        let isCustom = shortcutManager.isCustomized(action)

        return HStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)
            Text(tr("Phím tắt:", "Shortcut:"))
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)

            Spacer()

            if isCustom {
                Button {
                    shortcutManager.resetAction(action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(3.5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help(tr("Đặt lại mặc định (\(action.defaultCombo.displayString))",
                         "Reset to default (\(action.defaultCombo.displayString))"))
            }

            Button {
                shortcutManager.startRecording(action)
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                        Text(tr("Nhấn phím...", "Press keys..."))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(combo.spacedDisplayString)
                            .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isCustom ? Color.accentColor : Color.primary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(minWidth: 74)
                .background(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .stroke(isRecording ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isRecording ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .help(tr("Bấm để đổi phím tắt", "Click to customize shortcut"))
        }
    }
}
