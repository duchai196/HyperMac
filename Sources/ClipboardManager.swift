import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Clipboard Item Model

public enum ClipType: String, Codable, CaseIterable, Sendable {
    case all = "all"
    case text = "text"
    case rtf = "rtf"
    case image = "image"
    case file = "file"
    case color = "color"
    case url = "url"
}

public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: ClipType
    public var title: String
    public var detail: String
    public var plainText: String?
    public var rtfData: Data?
    public var imageData: Data?
    public var imageFileName: String?
    public var fileURLs: [String]?
    public var colorHex: String?
    public var sourceAppName: String?
    public var sourceBundleID: String?
    public let timestamp: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        type: ClipType,
        title: String,
        detail: String,
        plainText: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        imageFileName: String? = nil,
        fileURLs: [String]? = nil,
        colorHex: String? = nil,
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.plainText = plainText
        self.rtfData = rtfData
        self.imageData = imageData
        self.imageFileName = imageFileName
        self.fileURLs = fileURLs
        self.colorHex = colorHex
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    public static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        lhs.id == rhs.id && lhs.isPinned == rhs.isPinned && lhs.title == rhs.title
    }
}

// MARK: - Lightweight Clipboard Manager (Max 10 Recent Items)

@MainActor
public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    /// Hard cap: only keep the 10 most recent clipboard records for minimal RAM usage.
    public static let maxItemsCount: Int = 10
    public static let hudWidth: CGFloat = 480
    public static let hudHeight: CGFloat = 440

    // Published State
    @Published public var items: [ClipItem] = []
    @Published public var isMonitoringEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isMonitoringEnabled, forKey: "clipboard_monitoring_enabled")
            gIsClipboardEnabled = isMonitoringEnabled
            if isMonitoringEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    @Published public var ignoreConcealedTypes: Bool = true {
        didSet { UserDefaults.standard.set(ignoreConcealedTypes, forKey: "clipboard_ignore_concealed") }
    }
    @Published public var isHUDVisible: Bool = false
    @Published public var selectedIndex: Int = 0
    @Published public var searchText: String = "" {
        didSet {
            gIsClipboardSearchEmpty = searchText.isEmpty
            clampSelection()
        }
    }
    @Published public var hoveredItemID: UUID? = nil
    @Published public var scrollToTopToken: Int = 0
    @Published public var keyboardScrollTargetID: UUID? = nil

    // Internal State
    private var lastChangeCount: Int = 0
    private var suppressChangeCount: Int = 0
    private var pollTimer: Timer?
    private var previousApp: NSRunningApplication?
    private var hudPanel: NSPanel?
    private var hudShownTimestamp: Date = .distantPast
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var focusObservers: [NSObjectProtocol] = []
    private var previewImageCache: [UUID: NSImage] = [:]
    private let storageURL: URL
    public let imagesDirURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let hypermacDir = appSupport.appendingPathComponent("HyperMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: hypermacDir, withIntermediateDirectories: true)
        self.storageURL = hypermacDir.appendingPathComponent("clipboard.json")
        self.imagesDirURL = hypermacDir.appendingPathComponent("ClipboardImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.imagesDirURL, withIntermediateDirectories: true)

        if UserDefaults.standard.object(forKey: "clipboard_monitoring_enabled") != nil {
            self.isMonitoringEnabled = UserDefaults.standard.bool(forKey: "clipboard_monitoring_enabled")
        }
        if UserDefaults.standard.object(forKey: "clipboard_ignore_concealed") != nil {
            self.ignoreConcealedTypes = UserDefaults.standard.bool(forKey: "clipboard_ignore_concealed")
        }

        loadItemsFromDisk()
        trimItems()
        saveItemsToDisk()

        self.lastChangeCount = NSPasteboard.general.changeCount
        gIsClipboardEnabled = isMonitoringEnabled
        if isMonitoringEnabled {
            startMonitoring()
        }
    }

    // MARK: - Filtered Items (Search Only, No Categories)

    public var filteredItems: [ClipItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.title.lowercased().contains(query) ||
            (item.plainText?.lowercased().contains(query) ?? false)
        }
    }

    public func previewImage(for item: ClipItem) -> NSImage? {
        guard item.type == .image else { return nil }
        if let cached = previewImageCache[item.id] {
            return cached
        }
        var image: NSImage?
        if let data = item.imageData {
            image = NSImage(data: data)
        } else if let url = imageURL(for: item), let data = try? Data(contentsOf: url) {
            image = NSImage(data: data)?.resized(maxDimension: 240)
        }
        if let image {
            previewImageCache[item.id] = image
        }
        return image
    }

    // MARK: - Monitoring Engine

    public func startMonitoring() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
        pollTimer?.tolerance = 0.15
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkPasteboard() {
        guard isMonitoringEnabled else { return }

        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }

        if currentCount == suppressChangeCount {
            lastChangeCount = currentCount
            return
        }
        lastChangeCount = currentCount

        autoreleasepool {
            let pb = NSPasteboard.general

            // 1. Check Concealed / Password Manager flags
            if ignoreConcealedTypes {
                let concealedTypes: Set<String> = [
                    "org.nspasteboard.ConcealedType",
                    "com.agilebits.onepassword",
                    "de.sorcerer.KeepassX",
                    "com.lastpass.LastPass",
                    "org.nspasteboard.AutoGeneratedType"
                ]
                if let types = pb.types, types.contains(where: { concealedTypes.contains($0.rawValue) }) {
                    return
                }
            }

            // 2. File URLs
            if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
                let filePaths = urls.filter { $0.isFileURL }.map { $0.path }
                if !filePaths.isEmpty {
                    let count = filePaths.count
                    let firstPath = filePaths[0]
                    let firstFilename = (firstPath as NSString).lastPathComponent
                    let title = count == 1 ? firstFilename : "\(firstFilename) (+ \(count - 1) tệp)"

                    appendClip(ClipItem(
                        type: .file,
                        title: title,
                        detail: count == 1 ? firstPath : "\(count) tệp tin",
                        plainText: filePaths.joined(separator: "\n"),
                        fileURLs: filePaths
                    ))
                    return
                }
            }

            // 3. Images (save full PNG on disk, keep compact JPEG thumbnail <= 240px for HUD)
            if let image = NSImage(pasteboard: pb) {
                let size = image.size
                if size.width > 2 && size.height > 2 {
                    let clipID = UUID()
                    let fileName = "\(clipID.uuidString).png"
                    let fileURL = self.imagesDirURL.appendingPathComponent(fileName)

                    var originalData: Data? = pb.data(forType: .png)
                    if originalData == nil,
                       let tiff = pb.data(forType: .tiff) ?? image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff) {
                        originalData = rep.representation(using: .png, properties: [:])
                    }
                    if let origData = originalData {
                        try? origData.write(to: fileURL, options: .atomic)
                    }

                    var thumbData: Data? = nil
                    if let thumbnail = image.resized(maxDimension: 240),
                       let tiff = thumbnail.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff) {
                        thumbData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.78])
                            ?? rep.representation(using: .png, properties: [:])
                    }

                    appendClip(ClipItem(
                        id: clipID,
                        type: .image,
                        title: "Ảnh (\(Int(size.width)) × \(Int(size.height))px)",
                        detail: "",
                        imageData: thumbData,
                        imageFileName: fileName
                    ))
                    return
                }
            }

            // 4. Plain / Rich Text (keep RTF only if <= 256 KB to prevent RAM bloat)
            if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let firstLine = string
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first(where: { !$0.isEmpty }) ?? "Văn bản"

                let rawRTF = pb.data(forType: .rtf)
                let boundedRTF = (rawRTF != nil && rawRTF!.count <= 256 * 1024) ? rawRTF : nil

                appendClip(ClipItem(
                    type: .text,
                    title: String(firstLine.prefix(160)),
                    detail: "",
                    plainText: string,
                    rtfData: boundedRTF
                ))
            }
        }
    }

    private func appendClip(_ item: ClipItem) {
        if let index = items.firstIndex(where: {
            if let p1 = $0.plainText, let p2 = item.plainText {
                return p1 == p2
            }
            if $0.type == .image && item.type == .image {
                if let f1 = $0.imageFileName, let f2 = item.imageFileName, f1 == f2 { return true }
                if let d1 = $0.imageData, let d2 = item.imageData, d1 == d2 { return true }
                return false
            }
            if let f1 = $0.fileURLs, let f2 = item.fileURLs {
                return f1 == f2
            }
            return false
        }) {
            let existing = items.remove(at: index)
            previewImageCache.removeValue(forKey: existing.id)
            if let oldFile = existing.imageFileName, oldFile != item.imageFileName {
                deleteFileNamed(oldFile)
            }
            var updated = item
            updated.isPinned = existing.isPinned
            insertSorted(updated)
        } else {
            insertSorted(item)
        }

        trimItems()
        saveItemsToDisk()
    }

    private func insertSorted(_ item: ClipItem) {
        let pinnedCount = items.filter { $0.isPinned }.count
        items.insert(item, at: min(pinnedCount, items.count))
    }

    private func trimItems() {
        let pinned = items.filter { $0.isPinned }
        let nonPinned = items.filter { !$0.isPinned }

        let keptPinned = Array(pinned.prefix(Self.maxItemsCount))
        let excessPinned = pinned.dropFirst(Self.maxItemsCount)
        let allowedNonPinned = max(0, Self.maxItemsCount - keptPinned.count)
        let keptNonPinned = Array(nonPinned.prefix(allowedNonPinned))
        let excessNonPinned = nonPinned.dropFirst(allowedNonPinned)

        for item in excessPinned {
            previewImageCache.removeValue(forKey: item.id)
            deleteAssociatedImage(for: item)
        }
        for item in excessNonPinned {
            previewImageCache.removeValue(forKey: item.id)
            deleteAssociatedImage(for: item)
        }

        self.items = keptPinned + keptNonPinned
        clampSelection()
    }

    // MARK: - Clip Actions

    public func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        let updated = items.remove(at: index)
        insertSorted(updated)
        saveItemsToDisk()
    }

    public func deleteItem(_ item: ClipItem) {
        previewImageCache.removeValue(forKey: item.id)
        deleteAssociatedImage(for: item)
        items.removeAll(where: { $0.id == item.id })
        saveItemsToDisk()
        clampSelection()
    }

    public func clearAllHistory() {
        let unpinned = items.filter { !$0.isPinned }
        for item in unpinned {
            previewImageCache.removeValue(forKey: item.id)
            deleteAssociatedImage(for: item)
        }
        items = items.filter { $0.isPinned }
        saveItemsToDisk()
        selectedIndex = 0
    }

    // MARK: - Reorder Pinned Items

    public enum MoveDirection {
        case up
        case down
    }

    public func canMoveUp(id: UUID) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].isPinned else { return false }
        return idx > 0 && items[idx - 1].isPinned
    }

    public func canMoveDown(id: UUID) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].isPinned else { return false }
        return idx < items.count - 1 && items[idx + 1].isPinned
    }

    public func movePinnedItem(id: UUID, direction: MoveDirection) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].isPinned else { return }
        switch direction {
        case .up:
            if idx > 0 && items[idx - 1].isPinned {
                items.swapAt(idx, idx - 1)
                saveItemsToDisk()
                if let newFilteredIdx = filteredItems.firstIndex(where: { $0.id == id }) {
                    selectedIndex = newFilteredIdx
                }
            }
        case .down:
            if idx < items.count - 1 && items[idx + 1].isPinned {
                items.swapAt(idx, idx + 1)
                saveItemsToDisk()
                if let newFilteredIdx = filteredItems.firstIndex(where: { $0.id == id }) {
                    selectedIndex = newFilteredIdx
                }
            }
        }
    }

    public func moveSelectedPinned(direction: MoveDirection) {
        guard let item = selectedItem, item.isPinned else { return }
        movePinnedItem(id: item.id, direction: direction)
    }

    // MARK: - Selection & Keyboard Navigation

    public var selectedItem: ClipItem? {
        let list = filteredItems
        guard !list.isEmpty else { return nil }
        let index = min(max(0, selectedIndex), list.count - 1)
        return list[index]
    }

    public func clampSelection() {
        let count = filteredItems.count
        selectedIndex = count == 0 ? 0 : min(max(0, selectedIndex), count - 1)
    }

    public func selectNext() {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
        keyboardScrollTargetID = selectedItem?.id
    }

    public func selectPrevious() {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
        keyboardScrollTargetID = selectedItem?.id
    }

    public func pasteSelectedItem() {
        guard let item = selectedItem else { return }
        pasteItem(item)
    }

    public func pasteItemAt(index: Int) {
        let list = filteredItems
        guard index >= 0 && index < list.count else { return }
        pasteItem(list[index])
    }

    public func togglePinSelected() {
        guard let item = selectedItem else { return }
        togglePin(item)
        clampSelection()
    }

    public func deleteSelectedItem() {
        guard let item = selectedItem else { return }
        deleteItem(item)
        clampSelection()
    }

    // MARK: - Direct Paste Action

    public func pasteItem(_ item: ClipItem) {
        autoreleasepool {
            let pb = NSPasteboard.general
            pb.clearContents()

            if let rtf = item.rtfData {
                pb.setData(rtf, forType: .rtf)
            }
            if let text = item.plainText {
                pb.setString(text, forType: .string)
            }
            if item.type == .image {
                var fullImage: NSImage?
                if let fileName = item.imageFileName {
                    let fileURL = imagesDirURL.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: fileURL.path),
                       let data = try? Data(contentsOf: fileURL) {
                        fullImage = NSImage(data: data)
                        pb.setData(data, forType: .png)
                    }
                }
                if fullImage == nil, let imgData = item.imageData, let img = NSImage(data: imgData) {
                    fullImage = img
                }
                if let img = fullImage {
                    pb.writeObjects([img])
                }
            }
            if let paths = item.fileURLs {
                let urls = paths.map { NSURL(fileURLWithPath: $0) }
                pb.writeObjects(urls)
            }

            self.suppressChangeCount = pb.changeCount
            self.lastChangeCount = pb.changeCount
        }

        hideHUD()

        let appToActivate = previousApp ?? NSWorkspace.shared.runningApplications.first(where: { $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier })
        if let app = appToActivate {
            app.activate(options: [.activateIgnoringOtherApps])
            if #available(macOS 14.0, *) {
                app.activate()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true) {
                down.flags = .maskCommand
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false) {
                up.flags = .maskCommand
                up.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Image File Management

    public func imageURL(for item: ClipItem) -> URL? {
        guard item.type == .image else { return nil }
        if let fileName = item.imageFileName {
            let url = imagesDirURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let fallback = imagesDirURL.appendingPathComponent("\(item.id.uuidString).png")
        if FileManager.default.fileExists(atPath: fallback.path) { return fallback }
        return nil
    }

    public func deleteAssociatedImage(for item: ClipItem) {
        guard item.type == .image else { return }
        if let fileName = item.imageFileName {
            deleteFileNamed(fileName)
        }
        deleteFileNamed("\(item.id.uuidString).png")
    }

    private func deleteFileNamed(_ fileName: String) {
        let fileURL = imagesDirURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Floating HUD Window Management (Created on demand & released on close for 0 idle RAM)

    public func toggleHUD() {
        if isHUDVisible && (hudPanel?.isVisible ?? false) {
            hideHUD()
        } else {
            isHUDVisible = false
            showHUD()
        }
    }

    public func showHUD() {
        guard !isHUDVisible else { return }

        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = front
        }

        self.searchText = ""
        self.selectedIndex = 0
        self.hoveredItemID = nil
        self.keyboardScrollTargetID = nil
        self.scrollToTopToken &+= 1
        gIsClipboardSearchEmpty = true
        self.isHUDVisible = true
        gIsClipboardHUDVisible = true

        createHUDPanel()

        if let panel = hudPanel {
            let mouseLoc = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) }) ?? NSScreen.main ?? NSScreen.screens[0]

            let panelWidth = Self.hudWidth
            let panelHeight = Self.hudHeight
            let x = screen.visibleFrame.midX - (panelWidth / 2)
            let y = screen.visibleFrame.midY - (panelHeight / 2) + 40

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            resetHUDScrollToTop()
            self.hudShownTimestamp = Date()
            NSApplication.shared.activate(ignoringOtherApps: true)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            }
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            installBlurMonitors(for: panel)

            DispatchQueue.main.async { [weak self] in
                self?.resetHUDScrollToTop()
            }
        }
    }

    public func hideHUD() {
        guard isHUDVisible else { return }
        self.isHUDVisible = false
        gIsClipboardHUDVisible = false
        removeBlurMonitors()
        if let panel = hudPanel {
            panel.orderOut(nil)
            panel.contentView = nil
            self.hudPanel = nil
        }
        // Release decoded NSImage thumbnails from RAM immediately when HUD closes
        previewImageCache.removeAll(keepingCapacity: false)
    }

    public func resetHUDScrollToTop() {
        guard let rootView = hudPanel?.contentView else { return }
        rootView.layoutSubtreeIfNeeded()
        Self.scrollVerticalScrollViewsToTop(in: rootView)
    }

    private static func scrollVerticalScrollViewsToTop(in view: NSView) {
        if let scrollView = view as? NSScrollView, scrollView.frame.height > 100 {
            if let docView = scrollView.documentView {
                let topPoint = docView.isFlipped
                    ? NSPoint(x: 0, y: 0)
                    : NSPoint(x: 0, y: max(0, docView.bounds.height - scrollView.contentView.bounds.height))
                scrollView.contentView.scroll(to: topPoint)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
        for subview in view.subviews {
            scrollVerticalScrollViewsToTop(in: subview)
        }
    }

    private func installBlurMonitors(for panel: NSPanel) {
        removeBlurMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.hudPanel, self.isHUDVisible else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.hideHUD()
                }
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, let panel = self.hudPanel, self.isHUDVisible else { return event }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hideHUD()
            }
            return event
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let appSwitchObs = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            let activatedApp = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let activatedBundleID = activatedApp?.bundleIdentifier
            Task { @MainActor [weak self] in
                guard let self, let panel = self.hudPanel, self.isHUDVisible else { return }
                guard Date().timeIntervalSince(self.hudShownTimestamp) > 0.35 else { return }
                if activatedBundleID != Bundle.main.bundleIdentifier && !panel.frame.contains(NSEvent.mouseLocation) {
                    self.hideHUD()
                }
            }
        }
        focusObservers = [appSwitchObs]
    }

    private func removeBlurMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        for obs in focusObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            NotificationCenter.default.removeObserver(obs)
        }
        focusObservers.removeAll()
    }

    private func createHUDPanel() {
        if let existing = hudPanel {
            existing.orderOut(nil)
            existing.contentView = nil
            hudPanel = nil
        }

        let panel = ClipboardHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.hudWidth, height: Self.hudHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false

        let hosting = NSHostingView(rootView: ClipboardOverlayView(manager: self))
        if #available(macOS 13.0, *) {
            hosting.safeAreaRegions = []
        }
        panel.contentView = hosting
        self.hudPanel = panel
    }

    // MARK: - Disk Persistence

    private func saveItemsToDisk() {
        let itemsToSave = self.items
        let url = self.storageURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                appLog("Failed to save clipboard items: \(error.localizedDescription)")
            }
        }
    }

    private func loadItemsFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            var loaded = try JSONDecoder().decode([ClipItem].self, from: data)
            // Keep at most 10 items immediately on load to minimize RAM
            if loaded.count > Self.maxItemsCount {
                let pinned = loaded.filter { $0.isPinned }.prefix(Self.maxItemsCount)
                let remaining = max(0, Self.maxItemsCount - pinned.count)
                let unpinned = loaded.filter { !$0.isPinned }.prefix(remaining)
                loaded = Array(pinned) + Array(unpinned)
            }
            // Drop oversized RTF payloads from legacy storage
            for i in loaded.indices {
                if let rtf = loaded[i].rtfData, rtf.count > 256 * 1024 {
                    loaded[i].rtfData = nil
                }
            }
            self.items = loaded
            cleanupOrphanImages(validItems: loaded)
        } catch {
            appLog("Failed to load clipboard items: \(error.localizedDescription)")
        }
    }

    private func cleanupOrphanImages(validItems: [ClipItem]) {
        let imagesDir = self.imagesDirURL
        DispatchQueue.global(qos: .utility).async {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) else { return }
            var validFileNames = Set<String>()
            for item in validItems where item.type == .image {
                if let f = item.imageFileName { validFileNames.insert(f) }
                validFileNames.insert("\(item.id.uuidString).png")
            }
            for file in files {
                if !validFileNames.contains(file) && (file.hasSuffix(".png") || file.hasSuffix(".jpg") || file.hasSuffix(".tiff")) {
                    try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file))
                }
            }
        }
    }
}

// MARK: - Borderless Key-Capable HUD Panel

private final class ClipboardHUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - NSImage Helpers

private extension NSImage {
    func resized(maxDimension: CGFloat) -> NSImage? {
        let w = size.width
        let h = size.height
        guard w > 0 && h > 0 else { return nil }

        let ratio = min(maxDimension / w, maxDimension / h)
        if ratio >= 1.0 { return self }

        let newSize = NSSize(width: floor(w * ratio), height: floor(h * ratio))
        let target = NSImage(size: newSize)
        target.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        target.unlockFocus()
        return target
    }
}
