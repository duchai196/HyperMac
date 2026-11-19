import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Models

public struct JunkSubItem: Identifiable, Equatable, Sendable {
    public let id: String          // Standardized file path
    public let name: String        // Friendly app name or folder/file name
    public let rawName: String     // Relative path / folder name inside category (e.g. "Google/Chrome", "com.spotify.client")
    public let url: URL
    public let appBundleURL: URL?  // Matched .app bundle URL for displaying the app icon
    public let isDirectory: Bool
    public var sizeBytes: Int64
    public var isSelected: Bool

    public var sizeFormatted: String {
        SystemCleanerManager.formatBytes(sizeBytes)
    }

    public static func == (lhs: JunkSubItem, rhs: JunkSubItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.sizeBytes == rhs.sizeBytes &&
        lhs.isSelected == rhs.isSelected
    }
}

public struct JunkCategoryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let iconColor: Color
    public var sizeBytes: Int64
    public var fileCount: Int
    public var isSelected: Bool
    public let directoryURLs: [URL]
    public var subItems: [JunkSubItem] = []

    public var sizeFormatted: String {
        SystemCleanerManager.formatBytes(sizeBytes)
    }

    public var selectedCount: Int {
        if subItems.isEmpty {
            return (isSelected && sizeBytes > 0) ? max(1, fileCount) : 0
        }
        return subItems.reduce(0) { $0 + ($1.isSelected ? 1 : 0) }
    }

    public var selectedSizeBytes: Int64 {
        if subItems.isEmpty {
            return isSelected ? sizeBytes : 0
        }
        return subItems.reduce(0) { $0 + ($1.isSelected ? $1.sizeBytes : 0) }
    }

    public var allSubItemsSelected: Bool {
        guard !subItems.isEmpty else { return isSelected && sizeBytes > 0 }
        return subItems.allSatisfy(\.isSelected)
    }

    public var someSubItemsSelected: Bool {
        guard !subItems.isEmpty else { return false }
        let count = selectedCount
        return count > 0 && count < subItems.count
    }

    public var localizedTitle: String {
        switch id {
        case "caches": return tr("Bộ nhớ đệm ứng dụng & web", "App & Web Caches")
        case "logs": return tr("Nhật ký & Báo cáo lỗi", "Logs & Crash Reports")
        case "trash": return tr("Thùng rác hệ thống (Trash)", "System Trash")
        case "developer": return tr("Dữ liệu rác lập trình viên (Xcode)", "Developer Junk (Xcode)")
        default: return title
        }
    }

    public var localizedSubtitle: String {
        switch id {
        case "caches": return tr("Cache Chrome, Safari, Spotify, Zalo, Adobe...", "Cache from Chrome, Safari, Spotify, Adobe...")
        case "logs": return tr("Các tệp .log, .crash tích tụ lâu ngày", "Accumulated .log and .crash files")
        case "trash": return tr("Các tệp đang nằm chờ dọn dẹp trong Thùng rác", "Files waiting in the Trash")
        case "developer": return tr("DerivedData và bộ nhớ build tạm", "DerivedData and build artifacts")
        default: return subtitle
        }
    }

    public static func == (lhs: JunkCategoryItem, rhs: JunkCategoryItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.sizeBytes == rhs.sizeBytes &&
        lhs.isSelected == rhs.isSelected &&
        lhs.fileCount == rhs.fileCount &&
        lhs.subItems == rhs.subItems
    }
}

public struct LeftoverFileItem: Identifiable, Equatable, Sendable {
    public let id: UUID = UUID()
    public let categoryName: String
    public let url: URL
    public let sizeBytes: Int64
    public var isSelected: Bool

    public var sizeFormatted: String {
        SystemCleanerManager.formatBytes(sizeBytes)
    }

    public var localizedCategoryName: String {
        switch categoryName {
        case "Bộ nhớ đệm (Caches)": return tr("Bộ nhớ đệm (Caches)", "App Caches")
        case "Cài đặt (Preferences)": return tr("Cài đặt (Preferences)", "Preferences")
        case "Trạng thái lưu (Saved State)": return tr("Trạng thái lưu (Saved State)", "Saved Application State")
        case "Nhật ký (Logs)": return tr("Nhật ký (Logs)", "Logs & Diagnostics")
        case "Application Support": return "Application Support"
        default: return categoryName
        }
    }

    public static func == (lhs: LeftoverFileItem, rhs: LeftoverFileItem) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected && lhs.sizeBytes == rhs.sizeBytes
    }
}

public struct InstalledAppItem: Identifiable, Equatable, Sendable {
    public let id: String // Bundle ID or path
    public let name: String
    public let bundleID: String
    public let appURL: URL
    public var appSizeBytes: Int64
    public var leftovers: [LeftoverFileItem] = []
    public var isInspectingLeftovers: Bool = false

