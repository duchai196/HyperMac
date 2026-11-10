import SwiftUI
import AppKit

// MARK: - Unified 1-Screen Shortcut Customizer View (For Menu Bar Popover & Standalone Window)

public struct UnifiedShortcutDashboardView: View {
    @ObservedObject var shortcutManager: ShortcutManager = ShortcutManager.shared
    @ObservedObject var displayManager: DisplayManager = DisplayManager.shared
    @ObservedObject var clipboardManager: ClipboardManager = ClipboardManager.shared
    @ObservedObject var screenshotManager: ScreenshotManager = ScreenshotManager.shared
    @ObservedObject var finderCutPasteManager: FinderCutPasteManager = FinderCutPasteManager.shared
    @ObservedObject var menuBarHiderManager: MenuBarHiderManager = MenuBarHiderManager.shared

    var isWideLayout: Bool = false

    public init(isWideLayout: Bool = false) {
        self.isWideLayout = isWideLayout
    }

    private var visibleCategories: [ShortcutCategory] {
        let base: [ShortcutCategory] = [.captureAndClipboard, .systemUtilities]
        if shortcutManager.selectedCategory == .all {
            return base
        }
        return base.filter { $0 == shortcutManager.selectedCategory }
    }

    private func actions(for category: ShortcutCategory) -> [ShortcutAction] {
        let q = shortcutManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ShortcutAction.allCases.filter { action in
            guard action.category == category else { return false }
            if q.isEmpty { return true }
            let comboStr = shortcutManager.combo(for: action).displayString.lowercased()
            return action.title.lowercased().contains(q) || comboStr.contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 6) {
            // 1. Top Filter & Quick Actions Bar
            topControlHeader
                .padding(.horizontal, 12)

            // 2. Active Recording Banner or Status Feedback Banner
            if let recording = shortcutManager.recordingAction {
                recordingBanner(for: recording)
                    .padding(.horizontal, 12)
            } else if let status = shortcutManager.statusMessage {
                statusBanner(status)
                    .padding(.horizontal, 12)
            }

            // 3. Main Scrollable All-in-One Shortcut List
            ScrollView(.vertical, showsIndicators: false) {
                if isWideLayout {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(visibleCategories, id: \.rawValue) { category in
                            let items = actions(for: category)
                            if !items.isEmpty {
                                categoryCard(category, actions: items)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(visibleCategories, id: \.rawValue) { category in
                            let items = actions(for: category)
                            if !items.isEmpty {
                                categoryCard(category, actions: items)
                            }
                        }

                        // Mouse Chord row (Chuột Trái + Phải -> Mission Control)
                        if shortcutManager.selectedCategory == .all || shortcutManager.selectedCategory == .systemUtilities {
                            mouseChordCompactCard
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Top Control Header

    private var topControlHeader: some View {
        VStack(spacing: 5) {
            // Search & Global Reset / Expand Row
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)

                    TextField(tr("Tìm chức năng hoặc phím tắt...", "Search action or key..."), text: $shortcutManager.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: FS.caption))

                    if !shortcutManager.searchQuery.isEmpty {
                        Button {
                            shortcutManager.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))

                if !isWideLayout {
                    Button {
                        shortcutManager.openStandaloneWindow()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: FS.caption))
                            Text(tr("Mở rộng", "Expand"))
                                .font(.system(size: FS.caption, weight: .medium))
                                .lineLimit(1)
                        }
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4.5)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Mở bảng phím tắt trong cửa sổ lớn 2 cột", "Open all shortcuts in a wide 2-column window"))
                }

                if shortcutManager.customizedCount > 0 {
                    Button {
                        shortcutManager.resetAllToDefaults()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: FS.caption))
                            Text(tr("Mặc định", "Reset"))
                                .font(.system(size: FS.caption, weight: .medium))
                                .lineLimit(1)
                        }
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4.5)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.orange.opacity(0.12)))
                        .foregroundStyle(Color.orange)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Khôi phục toàn bộ phím tắt về mặc định", "Restore all shortcuts to defaults"))
                }
            }

            // Category Filter Pills
            HStack(spacing: 4) {
                ForEach(ShortcutCategory.allCases, id: \.rawValue) { cat in
                    let isSelected = shortcutManager.selectedCategory == cat
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            shortcutManager.selectedCategory = cat
                        }
                    } label: {
                        Text(cat.shortTitle)
                            .font(.system(size: FS.caption, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Banners

    private func recordingBanner(for action: ShortcutAction) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: FS.body))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Đang gán phím cho: \(action.title)", "Recording shortcut for: \(action.title)"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(tr("Nhấn tổ hợp phím mới (vd: ⌘⇧4, ⌃⌥A) • Esc để huỷ • ⌫ về mặc định",
                        "Press new shortcut (e.g. ⌘⇧4, ⌃⌥A) • Esc cancel • ⌫ reset default"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                shortcutManager.cancelRecording()
            } label: {
                Text(tr("Huỷ", "Cancel"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(7)
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
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Tone.good.opacity(0.10)))
    }

    // MARK: - Category Card

    private func categoryCard(_ category: ShortcutCategory, actions: [ShortcutAction]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Category Header with Feature Master Toggle where applicable
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(category.title)
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                categoryMasterControl(for: category)
            }
            .padding(.bottom, 2)

            Divider().opacity(0.35)

            // Action Rows
            VStack(spacing: 4) {
                ForEach(actions) { action in
                    shortcutRow(for: action)
                }
            }
        }
        .padding(9)
        .cardBackground()
    }

    @ViewBuilder
    private func categoryMasterControl(for category: ShortcutCategory) -> some View {
        Text(tr("Bấm vào phím để đổi", "Click key to edit"))
            .font(.system(size: FS.caption))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Individual Shortcut Row

    private func shortcutRow(for action: ShortcutAction) -> some View {
        let combo = shortcutManager.combo(for: action)
        let isRecording = (shortcutManager.recordingAction == action)
        let isCustom = shortcutManager.isCustomized(action)
        let featureEnabled = isFeatureEnabled(for: action) && combo.isEnabled

        return HStack(spacing: 7) {
            // Enable / Disable Dot Toggle for this specific action
            Button {
                setFeatureAndActionEnabled(for: action, enabled: !featureEnabled)
            } label: {
                Image(systemName: featureEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: FS.body))
                    .foregroundStyle(featureEnabled ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help(featureEnabled ? tr("Đang bật • Bấm để tắt phím tắt này", "Enabled • Click to disable this shortcut")
                                 : tr("Đang tắt • Bấm để bật phím tắt này", "Disabled • Click to enable this shortcut"))

            Image(systemName: action.icon)
                .font(.system(size: FS.caption))
                .foregroundStyle(featureEnabled ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.45))
                .frame(width: 15)

            Text(action.title)
                .font(.system(size: FS.caption, weight: .medium))
                .foregroundStyle(featureEnabled ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            // Reset to default button (only visible when customized)
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

            // Interactive Key Recorder Button
            Button {
                shortcutManager.startRecording(action)
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                        Text(tr("Nhấn phím...", "Press key..."))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(combo.spacedDisplayString)
                            .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(
                                !featureEnabled
                                ? Color.secondary.opacity(0.5)
                                : (isCustom ? Color.accentColor : Color.primary)
                            )
                    }
                }
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .frame(minWidth: 74)
                .background(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(
                            isRecording
                            ? Color.accentColor.opacity(0.14)
                            : (isCustom ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.06))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .stroke(
                            isRecording
                            ? Color.accentColor
                            : (isCustom ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08)),
                            lineWidth: isRecording ? 1.5 : 1
                        )
                )
            }
            .buttonStyle(.plain)
            .help(tr("Bấm vào đây rồi nhấn tổ hợp phím mới trên bàn phím",
                     "Click here then press new key combination on your keyboard"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm)
                .fill(isRecording ? Color.accentColor.opacity(0.05) : Color.primary.opacity(0.02))
        )
    }

    // MARK: - Mouse Chord Compact Card

    private var mouseChordCompactCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: FS.label, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Chuột Trái + Phải cùng lúc ➔ Mở Mission Control (F3)", "Simultaneous Left + Right Click ➔ Mission Control (F3)"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding<Bool>(
                get: { displayManager.isMouseChordEnabled },
                set: {
                    displayManager.isMouseChordEnabled = $0
                    UserDefaults.standard.set($0, forKey: "mouse_chord_enabled")
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(9)
        .cardBackground()
    }

    // MARK: - Feature State Helpers

    private func isFeatureEnabled(for action: ShortcutAction) -> Bool {
        switch action {
        case .screenshotCapture, .screenshotFullScreen, .screenshotQuickCopy, .screenshotActiveWindow:
            return screenshotManager.isScreenshotEnabled
        case .clipboardHUD:
            return clipboardManager.isMonitoringEnabled
        case .menuBarDrawer:
            return menuBarHiderManager.isEnabled
        case .toggleCaffeinate:
            return true
        case .finderCut:
            return finderCutPasteManager.isEnabled
        }
    }

    private func setFeatureAndActionEnabled(for action: ShortcutAction, enabled: Bool) {
        if enabled {
            switch action {
            case .screenshotCapture, .screenshotFullScreen, .screenshotQuickCopy, .screenshotActiveWindow:
                screenshotManager.isScreenshotEnabled = true
            case .clipboardHUD:
                clipboardManager.isMonitoringEnabled = true
            case .menuBarDrawer:
                menuBarHiderManager.isEnabled = true
            case .finderCut:
                finderCutPasteManager.isEnabled = true
            case .toggleCaffeinate:
                break
            }
        }
        shortcutManager.setActionEnabled(action, enabled)
    }
}

// MARK: - Standalone Wide Window View

public struct StandaloneShortcutWindowView: View {
    @ObservedObject var shortcutManager: ShortcutManager

    public init(shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: FS.display, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Trung tâm Tuỳ chỉnh Phím tắt HyperMac", "HyperMac Keyboard Shortcuts Center"))
                        .font(.system(size: FS.subhead, weight: .semibold))
                    Text(tr("Tất cả phím tắt tập trung trên 1 màn hình • Bấm vào bất kỳ ô phím nào rồi nhấn tổ hợp phím mới để thay đổi",
                            "All shortcuts on one screen • Click any key badge and press a new key combination to customize"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().padding(.horizontal, 12)

            UnifiedShortcutDashboardView(isWideLayout: true)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}
