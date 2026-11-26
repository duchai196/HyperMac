import Foundation
import AppKit
import CoreGraphics
import SwiftUI
import Combine

// MARK: - Minimal Screenshot Tool Models (Arrow & Text Only)

public enum ScreenshotTool: String, CaseIterable, Sendable {
    case arrow
    case text

    public var title: String {
        switch self {
        case .arrow: return tr("Mũi tên", "Arrow")
        case .text:  return tr("Nhập chữ", "Text")
        }
    }

    public var icon: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .text:  return "textformat"
        }
    }
}

public enum TextBoxStyle: String, CaseIterable, Sendable {
    case plain = "plain"
    case solidPill = "solid"
    case darkPill = "dark"

    public var title: String {
        switch self {
        case .plain:     return tr("Chữ nổi", "Plain")
        case .solidPill: return tr("Nền màu", "Colored")
        case .darkPill:  return tr("Nền tối", "Dark")
        }
    }
}

public struct DrawnStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var tool: ScreenshotTool
    public var points: [CGPoint]
    public var colorHex: String
    public var lineWidth: CGFloat
    public var text: String
    public var fontSize: CGFloat
    public var textBoxStyle: TextBoxStyle

    public init(
        id: UUID = UUID(),
        tool: ScreenshotTool,
        points: [CGPoint],
        colorHex: String,
        lineWidth: CGFloat,
        text: String = "",
        fontSize: CGFloat = 20,
        textBoxStyle: TextBoxStyle = .solidPill
    ) {
        self.id = id
        self.tool = tool
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.text = text
        self.fontSize = fontSize
        self.textBoxStyle = textBoxStyle
    }

    public var nsColor: NSColor {
        NSColor(hex: colorHex) ?? .systemRed
    }
}

// MARK: - Dynamic CoreGraphics Loader for Instant Screen Capture

private typealias CGWindowListCreateImageFunc = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

private let cgCaptureSym: CGWindowListCreateImageFunc? = {
    if let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
       let sym = dlsym(handle, "CGWindowListCreateImage") {
        return unsafeBitCast(sym, to: CGWindowListCreateImageFunc.self)
    }
    return nil
}()

// MARK: - Lightweight Screenshot Manager (Region Capture -> Studio with Arrow & Text)

@MainActor
public class ScreenshotManager: ObservableObject {
    public static let shared = ScreenshotManager()