    public var totalSizeBytes: Int64 {
        appSizeBytes + leftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }

    public var totalSizeFormatted: String {
        SystemCleanerManager.formatBytes(totalSizeBytes)
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    public static func == (lhs: InstalledAppItem, rhs: InstalledAppItem) -> Bool {
        lhs.id == rhs.id && lhs.totalSizeBytes == rhs.totalSizeBytes && lhs.leftovers.count == rhs.leftovers.count
    }
}

public struct LargeFileItem: Identifiable, Equatable, Sendable {
    public let id: UUID = UUID()
    public let name: String
    public let url: URL
    public let sizeBytes: Int64
    public let modificationDate: Date
    public let kind: String

    public var sizeFormatted: String {
        SystemCleanerManager.formatBytes(sizeBytes)
    }

    public var relativeDateFormatted: String {
        let elapsed = Date().timeIntervalSince(modificationDate)
        if elapsed < 86400 {
            return tr("Hôm nay", "Today")
        } else if elapsed < 86400 * 30 {
            let days = Int(elapsed / 86400)
            return tr("\(days) ngày trước", "\(days)d ago")
        } else if elapsed < 86400 * 365 {
            let months = Int(elapsed / (86400 * 30))
            return tr("\(months) tháng trước", "\(months)mo ago")
        } else {
            let years = Int(elapsed / (86400 * 365))
            return tr("\(years) năm trước", "\(years)y ago")
        }
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    public static func == (lhs: LargeFileItem, rhs: LargeFileItem) -> Bool {
        lhs.id == rhs.id && lhs.sizeBytes == rhs.sizeBytes
    }
}

// MARK: - System Cleaner Manager Singleton

@MainActor
public class SystemCleanerManager: ObservableObject {
    public static let shared = SystemCleanerManager()

    // Sub-segment navigation: 0: Dọn rác, 1: Gỡ ứng dụng, 2: Tệp lớn
    @Published public var selectedSection: Int = 0

    // 1. System Junk State
    @Published public var junkCategories: [JunkCategoryItem] = []
    @Published public var expandedCategoryIDs: Set<String> = ["caches"]
    @Published public var categorySearchQueries: [String: String] = [:]
    @Published public var showAllCategoryIDs: Set<String> = []
    @Published public var isScanningJunk: Bool = false
    @Published public var isCleaningJunk: Bool = false
    @Published public var totalJunkBytes: Int64 = 0
    @Published public var cleanedMessage: String? = nil
    @Published public var cleanedMessageIsWarning: Bool = false
    @Published public var lastCleanedTimestamp: Date? = nil

    private var iconCache: [String: NSImage] = [:]

    public var selectedJunkBytes: Int64 {
        junkCategories.reduce(0) { $0 + $1.selectedSizeBytes }
    }

    public var selectedJunkItemCount: Int {
        junkCategories.reduce(0) { $0 + $1.selectedCount }
    }

    public func appIcon(for subItem: JunkSubItem) -> NSImage? {
        guard let appURL = subItem.appBundleURL else { return nil }
        let key = appURL.path
        if let cached = iconCache[key] {
            return cached
        }
        let img = NSWorkspace.shared.icon(forFile: key)
        iconCache[key] = img
        return img
    }

    public func toggleCategoryExpanded(_ categoryID: String) {
        if expandedCategoryIDs.contains(categoryID) {
            expandedCategoryIDs.remove(categoryID)
        } else {
            expandedCategoryIDs.insert(categoryID)
        }
    }

    public func toggleCategorySelection(_ categoryID: String) {
        guard let idx = junkCategories.firstIndex(where: { $0.id == categoryID }) else { return }
        if junkCategories[idx].subItems.isEmpty {
            guard junkCategories[idx].sizeBytes > 0 else { return }
            junkCategories[idx].isSelected.toggle()
        } else {
            let selectAll = !junkCategories[idx].allSubItemsSelected
            for subIdx in junkCategories[idx].subItems.indices {
                junkCategories[idx].subItems[subIdx].isSelected = selectAll
            }
            junkCategories[idx].isSelected = selectAll
        }
    }

    public func setSubItemsSelection(categoryID: String, itemIDs: Set<String>, selected: Bool) {
        guard let idx = junkCategories.firstIndex(where: { $0.id == categoryID }) else { return }
        for subIdx in junkCategories[idx].subItems.indices {
            if itemIDs.contains(junkCategories[idx].subItems[subIdx].id) {
                junkCategories[idx].subItems[subIdx].isSelected = selected
            }
        }
        junkCategories[idx].isSelected = junkCategories[idx].allSubItemsSelected
    }

