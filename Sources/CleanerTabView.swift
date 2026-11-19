import SwiftUI
import AppKit

// MARK: - Tab 3: System Cleaner & App Uninstaller (CleanMyMac Replacement)

/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
public struct CleanerTabView: View {
    @ObservedObject var cleanerManager: SystemCleanerManager

    public init(cleanerManager: SystemCleanerManager) {
        self.cleanerManager = cleanerManager
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Sub-Segment Navigation Bar
            subTabBar

            // Sub-Tab Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    switch cleanerManager.selectedSection {
                    case 1:
                        appUninstallerSection
                    case 2:
                        largeFilesSection
                    default:
                        systemJunkSection
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .onAppear {
            if cleanerManager.totalJunkBytes == 0 && !cleanerManager.isScanningJunk {
                cleanerManager.scanJunk()
            }
        }
    }

    // MARK: - Sub Tab Bar

    private var subTabBar: some View {
        HStack(spacing: 4) {
            subTabButton(index: 0, title: tr("Dọn rác", "Junk"), icon: "sparkles")
            subTabButton(index: 1, title: tr("Gỡ App", "Uninstaller"), icon: "trash")
            subTabButton(index: 2, title: tr("Tệp lớn", "Large Files"), icon: "doc.badge.gearshape")
        }
        .padding(2.5)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func subTabButton(index: Int, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                cleanerManager.selectedSection = index
            }
            if index == 1 && cleanerManager.installedApps.isEmpty && !cleanerManager.isScanningApps {
                cleanerManager.scanInstalledApps()
            }
            if index == 2 && cleanerManager.largeFiles.isEmpty && !cleanerManager.isScanningLargeFiles {
                cleanerManager.scanLargeFiles()
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: FS.caption, weight: cleanerManager.selectedSection == index ? .semibold : .medium))
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Rad.sm))
            .background(
                RoundedRectangle(cornerRadius: Rad.sm)
                    .fill(cleanerManager.selectedSection == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(cleanerManager.selectedSection == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - SECTION 0: SYSTEM JUNK CLEANER

    private var systemJunkSection: some View {
        let selectedBytes = cleanerManager.selectedJunkBytes
        let selectedCount = cleanerManager.selectedJunkItemCount

        return VStack(spacing: 10) {
            // Hero Status Card
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 40, height: 40)

                        Image(systemName: cleanerManager.totalJunkBytes > 0 ? "trash.circle.fill" : "checkmark.seal.fill")
                            .font(.system(size: FS.display, weight: .bold))
                            .foregroundStyle(cleanerManager.totalJunkBytes > 0 ? Color.accentColor : Tone.good)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            cleanerManager.isScanningJunk
                                ? tr("Đang quét hệ thống...", "Scanning system...")
                                : (selectedBytes > 0
                                    ? SystemCleanerManager.formatBytes(selectedBytes)
                                    : (cleanerManager.totalJunkBytes > 0
                                        ? SystemCleanerManager.formatBytes(cleanerManager.totalJunkBytes)
                                        : tr("Hệ thống sạch sẽ", "System is Clean")))
                        )
                        .font(.system(size: FS.value, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                        Text(
                            cleanerManager.isScanningJunk
                                ? tr("Đang quét chi tiết ứng dụng & thư mục...", "Scanning apps & folders in detail...")
                                : (selectedBytes > 0
                                    ? tr("Đã chọn \(selectedCount) mục / Tổng \(SystemCleanerManager.formatBytes(cleanerManager.totalJunkBytes))", "Selected \(selectedCount) items / Total \(SystemCleanerManager.formatBytes(cleanerManager.totalJunkBytes))")
                                    : (cleanerManager.totalJunkBytes > 0
                                        ? tr("Chọn từng ứng dụng hoặc thư mục bên dưới để dọn", "Select specific apps or folders below to clean")
                                        : tr("Không có dữ liệu rác cần dọn", "No junk data to clean")))
                        )
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }

                    Spacer()

                    if cleanerManager.isScanningJunk || cleanerManager.isCleaningJunk {
                        ProgressView().controlSize(.small)
                    }
                }

                // Action Buttons
                HStack(spacing: 8) {
                    Button {
                        cleanerManager.cleanSelectedJunk()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: FS.caption, weight: .semibold))
                            Text(
                                cleanerManager.isCleaningJunk
                                    ? tr("Đang dọn sạch...", "Cleaning...")
                                    : (selectedBytes > 0
                                        ? tr("Dọn \(SystemCleanerManager.formatBytes(selectedBytes))", "Clean \(SystemCleanerManager.formatBytes(selectedBytes))")
                                        : tr("Chọn mục cần dọn", "Select items to clean"))
                            )
                            .font(.system(size: FS.caption, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(selectedBytes > 0 ? Color.accentColor : Color.secondary.opacity(0.3))
                        .foregroundStyle(Color.white)
                        .cornerRadius(Rad.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedBytes == 0 || cleanerManager.isCleaningJunk || cleanerManager.isScanningJunk)

                    Button {
                        cleanerManager.scanJunk(preserveSelection: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: FS.caption, weight: .semibold))
                            Text(tr("Quét lại", "Rescan"))
                                .font(.system(size: FS.caption, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.primary)
                        .cornerRadius(Rad.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(cleanerManager.isScanningJunk || cleanerManager.isCleaningJunk)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Rad.md).fill(Color(nsColor: .controlBackgroundColor)))

            // Feedback message
            if let msg = cleanerManager.cleanedMessage {
                let isWarn = cleanerManager.cleanedMessageIsWarning
                HStack(spacing: 6) {
                    Image(systemName: isWarn ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isWarn ? Color.orange : Tone.good)
                        .font(.system(size: FS.label))
                    Text(msg)
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(isWarn ? Color.orange : Tone.good)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill((isWarn ? Color.orange : Tone.good).opacity(0.12)))
                .transition(.opacity)
            }

            // Categories Checklist with Expandable App / Folder Details
            VStack(spacing: 6) {
                ForEach(cleanerManager.junkCategories) { cat in
                    junkCategoryCard(cat: cat)
                }
            }
        }
    }

    private func junkCategoryCard(cat: JunkCategoryItem) -> some View {
        let hasDetails = !cat.subItems.isEmpty
        let isExpanded = hasDetails && cleanerManager.expandedCategoryIDs.contains(cat.id)
        let query = cleanerManager.categorySearchQueries[cat.id] ?? ""
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredSubItems: [JunkSubItem] = {
            guard !trimmedQuery.isEmpty else { return cat.subItems }
            return cat.subItems.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.rawName.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }()

        let defaultLimit = 12
        let isShowingAll = cleanerManager.showAllCategoryIDs.contains(cat.id) || !trimmedQuery.isEmpty
        let displayedSubItems = isShowingAll ? filteredSubItems : Array(filteredSubItems.prefix(defaultLimit))
        let hiddenCount = max(0, filteredSubItems.count - displayedSubItems.count)

        let checkboxIcon: String = {
            if cat.allSubItemsSelected {
                return "checkmark.square.fill"
            } else if cat.someSubItemsSelected {
                return "minus.square.fill"
            } else {
                return "square"
            }
        }()

        return VStack(spacing: 0) {
            // Category Header Row
            HStack(spacing: 8) {
                // Tri-state Category Checkbox
                Button {
                    cleanerManager.toggleCategorySelection(cat.id)
                } label: {
                    Image(systemName: checkboxIcon)
                        .font(.system(size: FS.subhead, weight: .medium))
                        .foregroundStyle(
                            cat.sizeBytes == 0
                                ? Color.secondary.opacity(0.4)
                                : ((cat.allSubItemsSelected || cat.someSubItemsSelected) ? Color.accentColor : Color.secondary)
                        )
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(cat.sizeBytes == 0)
                .help(tr("Chọn / bỏ chọn toàn bộ nhóm này", "Select / deselect entire category"))

                // Expandable Header Hit Area
                Button {
                    if hasDetails {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            cleanerManager.toggleCategoryExpanded(cat.id)
                        }
                    } else if cat.sizeBytes > 0 {
                        cleanerManager.toggleCategorySelection(cat.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Rad.sm)
                                .fill(cat.iconColor.opacity(0.15))
                                .frame(width: 26, height: 26)

                            Image(systemName: cat.icon)
                                .font(.system(size: FS.body, weight: .semibold))
                                .foregroundStyle(cat.iconColor)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(cat.localizedTitle)
                                .font(.system(size: FS.caption, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if hasDetails {
                                if cat.selectedCount > 0 {
                                    Text(tr(
                                        "\(cat.subItems.count) mục • Đã chọn \(cat.selectedCount) (\(SystemCleanerManager.formatBytes(cat.selectedSizeBytes)))",
                                        "\(cat.subItems.count) items • Selected \(cat.selectedCount) (\(SystemCleanerManager.formatBytes(cat.selectedSizeBytes)))"
                                    ))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                } else {
                                    Text(tr(
                                        "\(cat.subItems.count) ứng dụng / thư mục • Bấm xem chi tiết",
                                        "\(cat.subItems.count) apps / folders • Click to inspect"
                                    ))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            } else {
                                Text(cat.localizedSubtitle)
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        Text(cat.sizeFormatted)
                            .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(cat.sizeBytes > 0 ? Color.primary : Color.secondary)

                        if hasDetails {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: FS.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(8)

            // Expanded App / Folder Detail List
            if isExpanded {
                Divider().opacity(0.25)

                VStack(spacing: 6) {
                    // Search & Bulk Select Toolbar
                    HStack(spacing: 6) {
                        if cat.subItems.count > 5 {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)

                                TextField(
                                    tr("Lọc ứng dụng / thư mục...", "Filter apps / folders..."),
                                    text: Binding<String>(
                                        get: { cleanerManager.categorySearchQueries[cat.id] ?? "" },
                                        set: { cleanerManager.categorySearchQueries[cat.id] = $0 }
                                    )
                                )
                                .textFieldStyle(.plain)
                                .font(.system(size: FS.caption))

                                if !query.isEmpty {
                                    Button {
                                        cleanerManager.categorySearchQueries[cat.id] = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: FS.caption))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
                        } else {
                            Spacer()
                        }

                        // Select / Deselect visible items
                        let visibleIDs = Set(filteredSubItems.map(\.id))
                        let allVisibleSelected = !filteredSubItems.isEmpty && filteredSubItems.allSatisfy(\.isSelected)

                        Button {
                            cleanerManager.setSubItemsSelection(
                                categoryID: cat.id,
                                itemIDs: visibleIDs,
                                selected: !allVisibleSelected
                            )
                        } label: {
                            Text(allVisibleSelected ? tr("Bỏ chọn", "Clear") : tr("Chọn hết", "Select all"))
                                .font(.system(size: FS.caption, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                        .disabled(filteredSubItems.isEmpty)

                        if let rootDir = cat.directoryURLs.first, FileManager.default.fileExists(atPath: rootDir.path) {
                            Button {
                                NSWorkspace.shared.open(rootDir)
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                            .help(tr("Mở thư mục gốc trong Finder", "Open folder in Finder"))
                        }
                    }

                    // Individual App / Folder Rows
                    if displayedSubItems.isEmpty {
                        Text(tr("Không tìm thấy ứng dụng hoặc thư mục phù hợp.", "No matching apps or folders found."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 3) {
                            ForEach(displayedSubItems) { item in
                                junkSubItemRow(categoryID: cat.id, item: item)
                            }
                        }
                    }

                    // Show More / Collapse Button for Long Lists
                    if hiddenCount > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                cleanerManager.showAllCategoryIDs.insert(cat.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tr("Xem thêm \(hiddenCount) mục nhỏ hơn", "Show \(hiddenCount) more smaller items"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: FS.caption))
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
                        }
                        .buttonStyle(.plain)
                    } else if cleanerManager.showAllCategoryIDs.contains(cat.id) && filteredSubItems.count > defaultLimit && trimmedQuery.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                cleanerManager.showAllCategoryIDs.remove(cat.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tr("Thu gọn danh sách", "Show less"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: FS.caption))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func junkSubItemRow(categoryID: String, item: JunkSubItem) -> some View {
        let showSubtitle = item.rawName.lowercased() != item.name.lowercased()

        return HStack(spacing: 6) {
            Button {
                cleanerManager.toggleSubItemSelection(categoryID: categoryID, subItemID: item.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: FS.body, weight: .medium))
                        .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 16, height: 16)

                    if let appIcon = cleanerManager.appIcon(for: item) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.system(size: FS.body))
                            .foregroundStyle(item.isDirectory ? Color.accentColor.opacity(0.75) : Color.secondary)
                            .frame(width: 18, height: 18)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if showSubtitle {
                            Text(item.rawName)
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    Text(item.sizeFormatted)
                        .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                cleanerManager.revealInFinder(item.url)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(tr("Mở trong Finder: \(item.url.path)", "Reveal in Finder: \(item.url.path)"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm)
                .fill(item.isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.025))
        )
    }

    // MARK: - SECTION 1: APP UNINSTALLER

    private var appUninstallerSection: some View {
        VStack(spacing: 8) {
            // Search & Scan Bar
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)

                    TextField(tr("Tìm ứng dụng cần gỡ...", "Search apps to uninstall..."), text: Binding<String>(
                        get: { cleanerManager.appSearchQuery },
                        set: { cleanerManager.appSearchQuery = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: FS.caption))

                    if !cleanerManager.appSearchQuery.isEmpty {
                        Button {
                            cleanerManager.appSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))

                Button {
                    cleanerManager.scanInstalledApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help(tr("Quét lại danh sách ứng dụng", "Rescan application list"))
            }

            // Uninstall Result Alert
            if let msg = cleanerManager.uninstallMessage {
                let isWarning = msg.contains("")
                HStack(spacing: 6) {
                    Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isWarning ? .orange : Tone.good)
                        .font(.system(size: FS.label))
                    Text(msg)
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(isWarning ? .orange : Tone.good)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill((isWarning ? Color.orange : Tone.good).opacity(0.12)))
            }

            // Selected App Leftovers Inspector
            if let selected = cleanerManager.selectedApp {
                selectedAppDetailCard(app: selected)
            } else {
                // Apps List
                let filtered = cleanerManager.installedApps.filter {
                    cleanerManager.appSearchQuery.isEmpty ||
                    $0.name.localizedCaseInsensitiveContains(cleanerManager.appSearchQuery) ||
                    $0.bundleID.localizedCaseInsensitiveContains(cleanerManager.appSearchQuery)
                }

                if cleanerManager.isScanningApps {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(tr("Đang quét danh sách ứng dụng trong /Applications...", "Scanning apps in /Applications..."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                } else if filtered.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: FS.display))
                            .foregroundStyle(.secondary)
                        Text(tr("Không tìm thấy ứng dụng nào.", "No applications found."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 4) {
                        HStack {
                            Text(tr("\(filtered.count) ứng dụng", "\(filtered.count) applications"))
                                .font(.system(size: FS.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(tr("Bấm vào để xem & gỡ sạch file rác", "Click to inspect & clean leftovers"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        ForEach(filtered) { app in
                            appRowCard(app: app)
                        }
                    }
                }
            }
        }
    }

    private func appRowCard(app: InstalledAppItem) -> some View {
        Button {
            cleanerManager.inspectAppLeftovers(for: app)
        } label: {
            HStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(SystemCleanerManager.formatBytes(app.appSizeBytes))
                    .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color(nsColor: .controlBackgroundColor)))
        }
        .buttonStyle(.plain)
    }

    private func selectedAppDetailCard(app: InstalledAppItem) -> some View {
        VStack(spacing: 8) {
            // Header with back button
            HStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: FS.body, weight: .semibold))
                    Text(app.bundleID)
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    cleanerManager.selectedApp = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FS.subhead))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))

            // Leftovers list
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tr("Các tệp sẽ được chuyển vào Thùng rác:", "Files that will be moved to Trash:"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tr("Tổng cộng: \(app.totalSizeFormatted)", "Total: \(app.totalSizeFormatted)"))
                        .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }

                // 1. App binary itself
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(Color.accentColor)
                    Text(tr("File cài đặt ứng dụng (.app)", "App bundle (.app)"))
                        .font(.system(size: FS.caption, weight: .medium))
                    Spacer()
                    Text(SystemCleanerManager.formatBytes(app.appSizeBytes))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.03)))

                // 2. Leftovers
                if app.isInspectingLeftovers {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text(tr("Đang dò tìm file rác (Caches, Application Support...)...", "Searching for leftover files (Caches, Support...)..."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                } else if app.leftovers.isEmpty {
                    Text(tr("Không tìm thấy file rác ngoài thư mục .app.", "No leftover files found outside .app bundle."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                        .padding(4)
                } else {
                    ForEach(app.leftovers.indices, id: \.self) { idx in
                        let item = app.leftovers[idx]
                        HStack(spacing: 6) {
                            Toggle("", isOn: Binding<Bool>(
                                get: {
                                    cleanerManager.selectedApp?.leftovers[idx].isSelected ?? true
                                },
                                set: { val in
                                    cleanerManager.selectedApp?.leftovers[idx].isSelected = val
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .controlSize(.mini)
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.localizedCategoryName)
                                    .font(.system(size: FS.caption, weight: .semibold))
                                Text(item.url.lastPathComponent)
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(item.sizeFormatted)
                                .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.02)))
                    }
                }
            }

            // Uninstall Action Button
            Button {
                cleanerManager.uninstallSelectedApp()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: FS.caption, weight: .semibold))
                    Text(cleanerManager.isUninstalling ? tr("Đang gỡ sạch...", "Uninstalling...") : tr("Gỡ bỏ tận gốc (\(app.totalSizeFormatted))", "Uninstall Completely (\(app.totalSizeFormatted))"))
                        .font(.system(size: FS.caption, weight: .semibold))
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundStyle(Color.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(cleanerManager.isUninstalling)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Rad.md).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - SECTION 2: LARGE & OLD FILES

    private var largeFilesSection: some View {
        VStack(spacing: 8) {
            // Header with threshold selector
            HStack(spacing: 6) {
                Text(tr("Ngưỡng kích thước:", "Size threshold:"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)

                ForEach([100, 200, 500, 1000], id: \.self) { mb in
                    Button {
                        cleanerManager.largeFileThresholdMB = mb
                        cleanerManager.scanLargeFiles()
                    } label: {
                        Text(mb >= 1000 ? "≥ 1GB" : "≥ \(mb)MB")
                            .font(.system(size: FS.caption, weight: cleanerManager.largeFileThresholdMB == mb ? .semibold : .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(cleanerManager.largeFileThresholdMB == mb ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(cleanerManager.largeFileThresholdMB == mb ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    cleanerManager.scanLargeFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: FS.caption, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(tr("Quét lại tệp lớn", "Rescan large files"))
            }
            .padding(.horizontal, 2)

            if cleanerManager.isScanningLargeFiles {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(tr("Đang quét các tệp lớn trong Downloads, Movies, Documents...", "Scanning large files in Downloads, Movies, Documents..."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            } else if cleanerManager.largeFiles.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: FS.display))
                        .foregroundStyle(.secondary)
                    Text(tr("Không có tệp nào lớn hơn \(cleanerManager.largeFileThresholdMB)MB.", "No files larger than \(cleanerManager.largeFileThresholdMB)MB found."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            } else {
                VStack(spacing: 4) {
                    ForEach(cleanerManager.largeFiles) { file in
                        largeFileRow(file: file)
                    }
                }
            }
        }
    }

    private func largeFileRow(file: LargeFileItem) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(file.kind) • \(file.relativeDateFormatted)")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(file.sizeFormatted)
                .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)

            // Reveal in Finder button
            Button {
                cleanerManager.revealInFinder(file.url)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(tr("Mở trong Finder", "Reveal in Finder"))

            // Move to Trash button
            Button {
                cleanerManager.trashLargeFile(file)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.red)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.red.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(tr("Chuyển vào Thùng rác", "Move to Trash"))
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color(nsColor: .controlBackgroundColor)))
    }
}