    // Configuration
    @Published public var isScreenshotEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isScreenshotEnabled, forKey: "screenshot_enabled")
            gIsScreenshotEnabled = isScreenshotEnabled
        }
    }

    // Active Snipping State
    @Published public var isActive: Bool = false
    @Published public var isStudioOpen: Bool = false {
        didSet { gIsStudioEditorOpen = isStudioOpen }
    }
    @Published public var screenImage: CGImage? = nil
    @Published public var screenNSImage: NSImage? = nil
    @Published public var screenFrame: NSRect = .zero
    @Published public var scaleFactor: CGFloat = 2.0
    @Published public var selectionRect: CGRect = .zero
    @Published public var isDraggingSelection: Bool = false
    @Published public var isSpaceHeld: Bool = false

    // Studio Image State
    @Published public var studioBaseCGImage: CGImage? = nil
    @Published public var studioBaseNSImage: NSImage? = nil
    @Published public var studioLogicalSize: CGSize = .zero
    @Published public var studioZoom: CGFloat = 1.0

    // Annotation Tools (Arrow & Text only)
    @Published public var currentTool: ScreenshotTool = .arrow
    @Published public var selectedColorHex: String = "#FF3B30"
    @Published public var strokeWidth: CGFloat = 3.5
    @Published public var fontSize: CGFloat = 22.0
    @Published public var textBoxStyle: TextBoxStyle = .solidPill

    // Strokes & Text Editing
    @Published public var strokes: [DrawnStroke] = []
    @Published public var redoStack: [DrawnStroke] = []
    @Published public var activeStroke: DrawnStroke? = nil
    @Published public var editingTextStrokeID: UUID? = nil {
        didSet { gIsStudioEditingText = (editingTextStrokeID != nil) }
    }
    @Published public var editingTextValue: String = ""
    @Published public var editingTextPoint: CGPoint = .zero
    @Published public var statusBannerMessage: String? = nil
    private var statusBannerToken: Int = 0

    public let availableColors: [String] = [
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#34C759", // Green
        "#007AFF", // Blue
        "#AF52DE", // Purple
        "#FFFFFF", // White
        "#000000"  // Black
    ]

    private var overlayPanel: NSPanel?
    private var studioWindow: NSWindow?

    private init() {
        if UserDefaults.standard.object(forKey: "screenshot_enabled") != nil {
            self.isScreenshotEnabled = UserDefaults.standard.bool(forKey: "screenshot_enabled")
        } else {
            self.isScreenshotEnabled = true
        }
        gIsScreenshotEnabled = self.isScreenshotEnabled
    }

    public func showStatusBanner(_ message: String) {
        statusBannerToken &+= 1
        let token = statusBannerToken
        withAnimation(.easeInOut(duration: 0.16)) {
            statusBannerMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let self, self.statusBannerToken == token else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                self.statusBannerMessage = nil
            }
        }
    }

    // MARK: - Start Region Capture

    public func startCapture() {
        guard isScreenshotEnabled, !isActive else { return }

        if isStudioOpen {
            closeStudioEditor()
        }

        if !PermissionsManager.checkScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            PermissionsManager.shared.openScreenCaptureSettings()
            return
        }

        let targetScreen = preferredTargetScreen()
        let frame = targetScreen.frame
        self.screenFrame = frame

        guard let capturedImage = captureScreenImage(screen: targetScreen) else {
            appLog("⚠️ ScreenshotManager: Failed to capture screen image.")
            return
        }

        self.screenImage = capturedImage
        self.scaleFactor = max(1.0, CGFloat(capturedImage.width) / max(1.0, frame.width))
        self.screenNSImage = NSImage(cgImage: capturedImage, size: frame.size)
        self.selectionRect = .zero
        self.isDraggingSelection = false
        self.isSpaceHeld = false
        gIsSpacePressed = false

        createOverlayPanel(on: targetScreen)
        self.isActive = true
        gIsScreenshotActive = true
    }

    private func preferredTargetScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLoc) }
            ?? NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func captureScreenImage(screen: NSScreen) -> CGImage? {
        let primaryH = NSScreen.screens[0].frame.height
        let f = screen.frame
        let cgRect = CGRect(
            x: f.origin.x,
            y: primaryH - (f.origin.y + f.height),
            width: f.width,
            height: f.height
        )

        if CGPreflightScreenCaptureAccess(),
           let fn = cgCaptureSym,
           let unmanaged = fn(cgRect, 1, 0, 0) {
            return unmanaged.takeRetainedValue()
        }

        let tempPath = "/tmp/hypermac_screenshot_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let res = shell("/usr/sbin/screencapture -x -C -R \(Int(cgRect.origin.x)),\(Int(cgRect.origin.y)),\(Int(cgRect.width)),\(Int(cgRect.height)) \"\(tempPath)\"")
        if res.exitCode == 0,
           let nsImg = NSImage(contentsOfFile: tempPath),
           let image = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return image
        }

        if let fn = cgCaptureSym, let unmanaged = fn(cgRect, 1, 0, 0) {
            return unmanaged.takeRetainedValue()
        }
        return nil
    }

    public func switchScreen() {
        guard isActive, NSScreen.screens.count > 1 else { return }
        let screens = NSScreen.screens
        guard let currentIndex = screens.firstIndex(where: { $0.frame == self.screenFrame }) else { return }
        let nextScreen = screens[(currentIndex + 1) % screens.count]

        self.screenFrame = nextScreen.frame
        guard let capturedImage = captureScreenImage(screen: nextScreen) else { return }
        self.screenImage = capturedImage
        self.scaleFactor = max(1.0, CGFloat(capturedImage.width) / max(1.0, nextScreen.frame.width))
        self.screenNSImage = NSImage(cgImage: capturedImage, size: nextScreen.frame.size)
        self.selectionRect = .zero

        createOverlayPanel(on: nextScreen)
    }

    private func highestOnScreenAppWindowLayer() -> Int {
        let cursorLimit = Int(CGWindowLevelForKey(.cursorWindow)) - 50
        let myPID = ProcessInfo.processInfo.processIdentifier
        let ignoredOwners: Set<String> = ["Window Server", "WindowServer", "Dock"]
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return Int(CGWindowLevelForKey(.screenSaverWindow))
        }
        var maxLayer = 0
        for entry in windowList {
            guard let layer = entry[kCGWindowLayer as String] as? Int,
                  layer < cursorLimit else { continue }
            if let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid == myPID { continue }
            let owner = (entry[kCGWindowOwnerName as String] as? String) ?? ""
            if ignoredOwners.contains(owner) { continue }
            let alpha = (entry[kCGWindowAlpha as String] as? Double) ?? 1.0
            guard alpha > 0.01 else { continue }
            if layer > maxLayer {
                maxLayer = layer
            }
        }
        return maxLayer
    }

    private func createOverlayPanel(on screen: NSScreen) {
        if let existing = overlayPanel {
            existing.orderOut(nil)
            existing.contentView = nil
            overlayPanel = nil
        }

        let panel = ScreenshotKeyPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Strictly above high-level fullscreen lightboxes (e.g. Telegram image viewer at screenSaver=1000),
        // while staying safely below the hardware cursor window level.
        // IMPORTANT: Do NOT set `panel.isFloatingPanel = true` after setting `panel.level`,
        // because AppKit's `isFloatingPanel = true` overwrites `panel.level` back to `.floating` (3).
        let cursorSafeMax = Int(CGWindowLevelForKey(.cursorWindow)) - 20
        let targetLevel = min(
            cursorSafeMax,
            max(Int(CGWindowLevelForKey(.assistiveTechHighWindow)), highestOnScreenAppWindowLayer() + 20)
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.level = NSWindow.Level(rawValue: targetLevel)

        let hostingView = ScreenshotHostingView(rootView: ScreenshotOverlayView(manager: self))
        if #available(macOS 13.0, *) {
            hostingView.safeAreaRegions = []
        }
        panel.contentView = hostingView
        self.overlayPanel = panel

        panel.setFrame(screen.frame, display: true)
        // Do NOT call NSApp.activate() here: activating HyperMac would deactivate fullscreen lightboxes
        // (such as Telegram's image viewer) or switch away from a macOS Fullscreen Space.
        panel.orderFrontRegardless()
        panel.makeKey()
        NSCursor.crosshair.set()
    }

    // MARK: - Open & Close Studio Editor

    public func openStudioEditor() {
        guard let baseCG = screenImage,
              selectionRect.width >= 12,
              selectionRect.height >= 12 else { return }

        let scale = self.scaleFactor
        let pixelCropRect = CGRect(
            x: round(selectionRect.origin.x * scale),
            y: round(selectionRect.origin.y * scale),
            width: round(selectionRect.width * scale),
            height: round(selectionRect.height * scale)
        )
        guard let croppedCG = baseCG.cropping(to: pixelCropRect) else { return }

        let logicalSize = CGSize(width: round(selectionRect.width), height: round(selectionRect.height))
        let targetScreen = NSScreen.screens.first { $0.frame == self.screenFrame }

        // Release full-screen freeze buffer immediately before opening Studio
        dismissOverlayAndReleaseScreenBuffer()

        self.scaleFactor = scale
        self.studioBaseCGImage = croppedCG
        self.studioLogicalSize = logicalSize
        self.studioBaseNSImage = NSImage(cgImage: croppedCG, size: logicalSize)
        self.strokes = []
        self.redoStack = []
        self.activeStroke = nil
        self.editingTextStrokeID = nil
        self.editingTextValue = ""
        self.currentTool = .arrow
        self.studioZoom = 1.0

        presentStudioWindow(preferredScreen: targetScreen)
    }

    private func dismissOverlayAndReleaseScreenBuffer() {
        if let panel = overlayPanel {
            panel.orderOut(nil)
            panel.contentView = nil
            overlayPanel = nil
        }
        self.isActive = false
        gIsScreenshotActive = false
        self.screenImage = nil
        self.screenNSImage = nil
        self.selectionRect = .zero
        self.isDraggingSelection = false
        self.isSpaceHeld = false
        gIsSpacePressed = false
        NSCursor.arrow.set()
    }

    private func presentStudioWindow(preferredScreen: NSScreen? = nil) {
        if let existing = studioWindow {
            existing.orderOut(nil)
            existing.contentView = nil
            studioWindow = nil
        }

        let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let winW = min(max(680, studioLogicalSize.width + 80), visible.width - 48)
        let winH = min(max(460, studioLogicalSize.height + 160), visible.height - 48)
        let originX = visible.midX - winW / 2
        let originY = visible.midY - winH / 2

        let window = ScreenshotStudioWindow(
            contentRect: NSRect(x: originX, y: originY, width: winW, height: winH),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = tr("HyperMac Studio", "HyperMac Studio")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 560, height: 380)
        window.isReleasedWhenClosed = false
        let cursorSafeMax = Int(CGWindowLevelForKey(.cursorWindow)) - 20
        let studioLevel = min(
            cursorSafeMax,
            max(Int(NSWindow.Level.floating.rawValue), highestOnScreenAppWindowLayer() + 10)
        )
        window.level = NSWindow.Level(rawValue: studioLevel)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: ScreenshotStudioEditorView(manager: self))
        window.contentView = hosting
        self.studioWindow = window
        self.isStudioOpen = true

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        }
    }

    public func closeStudioEditor() {
        commitActiveTextEditing()
        if let win = studioWindow {
            win.orderOut(nil)
            win.contentView = nil
            studioWindow = nil
        }
        self.isStudioOpen = false
        gIsStudioEditorOpen = false
        gIsStudioEditingText = false
        self.studioBaseCGImage = nil
        self.studioBaseNSImage = nil
        self.studioLogicalSize = .zero
        self.strokes.removeAll(keepingCapacity: false)
        self.redoStack.removeAll(keepingCapacity: false)
        self.activeStroke = nil
        self.editingTextStrokeID = nil
        self.editingTextValue = ""
    }

    public func cancelCapture() {
        dismissOverlayAndReleaseScreenBuffer()
    }

    // MARK: - Studio Keyboard Shortcuts

    public func handleStudioKeyCommand(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isStudioOpen else { return false }

        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasAlt = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        if editingTextStrokeID != nil {
            if keyCode == 53 && !hasCmd && !hasCtrl && !hasAlt && !hasShift {
                commitActiveTextEditing()
                return true
            }
            return false
        }

        // ⌘C -> Copy & Close
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 8 {
            copyToClipboard()
            return true
        }
        // ⌘S -> Save to Downloads/Screenshots & Close
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 1 {
            saveToDownloads()
            return true
        }
        // ⌘⇧S -> Save As...
        if hasCmd && !hasCtrl && !hasAlt && hasShift && keyCode == 1 {
            saveAsWithPanel()
            return true
        }
        // ⌘Z / ⌘⇧Z -> Undo / Redo
        if hasCmd && !hasCtrl && !hasAlt && keyCode == 6 {
            if hasShift { redoLastStroke() } else { undoLastStroke() }
            return true
        }
        // ⌘W -> Close
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 13 {
            closeStudioEditor()
            return true
        }
        // Enter -> Copy & Close
        if !hasCmd && !hasCtrl && !hasAlt && !hasShift && (keyCode == 36 || keyCode == 76) {
            copyToClipboard()
            return true
        }
        // Esc -> Close Studio
        if !hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 53 {
            closeStudioEditor()
            return true
        }

        return false
    }

    // MARK: - Strokes (Arrow & Text)

    public func addStroke(_ stroke: DrawnStroke) {
        strokes.append(stroke)
        redoStack.removeAll()
    }

    public func undoLastStroke() {
        commitActiveTextEditing()
        guard let last = strokes.popLast() else { return }
        redoStack.append(last)
    }

    public func redoLastStroke() {
        commitActiveTextEditing()
        guard let next = redoStack.popLast() else { return }
        strokes.append(next)
    }

    public func clearAllStrokes() {
        commitActiveTextEditing()
        guard !strokes.isEmpty else { return }
        strokes.removeAll()
        redoStack.removeAll()
    }

    public func beginTextAnnotation(at point: CGPoint) {
        commitActiveTextEditing()
        let newStroke = DrawnStroke(
            tool: .text,
            points: [point],
            colorHex: selectedColorHex,
            lineWidth: strokeWidth,
            text: "",
            fontSize: fontSize,
            textBoxStyle: textBoxStyle
        )
        strokes.append(newStroke)
        redoStack.removeAll()
        editingTextStrokeID = newStroke.id
        editingTextValue = ""
        editingTextPoint = point
    }

    public func commitActiveTextEditing() {
        guard let id = editingTextStrokeID else { return }
        if let idx = strokes.firstIndex(where: { $0.id == id }) {
            let trimmed = editingTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                strokes.remove(at: idx)
            } else {
                strokes[idx].text = editingTextValue
            }
        }
        editingTextStrokeID = nil
        editingTextValue = ""
    }

    // MARK: - High-Res Render Engine (Arrow & Text Only)

    public func renderStudioCompositeImage() -> CGImage? {
        commitActiveTextEditing()
        guard let baseCG = studioBaseCGImage else { return nil }
        if strokes.isEmpty {
            return baseCG
        }

        let imgW = CGFloat(baseCG.width)
        let imgH = CGFloat(baseCG.height)
        guard imgW > 0 && imgH > 0 else { return nil }
        let scale = imgW / max(1, studioLogicalSize.width)

        guard let colorSpace = baseCG.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: Int(imgW),
                  height: Int(imgH),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return baseCG }

        ctx.draw(baseCG, in: CGRect(x: 0, y: 0, width: imgW, height: imgH))

        // Flip to top-left logical coordinates
        ctx.saveGState()
        ctx.translateBy(x: 0, y: imgH)
        ctx.scaleBy(x: scale, y: -scale)

        for stroke in strokes {
            drawStroke(stroke, in: ctx)
        }

        ctx.restoreGState()
        return ctx.makeImage() ?? baseCG
    }

    private func drawStroke(_ stroke: DrawnStroke, in ctx: CGContext) {
        guard !stroke.points.isEmpty else { return }

        ctx.saveGState()
        ctx.setStrokeColor(stroke.nsColor.cgColor)
        ctx.setFillColor(stroke.nsColor.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(stroke.lineWidth)

        switch stroke.tool {
        case .arrow:
            guard stroke.points.count >= 2 else { break }
            let start = stroke.points[0]
            let end = stroke.points[stroke.points.count - 1]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dist = hypot(dx, dy)
            guard dist >= 4 else { break }

            ctx.beginPath()
            ctx.move(to: start)
            ctx.addLine(to: end)
            ctx.strokePath()

            let angle = atan2(dy, dx)
            let arrowLength: CGFloat = max(13, stroke.lineWidth * 3.6)
            let arrowAngle: CGFloat = .pi / 6
            let p1 = CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            let p2 = CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )
            ctx.beginPath()
            ctx.move(to: p1)
            ctx.addLine(to: end)
            ctx.addLine(to: p2)
            ctx.strokePath()

        case .text:
            let display = stroke.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !display.isEmpty else { break }
            let origin = stroke.points[0]
            let font = NSFont.systemFont(ofSize: stroke.fontSize, weight: .semibold)
            let textColor: NSColor
            switch stroke.textBoxStyle {
            case .plain:
                textColor = stroke.nsColor
            case .solidPill:
                textColor = stroke.colorHex.uppercased() == "#FFFFFF" ? .black : .white
            case .darkPill:
                textColor = .white
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let nsStr = display as NSString
            let textSize = nsStr.size(withAttributes: attrs)
            let padX: CGFloat = 10
            let padY: CGFloat = 6
            let pillRect = CGRect(x: origin.x, y: origin.y, width: textSize.width + padX * 2, height: textSize.height + padY * 2)

            if stroke.textBoxStyle != .plain {
                ctx.saveGState()
                let bgPath = CGPath(roundedRect: pillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: NSColor.black.withAlphaComponent(0.3).cgColor)
                ctx.addPath(bgPath)
                ctx.setFillColor(stroke.textBoxStyle == .solidPill ? stroke.nsColor.cgColor : NSColor.black.withAlphaComponent(0.78).cgColor)
                ctx.fillPath()
                ctx.restoreGState()
            }

            let prev = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            nsStr.draw(at: CGPoint(x: origin.x + padX, y: origin.y + padY), withAttributes: attrs)
            NSGraphicsContext.current = prev
        }

        ctx.restoreGState()
    }

    // MARK: - Export Actions (Wrapped in autoreleasepool to release buffers immediately)

    public func copyToClipboard() {
        autoreleasepool {
            guard let finalCG = renderStudioCompositeImage() else { return }
            let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
            let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
            let rep = NSBitmapImageRep(cgImage: finalCG)
            rep.size = NSSize(width: logicalW, height: logicalH)

            let pngData = rep.representation(using: .png, properties: [:])
            let tiffData = rep.representation(using: .tiff, properties: [:])

            let pb = NSPasteboard.general
            pb.clearContents()
            if let pngData { pb.setData(pngData, forType: .png) }
            if let tiffData { pb.setData(tiffData, forType: .tiff) }
            NSSound(named: "Glass")?.play()
        }
        closeStudioEditor()
    }

    public func saveToDownloads() {
        autoreleasepool {
            guard let finalCG = renderStudioCompositeImage() else { return }
            let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
            let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
            let rep = NSBitmapImageRep(cgImage: finalCG)
            rep.size = NSSize(width: logicalW, height: logicalH)
            guard let pngData = rep.representation(using: .png, properties: [:]) else { return }

            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let screenshotsDir = downloadsDir.appendingPathComponent("Screenshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
            let fileURL = screenshotsDir.appendingPathComponent("Screenshot_\(formatter.string(from: Date())).png")

            do {
                try pngData.write(to: fileURL, options: .atomic)
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(pngData, forType: .png)
                pb.writeObjects([fileURL as NSURL])
                NSSound(named: "Glass")?.play()
                appLog("📸 Screenshot saved to \(fileURL.path)")
            } catch {
                appLog("❌ Error saving screenshot: \(error)")
            }
        }
        closeStudioEditor()
    }

    public func saveAsWithPanel() {
        let savePanel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        savePanel.nameFieldStringValue = "HyperMac_\(formatter.string(from: Date())).png"
        savePanel.canCreateDirectories = true
        savePanel.level = .modalPanel

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else { return }

        autoreleasepool {
            guard let finalCG = renderStudioCompositeImage() else { return }
            let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
            let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
            let rep = NSBitmapImageRep(cgImage: finalCG)
            rep.size = NSSize(width: logicalW, height: logicalH)

            let isJPEG = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
            let data = isJPEG
                ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
                : rep.representation(using: .png, properties: [:])

            if let data {
                try? data.write(to: url, options: .atomic)
                NSSound(named: "Glass")?.play()
                showStatusBanner(tr("Đã lưu ảnh tại \(url.lastPathComponent)", "Saved \(url.lastPathComponent)"))
            }
        }
    }
}

// MARK: - Key-Capable Panel, Hosting View & Studio Window Subclasses

private final class ScreenshotHostingView: NSHostingView<ScreenshotOverlayView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
}