    public func toggleSubItemSelection(categoryID: String, subItemID: String) {
        guard let catIdx = junkCategories.firstIndex(where: { $0.id == categoryID }),
              let subIdx = junkCategories[catIdx].subItems.firstIndex(where: { $0.id == subItemID }) else { return }
        junkCategories[catIdx].subItems[subIdx].isSelected.toggle()
        junkCategories[catIdx].isSelected = junkCategories[catIdx].allSubItemsSelected
    }

    // 2. App Uninstaller State
    @Published public var installedApps: [InstalledAppItem] = []
    @Published public var isScanningApps: Bool = false
    @Published public var appSearchQuery: String = ""
    @Published public var selectedApp: InstalledAppItem? = nil
    @Published public var isUninstalling: Bool = false
    @Published public var uninstallMessage: String? = nil

    // 3. Large Files State
    @Published public var largeFiles: [LargeFileItem] = []
    @Published public var isScanningLargeFiles: Bool = false
    @Published public var largeFileThresholdMB: Int = 200 // Default > 200MB

    private init() {
        // Prepare initial empty categories
        setupDefaultJunkCategories()
    }

    // MARK: - Utilities

    nonisolated public static func formatBytes(_ bytes: Int64) -> String {
        let b = Double(max(0, bytes))
        if b >= 1024 * 1024 * 1024 {
            return String(format: "%.2f GB", b / (1024 * 1024 * 1024))
        } else if b >= 1024 * 1024 {
            return String(format: "%.1f MB", b / (1024 * 1024))
        } else if b >= 1024 {
            return String(format: "%.0f KB", b / 1024)
        } else {
            return "\(bytes) B"
        }
    }

    nonisolated private static func calculateSize(at url: URL) -> (bytes: Int64, files: Int) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return (0, 0) }

        if !isDir.boolValue {
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return (size, 1)
        }

        // Fast directory size using system du (written in C, low-level syscalls)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let out = String(data: data, encoding: .utf8),
               let kbStr = out.split(separator: "\t").first,
               let kb = Int64(kbStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return (kb * 1024, 1)
            }
        } catch {}

