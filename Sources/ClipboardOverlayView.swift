import SwiftUI
import AppKit

// MARK: - NSVisualEffectView Wrapper for HUD Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Compact Clipboard HUD Overlay View (10 Recent Items, No Category Tabs)

public struct ClipboardOverlayView: View {
    @ObservedObject var manager: ClipboardManager

    public init(manager: ClipboardManager) {
        self.manager = manager
    }

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                topSearchBar

                Divider().opacity(0.2)

                if manager.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    clipsListView
                }

                Divider().opacity(0.2)

                footerBar
            }
        }
        .frame(width: ClipboardManager.hudWidth, height: ClipboardManager.hudHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Top Search Bar

    private var topSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FS.title, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(tr("Tìm trong 10 mục gần nhất...", "Search last 10 clips..."), text: $manager.searchText)
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
        .padding(.vertical, 11)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Clips List View

    private var clipsListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 4) {
                    ForEach(Array(manager.filteredItems.enumerated()), id: \.element.id) { index, item in
                        clipRow(index: index, item: item)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollToTop(proxy)
            }
            .onChange(of: manager.scrollToTopToken) {
                scrollToTop(proxy)
            }
            .onChange(of: manager.searchText) {
                scrollToTop(proxy)
            }
            .onChange(of: manager.keyboardScrollTargetID) { _, targetID in
                guard let targetID else { return }
                if manager.selectedIndex == 0 {
                    scrollToTop(proxy)
                } else {
                    withTransaction(Transaction(animation: nil)) {
                        proxy.scrollTo(targetID)
                    }
                }
            }
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        if let firstID = manager.filteredItems.first?.id {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(firstID, anchor: .top)
            }
        }
        manager.resetHUDScrollToTop()
    }

    // MARK: - Single Clip Row

    private func clipRow(index: Int, item: ClipItem) -> some View {
        let isSelected = manager.selectedIndex == index
        let isHovered = manager.hoveredItemID == item.id

        return Button {
            manager.pasteItem(item)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                // Quick index indicator (1..9)
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 14)
                }

                // Content
                Group {
                    if item.type == .image, let nsImg = manager.previewImage(for: item) {
                        HStack(spacing: 8) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 120, maxHeight: 54)
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

                if item.isPinned && !isHovered && !isSelected {
                    Image(systemName: "pin.fill")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.orange)
                }

                if isHovered || isSelected {
                    HStack(spacing: 6) {
                        Button {
                            manager.togglePin(item)
                        } label: {
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(item.isPinned ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? tr("Bỏ ghim (⌥P)", "Unpin (⌥P)") : tr("Ghim (⌥P)", "Pin (⌥P)"))

                        Button {
                            manager.deleteItem(item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Xoá mục (⌥⌫)", "Delete item (⌥⌫)"))
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

            Text(tr("Sao chép (⌘C) văn bản, ảnh hoặc tệp để lưu tối đa 10 mục gần nhất.", "Copy (⌘C) text, images or files to keep up to 10 recent clips."))
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Footer Bar

    private var footerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                legendItem(key: "↵", label: tr("Dán", "Paste"))
                legendItem(key: "1–9", label: tr("Nhanh", "Quick"))
                legendItem(key: "⌥P", label: tr("Ghim", "Pin"))
                legendItem(key: "⌥⌫", label: tr("Xoá", "Delete"))
                legendItem(key: "⎋", label: tr("Đóng", "Close"))
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Text("\(manager.filteredItems.count)/\(ClipboardManager.maxItemsCount)")
                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Button(tr("Xoá hết", "Clear")) {
                    manager.clearAllHistory()
                }
                .font(.system(size: FS.caption, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.red.opacity(0.1)))
                .fixedSize()
            }
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