private final class ScreenshotKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    private var isTrackingRegionDrag: Bool = false
    private var regionDragOrigin: CGPoint = .zero
    private var spaceMoveStartMouse: CGPoint = .zero
    private var spaceMoveStartRect: CGRect = .zero

    override func sendEvent(_ event: NSEvent) {
        let manager = ScreenshotManager.shared
        let w = max(1, frame.width)
        let h = max(1, frame.height)
        let loc = event.locationInWindow
        let pt = CGPoint(
            x: max(0, min(w, loc.x)),
            y: max(0, min(h, h - loc.y))
        )

        switch event.type {
        case .leftMouseDown:
            isTrackingRegionDrag = true
            regionDragOrigin = pt
            spaceMoveStartMouse = .zero
            manager.isDraggingSelection = false
            manager.selectionRect = .zero
            return

        case .leftMouseDragged:
            if isTrackingRegionDrag {
                if manager.isSpaceHeld && manager.selectionRect.width > 0 && manager.selectionRect.height > 0 {
                    if !manager.isDraggingSelection {
                        manager.isDraggingSelection = true
                        spaceMoveStartMouse = pt
                        spaceMoveStartRect = manager.selectionRect
                    }
                    let dx = pt.x - spaceMoveStartMouse.x
                    let dy = pt.y - spaceMoveStartMouse.y
                    let newX = max(0, min(w - spaceMoveStartRect.width, spaceMoveStartRect.origin.x + dx))
                    let newY = max(0, min(h - spaceMoveStartRect.height, spaceMoveStartRect.origin.y + dy))
                    manager.selectionRect.origin = CGPoint(x: newX, y: newY)
                } else {
                    if manager.isDraggingSelection {
                        manager.isDraggingSelection = false
                        regionDragOrigin = manager.selectionRect.origin
                    }
                    let minX = max(0, min(regionDragOrigin.x, pt.x))
                    let minY = max(0, min(regionDragOrigin.y, pt.y))
                    let rectW = min(w - minX, abs(pt.x - regionDragOrigin.x))
                    let rectH = min(h - minY, abs(pt.y - regionDragOrigin.y))
                    manager.selectionRect = CGRect(x: minX, y: minY, width: rectW, height: rectH)
                }
                return
            }

        case .leftMouseUp:
            if isTrackingRegionDrag {
                isTrackingRegionDrag = false
                manager.isDraggingSelection = false
                if manager.selectionRect.width > 12 && manager.selectionRect.height > 12 {
                    manager.openStudioEditor()
                } else {
                    manager.selectionRect = .zero
                }
                return
            }

        default:
            break
        }

        super.sendEvent(event)
    }
}

private final class ScreenshotStudioWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func close() {
        ScreenshotManager.shared.closeStudioEditor()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        var cgFlags = CGEventFlags()
        if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
        if event.modifierFlags.contains(.shift) { cgFlags.insert(.maskShift) }
        if event.modifierFlags.contains(.option) { cgFlags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }

        if ScreenshotManager.shared.handleStudioKeyCommand(keyCode: Int64(event.keyCode), flags: cgFlags) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        var cgFlags = CGEventFlags()
        if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
        if event.modifierFlags.contains(.shift) { cgFlags.insert(.maskShift) }
        if event.modifierFlags.contains(.option) { cgFlags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }

        if ScreenshotManager.shared.handleStudioKeyCommand(keyCode: Int64(event.keyCode), flags: cgFlags) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Hex Color Helpers

extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 59, 48)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