        return (0, 0)
    }

    // MARK: - SECTION 1: SYSTEM JUNK CLEANER

    private static let vendorContainerNames: Set<String> = [
        "google", "adobe", "microsoft", "jetbrains", "mozilla",
        "bravesoftware", "vivaldi", "opera software", "tencent",
        "bytedance", "autodesk"
    ]

    private struct AppLookupIndex: @unchecked Sendable {
        var byBundleID: [String: (name: String, url: URL)] = [:]
        var byNormalizedName: [String: (name: String, url: URL)] = [:]
        var workspaceCache: [String: (name: String, url: URL)?] = [:]

        static func normalize(_ raw: String) -> String {
            String(raw.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }

        static func build() -> AppLookupIndex {
            var index = AppLookupIndex()
            let fm = FileManager.default
            let appDirs = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities"),
                fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]

            for dir in appDirs {
                guard let contents = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for url in contents where url.pathExtension == "app" {
                    let bundle = Bundle(url: url)
                    let fileBaseName = url.deletingPathExtension().lastPathComponent
                    let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? fileBaseName

                    if let bid = bundle?.bundleIdentifier?.lowercased(), !bid.isEmpty {
                        index.byBundleID[bid] = (displayName, url)
                    }
                    let normDisplay = normalize(displayName)
                    if normDisplay.count >= 3, index.byNormalizedName[normDisplay] == nil {
                        index.byNormalizedName[normDisplay] = (displayName, url)
                    }
                    let normFile = normalize(fileBaseName)
                    if normFile.count >= 3, index.byNormalizedName[normFile] == nil {
                        index.byNormalizedName[normFile] = (displayName, url)
                    }
                }
            }
            return index
        }

        mutating func resolve(folderName: String, vendorName: String?, categoryID: String) -> (name: String, appURL: URL?) {
            // Xcode DerivedData folder naming: ProjectName-<28 lowercase letters>
            if categoryID == "developer", let dashIdx = folderName.lastIndex(of: "-") {
                let suffix = folderName[folderName.index(after: dashIdx)...]
                if suffix.count == 28 && suffix.allSatisfy({ $0 >= "a" && $0 <= "z" }) {
                    let projectName = String(folderName[..<dashIdx])
                    if !projectName.isEmpty {
                        return (projectName, nil)
                    }
                }
            }

            let lower = folderName.lowercased()
            if let hit = byBundleID[lower] {
                return (hit.name, hit.url)
            }

            // Strip common updater/helper suffixes from bundle-id-like folders
            let suffixes = [".shipit", ".helper", ".renderer", ".gpu", ".cache", "-cache"]
            for suffix in suffixes where lower.hasSuffix(suffix) {
                let trimmed = String(lower.dropLast(suffix.count))
                if let hit = byBundleID[trimmed] {
                    return (hit.name, hit.url)
                }
            }

            // Query LaunchServices for bundle-id-like folder names
            if folderName.contains(".") && !folderName.hasPrefix(".") {
                if let cached = workspaceCache[lower] {
                    if let hit = cached { return (hit.name, hit.url) }
                } else {
                    var found: (name: String, url: URL)? = nil
                    let candidates: [String] = [folderName] + suffixes.compactMap { suffix in
                        lower.hasSuffix(suffix) ? String(folderName.dropLast(suffix.count)) : nil
                    }
                    for candidate in candidates {
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) {
                            let bundle = Bundle(url: appURL)
                            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                                ?? appURL.deletingPathExtension().lastPathComponent
                            found = (displayName, appURL)
                            break
                        }
                    }
                    workspaceCache[lower] = found
                    if let hit = found {
                        return (hit.name, hit.url)
                    }
                }
            }

            // Vendor + child name matching (e.g. Google + Chrome -> Google Chrome)
            if let vendor = vendorName {
                let combinedNorm = Self.normalize("\(vendor) \(folderName)")
                if combinedNorm.count >= 4, let hit = byNormalizedName[combinedNorm] {
                    return (hit.name, hit.url)
                }
            }

            // Direct normalized name match
            let normFolder = Self.normalize(folderName)
            if normFolder.count >= 3, let hit = byNormalizedName[normFolder] {
                return (hit.name, hit.url)
            }

            return (folderName, nil)
        }
    }

    nonisolated private static func measureChildDirectories(in dir: URL) -> [String: Int64] {
        var result: [String: Int64] = [:]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-k", "-d", "1", dir.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let out = String(data: data, encoding: .utf8) else { return result }
            let rootStdPath = dir.standardizedFileURL.path
            for line in out.split(whereSeparator: \.isNewline) {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2,
                      let kb = Int64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
                let pathStr = String(parts[1])
                let url = URL(fileURLWithPath: pathStr)
                if url.standardizedFileURL.path == rootStdPath { continue }
                result[url.lastPathComponent] = kb * 1024
            }
        } catch {}

        return result
    }

    nonisolated private static func scanDirectorySubItems(
        in dir: URL,
        categoryID: String,
        appIndex: inout AppLookupIndex,
        previouslySelectedIDs: Set<String>
    ) -> [JunkSubItem] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return [] }

        let dirSizes = measureChildDirectories(in: dir)
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else { return [] }

        var subItems: [JunkSubItem] = []

        for itemURL in contents {
            let childName = itemURL.lastPathComponent
            if childName == ".DS_Store" { continue }

            let res = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey])
            let isSymlink = res?.isSymbolicLink ?? false
            let isDir = (res?.isDirectory ?? false) && !isSymlink

            // Expand well-known multi-app vendor folders (e.g. Google/Chrome, Adobe/...) 1 level deep
            if (categoryID == "caches" || categoryID == "logs"),
               isDir,
               vendorContainerNames.contains(childName.lowercased()),
               let vendorChildren = try? fm.contentsOfDirectory(
                    at: itemURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                    options: []
               ),
               !vendorChildren.isEmpty {

                let vendorDirSizes = measureChildDirectories(in: itemURL)
                var addedFromVendor = 0

                for subURL in vendorChildren {
                    let subName = subURL.lastPathComponent
                    if subName == ".DS_Store" { continue }
                    let subRes = try? subURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey])
                    let subIsSymlink = subRes?.isSymbolicLink ?? false
                    let subIsDir = (subRes?.isDirectory ?? false) && !subIsSymlink

                    let bytes: Int64
                    if subIsDir {
                        bytes = vendorDirSizes[subName] ?? calculateSize(at: subURL).bytes
                    } else {
                        bytes = Int64(subRes?.totalFileAllocatedSize ?? subRes?.fileSize ?? 0)
                    }
                    guard bytes > 0 else { continue }

                    let resolved = appIndex.resolve(folderName: subName, vendorName: childName, categoryID: categoryID)
                    let stdPath = subURL.standardizedFileURL.path
                    subItems.append(JunkSubItem(
                        id: stdPath,
                        name: resolved.name,
                        rawName: "\(childName)/\(subName)",
                        url: subURL,
                        appBundleURL: resolved.appURL,
                        isDirectory: subIsDir,
                        sizeBytes: bytes,
                        isSelected: previouslySelectedIDs.contains(stdPath)
                    ))
                    addedFromVendor += 1
                }

                if addedFromVendor > 0 {
                    continue
                }
            }

            let bytes: Int64
            if isDir {
                bytes = dirSizes[childName] ?? calculateSize(at: itemURL).bytes
            } else {
                bytes = Int64(res?.totalFileAllocatedSize ?? res?.fileSize ?? 0)
            }
            guard bytes > 0 else { continue }

            let resolved = appIndex.resolve(folderName: childName, vendorName: nil, categoryID: categoryID)
            let stdPath = itemURL.standardizedFileURL.path
            subItems.append(JunkSubItem(
                id: stdPath,
                name: resolved.name,
                rawName: childName,
                url: itemURL,
                appBundleURL: resolved.appURL,
                isDirectory: isDir,
                sizeBytes: bytes,
                isSelected: previouslySelectedIDs.contains(stdPath)
            ))
        }

        subItems.sort { $0.sizeBytes > $1.sizeBytes }
        return subItems
    }

    private func setupDefaultJunkCategories() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cachesURL = home.appendingPathComponent("Library/Caches")
        let logsURL = home.appendingPathComponent("Library/Logs")
        let trashURL = home.appendingPathComponent(".Trash")
        let derivedDataURL = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")

        self.junkCategories = [
            JunkCategoryItem(
                id: "caches",
                title: "Bộ nhớ đệm ứng dụng & web",
                subtitle: "Cache Chrome, Safari, Spotify, Zalo, Adobe...",
                icon: "globe.americas.fill",
                iconColor: .secondary,
                sizeBytes: 0,
                fileCount: 0,
                isSelected: false,
                directoryURLs: [cachesURL]
            ),
            JunkCategoryItem(
                id: "logs",
                title: "Nhật ký & Báo cáo lỗi",
                subtitle: "Các tệp .log, .crash tích tụ lâu ngày",
                icon: "doc.text.fill",
                iconColor: .secondary,
                sizeBytes: 0,
                fileCount: 0,
                isSelected: false,
                directoryURLs: [logsURL]
            ),
            JunkCategoryItem(
                id: "trash",
                title: "Thùng rác hệ thống (Trash)",
                subtitle: "Các tệp đang nằm chờ dọn dẹp trong Thùng rác",
                icon: "trash.fill",
                iconColor: .secondary,
                sizeBytes: 0,
                fileCount: 0,
                isSelected: false,
                directoryURLs: [trashURL]
            ),
            JunkCategoryItem(
                id: "developer",
                title: "Dữ liệu rác lập trình viên (Xcode)",
                subtitle: "DerivedData và bộ nhớ build tạm",
                icon: "hammer.fill",
                iconColor: .secondary,
                sizeBytes: 0,
                fileCount: 0,
                isSelected: false,
                directoryURLs: [derivedDataURL]
            )
        ]
    }

    nonisolated private static func getTrashSizeKB() -> Int64 {
        let script = """
        tell application "Finder"
            set totalSize to 0.0
            try
                set sList to size of every item of trash
                repeat with s in sList
                    if contents of s is not missing value then
                        set totalSize to totalSize + (contents of s as real)
                    end if
                end repeat
            end try
            return ((round totalSize) div 1024) as string
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let out = String(data: data, encoding: .utf8),
               let kb = Int64(out.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(0, kb)
            }
        } catch {}
        return 0
    }

    nonisolated private static func emptyTrashViaFinder() {
        let script = "tell application \"Finder\" to empty trash"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
        process.waitUntilExit()
    }

    public func scanJunk(preserveSelection: Bool = false, clearMessage: Bool = true) {
        guard !isScanningJunk else { return }
        isScanningJunk = true
        if clearMessage {
            cleanedMessage = nil
            cleanedMessageIsWarning = false
        }

        let categoriesToScan = self.junkCategories
        let previouslySelectedSubIDs: Set<String> = preserveSelection
            ? Set(categoriesToScan.flatMap { $0.subItems.filter(\.isSelected).map(\.id) })
            : []
        let previouslySelectedTrash = preserveSelection && (categoriesToScan.first(where: { $0.id == "trash" })?.isSelected ?? false)

        DispatchQueue.global(qos: .userInitiated).async {
            let baseAppIndex = AppLookupIndex.build()
            let group = DispatchGroup()
            let lock = NSLock()
            var categoryResults: [String: (bytes: Int64, files: Int, subItems: [JunkSubItem])] = [:]

            for cat in categoriesToScan {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    var localAppIndex = baseAppIndex
                    var catBytes: Int64 = 0
                    var catFiles = 0
                    var catSubItems: [JunkSubItem] = []

                    if cat.id == "trash" {
                        let kb = Self.getTrashSizeKB()
                        catBytes = kb * 1024
                        catFiles = kb > 0 ? 1 : 0
                    } else {
                        for dir in cat.directoryURLs {
                            let items = Self.scanDirectorySubItems(
                                in: dir,
                                categoryID: cat.id,
                                appIndex: &localAppIndex,
                                previouslySelectedIDs: previouslySelectedSubIDs
                            )
                            catSubItems.append(contentsOf: items)
                        }
                        catSubItems.sort { $0.sizeBytes > $1.sizeBytes }
                        catBytes = catSubItems.reduce(0) { $0 + $1.sizeBytes }
                        catFiles = catSubItems.count
                    }

                    lock.lock()
                    categoryResults[cat.id] = (catBytes, catFiles, catSubItems)
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            var grandTotal: Int64 = 0
            var updatedCategories: [JunkCategoryItem] = []

            for cat in categoriesToScan {
                var updated = cat
                if let res = categoryResults[cat.id] {
                    updated.sizeBytes = res.bytes
                    updated.fileCount = res.files
                    updated.subItems = res.subItems
                    if cat.id == "trash" {
                        updated.isSelected = previouslySelectedTrash && res.bytes > 0
                    } else {
                        updated.isSelected = !res.subItems.isEmpty && res.subItems.allSatisfy(\.isSelected)
                    }
                }
                grandTotal += updated.sizeBytes
                updatedCategories.append(updated)
            }

            DispatchQueue.main.async {
                self.junkCategories = updatedCategories
                self.totalJunkBytes = grandTotal
                self.isScanningJunk = false
                appLog("🧹 SystemCleaner: Scanned \(Self.formatBytes(grandTotal)) of system junk.")
            }
        }
    }

    public func cleanSelectedJunk() {
        guard !isCleaningJunk else { return }
        guard selectedJunkBytes > 0 else { return }

        isCleaningJunk = true
        cleanedMessage = nil
        cleanedMessageIsWarning = false

        let categoriesSnapshot = self.junkCategories

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var actualFreedBytes: Int64 = 0
            var deletedCount = 0
            var skippedCount = 0

            for cat in categoriesSnapshot {
                if cat.id == "trash" {
                    if cat.isSelected && cat.sizeBytes > 0 {
                        Self.emptyTrashViaFinder()
                        actualFreedBytes += cat.sizeBytes
                        deletedCount += 1
                    }
                } else {
                    let chosenItems = cat.subItems.filter(\.isSelected)
                    for sub in chosenItems {
                        do {
                            try fm.removeItem(at: sub.url)
                            actualFreedBytes += sub.sizeBytes
                            deletedCount += 1
                        } catch {
                            // If removing the root folder fails (e.g. app running or SIP protected),
                            // try deleting removable contents inside it.
                            var freedFromChildren: Int64 = 0
                            if sub.isDirectory,
                               let children = try? fm.contentsOfDirectory(at: sub.url, includingPropertiesForKeys: nil) {
                                var removedAny = false
                                for child in children {
                                    if (try? fm.removeItem(at: child)) != nil {
                                        removedAny = true
                                    }
                                }
                                if removedAny {
                                    let (remainingBytes, _) = Self.calculateSize(at: sub.url)
                                    freedFromChildren = max(0, sub.sizeBytes - remainingBytes)
                                }
                            }

                            if freedFromChildren > 0 {
                                actualFreedBytes += freedFromChildren
                                deletedCount += 1
                            } else {
                                skippedCount += 1
                            }
                        }
                    }
                }
            }

            if actualFreedBytes > 0 {
                NSSound(named: "Glass")?.play()
            }

            DispatchQueue.main.async {
                self.isCleaningJunk = false
                self.lastCleanedTimestamp = Date()
                if actualFreedBytes > 0 {
                    let freedStr = Self.formatBytes(actualFreedBytes)
                    self.cleanedMessageIsWarning = false
                    if skippedCount > 0 {
                        self.cleanedMessage = tr(
                            "🎉 Đã dọn \(freedStr) (\(deletedCount) mục). Bỏ qua \(skippedCount) mục được hệ thống bảo vệ.",
                            "🎉 Cleaned \(freedStr) (\(deletedCount) items). Skipped \(skippedCount) protected items."
                        )
                    } else {
                        self.cleanedMessage = tr(
                            "🎉 Đã dọn sạch thành công \(freedStr) (\(deletedCount) mục)!",
                            "🎉 Successfully cleaned \(freedStr) (\(deletedCount) items)!"
                        )
                    }
                    appLog("✨ SystemCleaner: Cleaned \(freedStr) (\(deletedCount) items, skipped \(skippedCount))")
                } else {
                    self.cleanedMessageIsWarning = true
                    self.cleanedMessage = tr(
                        "Không thể xoá mục đã chọn (đang được ứng dụng sử dụng hoặc macOS bảo vệ).",
                        "Could not delete selected items (in use or protected by macOS)."
                    )
                    appLog("⚠️ SystemCleaner: Could not delete selected items (skipped \(skippedCount))")
                }
                // Re-scan to update counters while keeping the feedback message visible
                self.scanJunk(preserveSelection: false, clearMessage: false)
            }
        }
    }

    // MARK: - SECTION 2: APP UNINSTALLER (AppCleaner Style)

    public func scanInstalledApps() {
        guard !isScanningApps else { return }
        isScanningApps = true
        uninstallMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let appsDirs = [
                URL(fileURLWithPath: "/Applications"),
                fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]

            var list: [InstalledAppItem] = []

            for dir in appsDirs {
                guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for url in contents where url.pathExtension == "app" {
                    // Skip system apps protected by macOS
                    let path = url.path
                    if path.hasPrefix("/System/") { continue }

                    let bundle = Bundle(url: url)
                    let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent

                    let bid = bundle?.bundleIdentifier ?? "unknown.\(url.deletingPathExtension().lastPathComponent)"

                    // Skip Apple core utilities that shouldn't be uninstalled
                    if bid == "com.apple.finder" || bid == "com.apple.Safari" || bid == "com.apple.SystemPreferences" {
                        continue
                    }

                    // Fast app bundle size
                    let (appSize, _) = Self.calculateSize(at: url)

                    let item = InstalledAppItem(
                        id: bid,
                        name: name,
                        bundleID: bid,
                        appURL: url,
                        appSizeBytes: appSize
                    )
                    list.append(item)
                }
            }

            // Sort by size descending
            list.sort { $0.appSizeBytes > $1.appSizeBytes }

            DispatchQueue.main.async {
                self.installedApps = list
                self.isScanningApps = false
                appLog("📦 AppUninstaller: Found \(list.count) user applications.")
            }
        }
    }

    public func inspectAppLeftovers(for app: InstalledAppItem) {
        self.selectedApp = app
        var targetApp = app
        targetApp.isInspectingLeftovers = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let bid = app.bundleID.lowercased()
            let appName = app.name.lowercased()

            let searchDirs: [(name: String, dir: URL)] = [
                ("Application Support", home.appendingPathComponent("Library/Application Support")),
                ("Bộ nhớ đệm (Caches)", home.appendingPathComponent("Library/Caches")),
                ("Cài đặt (Preferences)", home.appendingPathComponent("Library/Preferences")),
                ("Trạng thái lưu (Saved State)", home.appendingPathComponent("Library/Saved Application State")),
                ("Containers", home.appendingPathComponent("Library/Containers")),
                ("Group Containers", home.appendingPathComponent("Library/Group Containers")),
                ("Nhật ký (Logs)", home.appendingPathComponent("Library/Logs")),
                ("WebKit Data", home.appendingPathComponent("Library/WebKit")),
                ("HTTPStorages", home.appendingPathComponent("Library/HTTPStorages"))
            ]

            var leftovers: [LeftoverFileItem] = []

            let appSubname = app.bundleID.split(separator: ".").last.map(String.init)?.lowercased() ?? appName

            func checkMatch(name: String) -> Bool {
                let lower = name.lowercased()
                if bid != "unknown" && lower.contains(bid) { return true }
                if appName.count > 3 && (lower == appName || lower.hasPrefix(appName + ".") || lower.hasPrefix(appName + "-") || lower.hasSuffix("." + appName)) {
                    return true
                }
                if appSubname.count > 3 && lower == appSubname {
                    return true
                }
                return false
            }

            for target in searchDirs {
                guard let contents = try? fm.contentsOfDirectory(at: target.dir, includingPropertiesForKeys: nil) else { continue }
                for url in contents {
                    let last = url.lastPathComponent
                    let isMatch = checkMatch(name: last)

                    if isMatch {
                        let (size, _) = Self.calculateSize(at: url)
                        let leftover = LeftoverFileItem(
                            categoryName: target.name,
                            url: url,
                            sizeBytes: size,
                            isSelected: true
                        )
                        leftovers.append(leftover)
                    } else if (target.name == "Application Support" || target.name == "Bộ nhớ đệm (Caches)") {
                        // Check 1 level deep inside vendor subdirectories (e.g. Google/Chrome, Microsoft/Word)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            if let subcontents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                                for subUrl in subcontents {
                                    if checkMatch(name: subUrl.lastPathComponent) {
                                        let (subSize, _) = Self.calculateSize(at: subUrl)
                                        let leftover = LeftoverFileItem(
                                            categoryName: "\(target.name)/\(last)",
                                            url: subUrl,
                                            sizeBytes: subSize,
                                            isSelected: true
                                        )
                                        leftovers.append(leftover)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                targetApp.leftovers = leftovers
                targetApp.isInspectingLeftovers = false
                self.selectedApp = targetApp
                if let idx = self.installedApps.firstIndex(where: { $0.id == app.id }) {
                    self.installedApps[idx] = targetApp
                }
                appLog("🔍 Leftovers for \(app.name): \(leftovers.count) item(s) found.")
            }
        }
    }

    public func uninstallSelectedApp() {
        guard let app = selectedApp, !isUninstalling else { return }
        isUninstalling = true
        uninstallMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var leftoversFreed: Int64 = 0

            // 1. Move leftover files to Trash
            for leftover in app.leftovers where leftover.isSelected {
                do {
                    try fm.trashItem(at: leftover.url, resultingItemURL: nil)
                    leftoversFreed += leftover.sizeBytes
                } catch {
                    do {
                        try fm.removeItem(at: leftover.url)
                        leftoversFreed += leftover.sizeBytes
                    } catch {
                        // Fallback: Finder delete
                        let script = "tell application \"Finder\" to delete POSIX file \"\(leftover.url.path)\""
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                        process.arguments = ["-e", script]
                        try? process.run()
                        process.waitUntilExit()
                        if !fm.fileExists(atPath: leftover.url.path) {
                            leftoversFreed += leftover.sizeBytes
                        }
                    }
                }
            }

            // 2. Move app bundle to Trash
            var appDeleted = false
            do {
                try fm.trashItem(at: app.appURL, resultingItemURL: nil)
                appDeleted = true
            } catch {
                do {
                    try fm.removeItem(at: app.appURL)
                    appDeleted = true
                } catch {
                    // Fallback for root-owned applications (e.g. OneDrive, MS Office): tell Finder to delete
                    let script = "tell application \"Finder\" to delete POSIX file \"\(app.appURL.path)\""
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    try? process.run()
                    process.waitUntilExit()
                    if !fm.fileExists(atPath: app.appURL.path) {
                        appDeleted = true
                    } else {
                        appLog("⚠️ Could not trash app bundle even via Finder: \(app.appURL.path)")
                    }
                }
            }

            NSSound(named: "Trash")?.play()

            DispatchQueue.main.async {
                self.isUninstalling = false
                if appDeleted {
                    let totalFreed = leftoversFreed + app.appSizeBytes
                    let freedStr = Self.formatBytes(totalFreed)
                    self.uninstallMessage = tr("🗑️ Đã gỡ sạch \(app.name) và giải phóng \(freedStr)!", "🗑️ Completely removed \(app.name) and freed \(freedStr)!")
                    self.installedApps.removeAll { $0.id == app.id }
                    self.selectedApp = nil
                } else {
                    let freedStr = Self.formatBytes(leftoversFreed)
                    self.uninstallMessage = tr("Không thể xóa file .app (yêu cầu quyền quản trị macOS). Đã dọn sạch \(freedStr) tệp rác liên quan.", "Could not delete .app bundle (admin privileges required). Cleaned \(freedStr) leftover files.")
                }
                appLog("✨ AppUninstaller: Uninstalled \(app.name), appDeleted=\(appDeleted)")
            }
        }
    }

    // MARK: - SECTION 3: LARGE & OLD FILES

    public func scanLargeFiles() {
        guard !isScanningLargeFiles else { return }
        isScanningLargeFiles = true

        let thresholdBytes = Int64(largeFileThresholdMB) * 1024 * 1024

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let scanDirs = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Movies"),
                home.appendingPathComponent("Documents")
            ]

            var found: [LargeFileItem] = []

            for dir in scanDirs {
                guard let enumerator = fm.enumerator(
                    at: dir,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                       res.isRegularFile == true, let size = res.fileSize, Int64(size) >= thresholdBytes {

                        let ext = fileURL.pathExtension.uppercased()
                        let kind = ext.isEmpty ? "Tệp tin" : "\(ext) File"

                        let item = LargeFileItem(
                            name: fileURL.lastPathComponent,
                            url: fileURL,
                            sizeBytes: Int64(size),
                            modificationDate: res.contentModificationDate ?? Date(),
                            kind: kind
                        )
                        found.append(item)
                    }
                }
            }

            // Sort descending by size
            found.sort { $0.sizeBytes > $1.sizeBytes }

            DispatchQueue.main.async {
                self.largeFiles = found
                self.isScanningLargeFiles = false
                appLog("📂 LargeFiles: Found \(found.count) large files > \(self.largeFileThresholdMB)MB.")
            }
        }
    }

    public func trashLargeFile(_ item: LargeFileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            self.largeFiles.removeAll { $0.id == item.id }
            NSSound(named: "Pop")?.play()
            appLog("🗑️ LargeFiles: Trashed \(item.name)")
        } catch {
            appLog("⚠️ LargeFiles: Failed to trash \(item.name): \(error.localizedDescription)")
        }
    }

    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
