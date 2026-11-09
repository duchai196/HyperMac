import SwiftUI
import AppKit

// MARK: - Clipboard HUD Overlay View (Hallmark Liquid Glass Design)

public struct ClipboardOverlayView: View {
    @ObservedObject var manager: ClipboardManager

    public init(manager: ClipboardManager) {
        self.manager = manager
    }

    public var body: some View {
        ZStack {
            // Visual Effect Background
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Top Search & Filter Header
                topSearchBar

                // Filter Category Bar
                categoryBar

                Divider().opacity(0.2)

                // List of Clips
                if manager.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    clipsListView
                }

                Divider().opacity(0.2)

                // Bottom Footer & Hotkey Hints
                footerBar
            }
        }
        .frame(width: ClipboardManager.hudWidth, height: ClipboardManager.hudHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Top Search Bar

    private var topSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FS.title, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(tr("Tìm kiếm clipboard...", "Search clipboard..."), text: $manager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: FS.title, weight: .medium))
                .onSubmit {
                    manager.pasteSelectedItem()
                }

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FS.body))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Close HUD Button
            Button {
                manager.hideHUD()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(tr("Đóng (Esc)", "Close (Esc)"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Category Filter Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach([ClipType.all, .text, .image, .url, .file, .color], id: \.self) { type in
                    Button {
                        manager.selectedFilter = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: FS.caption))
                            Text(type.title)
                                .font(.system(size: FS.caption, weight: manager.selectedFilter == type ? .semibold : .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule().fill(manager.selectedFilter == type ? Color.accentColor : Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(manager.selectedFilter == type ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Clips List View

    private var clipsListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 5) {
                    ForEach(Array(manager.filteredItems.enumerated()), id: \.element.id) { index, item in
                        clipRow(index: index, item: item)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Single Clip Row

    private func clipRow(index: Int, item: ClipItem) -> some View {
        let isSelected = manager.selectedIndex == index
        let isHovered = manager.hoveredItemID == item.id

        return Button {
            manager.pasteItem(item)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                // Main Value Content Render by Type
                Group {
                    switch item.type {
                    case .image:
                        let previewImg: NSImage? = {
                            if let data = item.imageData, let img = NSImage(data: data) {
                                return img
                            }
                            if let url = manager.imageURL(for: item), let data = try? Data(contentsOf: url) {
                                return NSImage(data: data)
                            }
                            return nil
                        }()

                        if let nsImg = previewImg {
                            HStack(spacing: 8) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 160, maxHeight: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: Rad.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Rad.sm)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )

                                Text(item.title)
                                    .font(.system(size: FS.body, weight: .regular))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(item.title)
                                .font(.system(size: FS.body, weight: .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                    case .color:
                        HStack(spacing: 8) {
                            if let hex = item.colorHex {
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(Color(hex: hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Rad.sm)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            Text(item.title)
                                .font(.system(size: FS.body, weight: .regular, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                    case .file:
                        Text(item.title)
                            .font(.system(size: FS.body, weight: .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                    case .url:
                        Text(item.title)
                            .font(.system(size: FS.body, weight: .regular))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)

                    case .text, .rtf, .all:
                        let singleLine = (item.plainText ?? item.title)
                            .replacingOccurrences(of: "\r\n", with: " ")
                            .replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(singleLine.isEmpty ? item.title : singleLine)
                            .font(.system(size: FS.body, weight: .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Action Buttons on Hover / Selection
                if isHovered || isSelected {
                    HStack(spacing: 6) {
                        if item.isPinned {
                            if manager.canMoveUp(id: item.id) {
                                Button {
                                    manager.movePinnedItem(id: item.id, direction: .up)
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: FS.caption, weight: .bold))
                                        .foregroundStyle(Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Đổi lên trên (⌘↑)", "Move up (⌘↑)"))
                            }

                            if manager.canMoveDown(id: item.id) {
                                Button {
                                    manager.movePinnedItem(id: item.id, direction: .down)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: FS.caption, weight: .bold))
                                        .foregroundStyle(Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Đổi xuống dưới (⌘↓)", "Move down (⌘↓)"))
                            }
                        }

                        Button {
                            manager.togglePin(item)
                        } label: {
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(item.isPinned ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? tr("Bỏ ghim (⌥P)", "Unpin (⌥P)") : tr("Ghim lên đầu (⌥P)", "Pin to top (⌥P)"))

                        Button {
                            manager.deleteItem(item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Xóa mục (⌥⌫)", "Delete item (⌥⌫)"))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            manager.hoveredItemID = hovering ? item.id : nil
            if hovering {
                manager.selectedIndex = index
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: FS.huge))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(tr("Lịch sử Clipboard trống", "Clipboard History is Empty"))
                .font(.system(size: FS.body, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(tr("Hãy sao chép (⌘C) văn bản, hình ảnh hoặc tệp tin để lưu vào HyperMac.", "Copy (⌘C) text, images or files to save them in HyperMac."))
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Footer Bar

    private var footerBar: some View {
        HStack(spacing: 8) {
            // Key hints
            HStack(spacing: 7) {
                legendItem(key: "↵", label: tr("Dán", "Paste"))
                legendItem(key: "↑↓", label: tr("Di chuyển", "Navigate"))
                legendItem(key: "⌘↑↓", label: tr("Đổi vị trí", "Reorder"))
                legendItem(key: "⌥P", label: tr("Ghim", "Pin"))
                legendItem(key: "⌥⌫", label: tr("Xóa", "Delete"))
                legendItem(key: "⎋", label: tr("Đóng", "Close"))
            }

            Spacer(minLength: 6)

            // Count & Clear button
            HStack(spacing: 6) {
                Text(tr("\(manager.filteredItems.count) mục", "\(manager.filteredItems.count) items"))
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()

                Button(tr("Xóa hết", "Clear All")) {
                    manager.clearAllHistory()
                }
                .font(.system(size: FS.caption, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.8))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.red.opacity(0.1)))
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    private func legendItem(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.08)))
            Text(label)
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
    }
}
