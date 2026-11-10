import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import ApplicationServices
@preconcurrency import Vision
import SwiftUI
import Combine

// MARK: - Screenshot Tool & Style Models (Snapzy Studio Suite)

public enum ScreenshotTool: String, CaseIterable, Sendable {
    case select     // Chọn & di chuyển chú thích
    case pen        // Bút vẽ tự do
    case marker     // Bút dạ quang (Tô sáng)
    case arrow      // Mũi tên (Thẳng / Cong)
    case line       // Đường thẳng (Liền / Đứt / Chấm)
    case rect       // Hình chữ nhật viền
    case filledRect // Hình chữ nhật tô màu đặc
    case oval       // Hình bầu dục / tròn
    case text       // Văn bản
    case counter    // Đánh số bước (1, 2, 3... kèm mũi tên)
    case blur       // Làm mờ / Che nhạy cảm (Pixelate / Gaussian / Băng xóa)
    case spotlight  // Đèn rọi làm nổi bật vùng
    case crop       // Cắt khung ảnh
    case move       // Di chuyển khung chọn trên màn hình chụp nhanh

    public var title: String {
        switch self {
        case .select:     return tr("Chọn", "Select")
        case .pen:        return tr("Bút chì", "Pencil")
        case .marker:     return tr("Tô sáng", "Highlighter")
        case .arrow:      return tr("Mũi tên", "Arrow")
        case .line:       return tr("Đường thẳng", "Line")
        case .rect:       return tr("Chữ nhật", "Rectangle")
        case .filledRect: return tr("Khối màu", "Filled Box")
        case .oval:       return tr("Bầu dục", "Oval")
        case .text:       return tr("Văn bản", "Text")
        case .counter:    return tr("Đánh số", "Counter")
        case .blur:       return tr("Làm mờ", "Blur / Redact")
        case .spotlight:  return tr("Đèn rọi", "Spotlight")
        case .crop:       return tr("Cắt ảnh", "Crop")
        case .move:       return tr("Di chuyển", "Move")
        }
    }

    public var icon: String {
        switch self {
        case .select:     return "cursorarrow"
        case .pen:        return "pencil.tip"
        case .marker:     return "highlighter"
        case .arrow:      return "arrow.up.right"
        case .line:       return "line.diagonal"
        case .rect:       return "rectangle"
        case .filledRect: return "rectangle.fill"
        case .oval:       return "circle"
        case .text:       return "textformat"
        case .counter:    return "1.circle.fill"
        case .blur:       return "eye.slash.fill"
        case .spotlight:  return "flashlight.on.fill"
        case .crop:       return "crop"
        case .move:       return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    public static var studioTools: [ScreenshotTool] {
        [.select, .pen, .marker, .arrow, .line, .rect, .filledRect, .oval, .text, .counter, .blur, .spotlight, .crop]
    }
}

public enum ArrowStyle: String, CaseIterable, Sendable {
    case straight = "straight"
    case curvedLeft = "curved_left"
    case curvedRight = "curved_right"

    public var title: String {
        switch self {
        case .straight:    return tr("Thẳng", "Straight")
        case .curvedLeft:  return tr("Cong trái", "Curved Left")
        case .curvedRight: return tr("Cong phải", "Curved Right")
        }
    }

    public var icon: String {
        switch self {
        case .straight:    return "arrow.up.right"
        case .curvedLeft:  return "arrow.turn.up.left"
        case .curvedRight: return "arrow.turn.up.right"
        }
    }
}

public enum LineDashStyle: String, CaseIterable, Sendable {
    case solid = "solid"
    case dashed = "dashed"
    case dotted = "dotted"

    public var title: String {
        switch self {
        case .solid:  return tr("Nét liền", "Solid")
        case .dashed: return tr("Nét đứt", "Dashed")
        case .dotted: return tr("Nét chấm", "Dotted")
        }
    }
}

public enum BlurStyle: String, CaseIterable, Sendable {
    case pixelated = "pixelated"
    case gaussian = "gaussian"
    case solidTape = "tape"

    public var title: String {
        switch self {
        case .pixelated: return tr("Điểm ảnh", "Pixelate")
        case .gaussian:  return tr("Gaussian", "Gaussian")
        case .solidTape: return tr("Băng xóa", "Solid Tape")
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
        case .solidPill: return tr("Nền màu", "Colored Box")
        case .darkPill:  return tr("Nền tối", "Dark Box")
        }
    }
}

public enum WatermarkMode: String, CaseIterable, Sendable {
    case none = "none"
    case corner = "corner"
    case diagonal = "diagonal"
    case tiled = "tiled"

    public var title: String {
        switch self {
        case .none:     return tr("Tắt", "Off")
        case .corner:   return tr("Đơn (Góc)", "Single Corner")
        case .diagonal: return tr("Chéo giữa", "Diagonal")
        case .tiled:    return tr("Lặp ô", "Tiled")
        }
    }
}

public enum StudioBackgroundPreset: String, CaseIterable, Sendable {
    case none = "none"
    case frosted = "frosted"
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case aurora = "aurora"
    case cyber = "cyber"
    case amber = "amber"
    case tahoeDark = "tahoe_dark"
    case tahoeLight = "tahoe_light"

    public var title: String {
        switch self {
        case .none:       return tr("Không nền", "None")
        case .frosted:    return tr("Kính mờ", "Frosted")
        case .ocean:      return tr("Đại dương", "Ocean")
        case .sunset:     return tr("Hoàng hôn", "Sunset")
        case .forest:     return tr("Rừng xanh", "Forest")
        case .aurora:     return tr("Cực quang", "Aurora")
        case .cyber:      return tr("Neon", "Neon")
        case .amber:      return tr("Hổ phách", "Amber")
        case .tahoeDark:  return tr("Tối", "Dark")
        case .tahoeLight: return tr("Sáng", "Light")
        }
    }

    public var gradientHexes: [String] {
        switch self {
        case .none:       return []
        case .frosted:    return ["#2B3240", "#181C24"]
        case .ocean:      return ["#0061FF", "#60EFFF"]
        case .sunset:     return ["#FF512F", "#DD2476", "#7F00FF"]
        case .forest:     return ["#11998E", "#38EF7D"]
        case .aurora:     return ["#6A11CB", "#2575FC", "#00D2FF"]
        case .cyber:      return ["#F953C6", "#B91D73", "#4A00E0"]
        case .amber:      return ["#F6D365", "#FDA085"]
        case .tahoeDark:  return ["#1C1E26", "#0F1117"]
        case .tahoeLight: return ["#F3F5F9", "#DDE3EE"]
        }
    }
}

public enum CanvasAspectRatio: String, CaseIterable, Sendable {
    case auto = "auto"
    case r16_9 = "16:9"
    case r4_3 = "4:3"
    case r1_1 = "1:1"

    public var title: String {
        switch self {
        case .auto:  return tr("Tự động", "Auto")
        case .r16_9: return "16:9"
        case .r4_3:  return "4:3"
        case .r1_1:  return "1:1"
        }
    }

    public var numericRatio: CGFloat? {
        switch self {
        case .auto:  return nil
        case .r16_9: return 16.0 / 9.0
        case .r4_3:  return 4.0 / 3.0
        case .r1_1:  return 1.0
        }
    }
}

// MARK: - Drawn Stroke / Annotation Element Model

public struct DrawnStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var tool: ScreenshotTool
    public var points: [CGPoint] // Coordinates relative to canvas/screen
    public var colorHex: String
    public var lineWidth: CGFloat
    public var text: String
    public var fontSize: CGFloat
    public var textBoxStyle: TextBoxStyle
    public var counterNumber: Int
    public var arrowStyle: ArrowStyle
    public var lineDashStyle: LineDashStyle
    public var blurStyle: BlurStyle
    public var blurIntensity: CGFloat
    public var isFilled: Bool

    public init(
        id: UUID = UUID(),
        tool: ScreenshotTool,
        points: [CGPoint],
        colorHex: String,
        lineWidth: CGFloat,
        text: String = "",
        fontSize: CGFloat = 20,
        textBoxStyle: TextBoxStyle = .solidPill,
        counterNumber: Int = 1,
        arrowStyle: ArrowStyle = .straight,
        lineDashStyle: LineDashStyle = .solid,
        blurStyle: BlurStyle = .pixelated,
        blurIntensity: CGFloat = 14,
        isFilled: Bool = false
    ) {
        self.id = id
        self.tool = tool
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.text = text
        self.fontSize = fontSize
        self.textBoxStyle = textBoxStyle
        self.counterNumber = counterNumber
        self.arrowStyle = arrowStyle
        self.lineDashStyle = lineDashStyle
        self.blurStyle = blurStyle
        self.blurIntensity = blurIntensity
        self.isFilled = isFilled
    }

    public var color: Color {
        Color(hex: colorHex)
    }

    public var nsColor: NSColor {
        NSColor(hex: colorHex) ?? .systemRed
    }

    public var boundingRect: CGRect {
        guard !points.isEmpty else { return .zero }
        if tool == .text {
            let origin = points[0]
            let approxW = max(80, CGFloat(max(4, text.count)) * (fontSize * 0.62) + 24)
            let approxH = max(32, fontSize * 1.55 + 12)
            return CGRect(x: origin.x - 4, y: origin.y - 4, width: approxW, height: approxH)
        }
        if tool == .counter {
            let p0 = points[0]
            let r: CGFloat = max(16, lineWidth * 3.8)
            var rect = CGRect(x: p0.x - r, y: p0.y - r, width: r * 2, height: r * 2)
            if points.count >= 2 {
                let p1 = points[points.count - 1]
                rect = rect.union(CGRect(x: p1.x - 8, y: p1.y - 8, width: 16, height: 16))
            }
            return rect
        }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let pad = max(8, lineWidth + 4)
        return CGRect(x: minX - pad, y: minY - pad, width: max(16, maxX - minX + pad * 2), height: max(16, maxY - minY + pad * 2))
    }

    public mutating func translate(by delta: CGSize) {
        for i in points.indices {
            points[i].x += delta.width
            points[i].y += delta.height
        }
    }
}

public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, topCenter, topRight
    case midLeft, midRight
    case bottomLeft, bottomCenter, bottomRight
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

// MARK: - Screenshot Manager (Snapzy + LightShot Hybrid Engine)

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
    @Published public var isDetailsExpanded: Bool = false {
        didSet {
            UserDefaults.standard.set(isDetailsExpanded, forKey: "screenshot_details_expanded")
        }
    }
    /// Mở ngay cửa sổ Chỉnh sửa Studio (kiểu Snapzy) sau khi thả chuột chọn vùng chụp.
    @Published public var autoOpenEditorAfterCapture: Bool = true {
        didSet {
            UserDefaults.standard.set(autoOpenEditorAfterCapture, forKey: "screenshot_auto_open_editor")
        }
    }

    // Active Snipping State
    @Published public var isActive: Bool = false
    @Published public var isQuickCopyMode: Bool = false
    @Published public var isStudioOpen: Bool = false {
        didSet {
            gIsStudioEditorOpen = isStudioOpen
        }
    }
    @Published public var screenImage: CGImage? = nil
    @Published public var screenNSImage: NSImage? = nil
    @Published public var screenFrame: NSRect = .zero
    @Published public var scaleFactor: CGFloat = 2.0

    // Selection Box (in screen-local coordinates 0...width, 0...height)
    @Published public var selectionRect: CGRect = .zero
    @Published public var hasSelection: Bool = false

    // Studio Editor Image State (cropped base image in Studio Editor)
    @Published public var studioBaseCGImage: CGImage? = nil
    @Published public var studioBaseNSImage: NSImage? = nil
    @Published public var studioLogicalSize: CGSize = .zero
    @Published public var studioCropRect: CGRect = .zero
    @Published public var isCroppingInStudio: Bool = false
    @Published public var studioZoom: CGFloat = 1.0
    @Published public var isSidebarVisible: Bool = true

    // Annotation Tools & Styling
    @Published public var currentTool: ScreenshotTool = .arrow
    @Published public var selectedColorHex: String = "#FF3B30" // Default Red
    @Published public var strokeWidth: CGFloat = 3.5
    @Published public var fontSize: CGFloat = 22.0
    @Published public var textBoxStyle: TextBoxStyle = .solidPill
    @Published public var arrowStyle: ArrowStyle = .straight
    @Published public var lineDashStyle: LineDashStyle = .solid
    @Published public var blurStyle: BlurStyle = .pixelated
    @Published public var blurIntensity: CGFloat = 14.0
    @Published public var isShapeFilled: Bool = false
    @Published public var nextCounterValue: Int = 1

    // Annotations Stack (with Undo / Redo)
    @Published public var strokes: [DrawnStroke] = []
    @Published public var redoStack: [DrawnStroke] = []
    @Published public var activeStroke: DrawnStroke? = nil
    @Published public var selectedStrokeID: UUID? = nil
    @Published public var editingTextStrokeID: UUID? = nil {
        didSet {
            gIsStudioEditingText = (editingTextStrokeID != nil)
        }
    }
    @Published public var editingTextValue: String = ""
    @Published public var editingTextPoint: CGPoint = .zero
    @Published public var isColorPaletteExpanded: Bool = false

    // Studio Beautifier / Canvas Settings (Snapzy Style)
    @Published public var backgroundPreset: StudioBackgroundPreset = .none {
        didSet {
            if backgroundPreset != .none && canvasPadding < 16 {
                canvasPadding = 40
                if cornerRadius < 8 { cornerRadius = 12 }
                if shadowIntensity < 10 { shadowIntensity = 45 }
            }
        }
    }
    @Published public var canvasPadding: CGFloat = 0
    @Published public var cornerRadius: CGFloat = 0
    @Published public var shadowIntensity: CGFloat = 0
    @Published public var spotlightOpacity: CGFloat = 0.60
    @Published public var aspectRatio: CanvasAspectRatio = .auto
    @Published public var watermarkText: String = ""
    @Published public var watermarkMode: WatermarkMode = .none
    @Published public var watermarkOpacity: CGFloat = 0.35

    // OCR & Auto-Redaction State
    @Published public var extractedOCRText: String? = nil
    @Published public var isOCRPopoverPresented: Bool = false
    @Published public var isScanningSensitiveData: Bool = false
    @Published public var statusBannerMessage: String? = nil
    private var statusBannerToken: Int = 0

    // Drag Interaction Tracking (Stored here to avoid CommandLineTools SwiftUIMacros @State issue)
    @Published public var activeHandle: ResizeHandle? = nil
    @Published public var dragStartPoint: CGPoint = .zero
    @Published public var dragStartRect: CGRect = .zero
    @Published public var isDraggingSelection: Bool = false
    @Published public var isSpaceHeld: Bool = false
    public var movingStrokeStartPoints: [CGPoint]? = nil
    public var cropDragHandle: ResizeHandle? = nil
    public var cropDragStartRect: CGRect = .zero

    // Palette Colors (Snapzy + LightShot)
    public let availableColors: [String] = [
        "#FF3B30", // Đỏ
        "#FF9500", // Cam
        "#FFCC00", // Vàng
        "#34C759", // Xanh lá
        "#00C7BE", // Xanh ngọc
        "#007AFF", // Xanh dương
        "#AF52DE", // Tím
        "#FF2D55", // Hồng
        "#FFFFFF", // Trắng
        "#000000"  // Đen
    ]

    private var overlayPanel: NSPanel?
    private var studioWindow: NSWindow?
    private var pinnedWindows: [NSWindow] = []
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init() {
        if UserDefaults.standard.object(forKey: "screenshot_enabled") != nil {
            self.isScreenshotEnabled = UserDefaults.standard.bool(forKey: "screenshot_enabled")
        } else {
            self.isScreenshotEnabled = true
        }
        if UserDefaults.standard.object(forKey: "screenshot_auto_open_editor") != nil {
            self.autoOpenEditorAfterCapture = UserDefaults.standard.bool(forKey: "screenshot_auto_open_editor")
        } else {
            self.autoOpenEditorAfterCapture = true
        }
        self.isDetailsExpanded = UserDefaults.standard.bool(forKey: "screenshot_details_expanded")
        gIsScreenshotEnabled = self.isScreenshotEnabled
    }

    // MARK: - Status Feedback Banner

    public func showStatusBanner(_ message: String) {
        statusBannerToken &+= 1
        let token = statusBannerToken
        withAnimation(.easeInOut(duration: 0.18)) {
            statusBannerMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self, self.statusBannerToken == token else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                self.statusBannerMessage = nil
            }
        }
    }

    // MARK: - Start Snipping / Freeze Screen

    public func startCapture(quickCopy: Bool = false) {
        guard isScreenshotEnabled else { return }
        guard !isActive else { return }

        // Close Studio Editor if currently open so user can take a fresh screenshot
        if isStudioOpen {
            closeStudioEditor()
        }

        // Check Screen Recording Permission
        if !PermissionsManager.checkScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            PermissionsManager.shared.openScreenCaptureSettings()
            return
        }

        // 1. Identify screen under mouse cursor
        let targetScreen = preferredTargetScreen()

        let frame = targetScreen.frame
        self.screenFrame = frame

        // 2. Capture synchronous instant high-res snapshot of target screen
        guard let capturedImage = captureScreenImage(screen: targetScreen) else {
            appLog("⚠️ ScreenshotManager: Failed to capture screen image.")
            return
        }

        self.screenImage = capturedImage
        self.scaleFactor = CGFloat(capturedImage.width) / frame.width
        let nsImg = NSImage(cgImage: capturedImage, size: frame.size)
        self.screenNSImage = nsImg

        // Reset state
        self.isQuickCopyMode = quickCopy
        self.selectionRect = .zero
        self.hasSelection = false
        self.strokes = []
        self.redoStack = []
        self.activeStroke = nil
        self.selectedStrokeID = nil
        self.editingTextStrokeID = nil
        self.currentTool = .arrow
        self.selectedColorHex = "#FF3B30"
        self.nextCounterValue = 1
        self.isColorPaletteExpanded = false
        self.isSpaceHeld = false
        gIsSpacePressed = false

        // 3. Create or update overlay panel on the target screen
        createOrUpdateOverlayPanel(on: targetScreen)

        self.isActive = true
        gIsScreenshotActive = true
    }

    /// Chụp toàn bộ màn hình hiện tại và mở ngay trong Studio Editor.
    public func captureFullScreenToStudio() {
        guard isScreenshotEnabled else { return }

        // Nếu đang mở overlay chọn vùng (nhấn nút trên thanh gợi ý), dùng ảnh đang đóng băng
        if isActive, screenImage != nil {
            self.selectionRect = CGRect(origin: .zero, size: screenFrame.size)
            self.hasSelection = true
            openStudioEditor()
            return
        }

        if isStudioOpen {
            closeStudioEditor()
        }

        if !PermissionsManager.checkScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            PermissionsManager.shared.openScreenCaptureSettings()
            return
        }

        let targetScreen = preferredTargetScreen()
        guard let capturedImage = captureScreenImage(screen: targetScreen) else {
            appLog("⚠️ ScreenshotManager: Failed to capture full screen image.")
            return
        }

        let frame = targetScreen.frame
        let scale = max(1.0, CGFloat(capturedImage.width) / max(1.0, frame.width))
        presentStudioWithImage(
            croppedCG: capturedImage,
            logicalSize: frame.size,
            scaleFactor: scale,
            strokes: [],
            preferredScreen: targetScreen
        )
    }

    /// Chụp cửa sổ ứng dụng đang hoạt động hiện tại và mở ngay trong Studio Editor.
    public func captureActiveWindowToStudio() {
        guard isScreenshotEnabled else { return }

        if isActive {
            cancelCapture()
        }

        let wasStudioOpen = isStudioOpen
        if wasStudioOpen {
            closeStudioEditor()
        }

        if !PermissionsManager.checkScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            PermissionsManager.shared.openScreenCaptureSettings()
            return
        }

        guard let target = findActiveWindowTarget(excludingOwnProcess: wasStudioOpen) else {
            NSSound.beep()
            appLog("⚠️ ScreenshotManager: Không tìm thấy cửa sổ ứng dụng hiện tại để chụp.")
            return
        }

        guard let capturedImage = captureWindowImage(windowID: target.windowID) else {
            appLog("⚠️ ScreenshotManager: Failed to capture active window (id=\(target.windowID)).")
            return
        }

        let targetScreen = screenContaining(quartzRect: target.bounds) ?? preferredTargetScreen()
        let imgRatio = CGFloat(capturedImage.width) / max(1.0, CGFloat(capturedImage.height))
        let boundsRatio = target.bounds.width / max(1.0, target.bounds.height)

        let logicalSize: CGSize
        let scale: CGFloat
        if abs(imgRatio - boundsRatio) < 0.05, target.bounds.width >= 10, target.bounds.height >= 10 {
            logicalSize = CGSize(width: round(target.bounds.width), height: round(target.bounds.height))
            scale = max(1.0, CGFloat(capturedImage.width) / max(1.0, logicalSize.width))
        } else {
            let backing = max(1.0, targetScreen.backingScaleFactor)
            logicalSize = CGSize(
                width: max(1.0, round(CGFloat(capturedImage.width) / backing)),
                height: max(1.0, round(CGFloat(capturedImage.height) / backing))
            )
            scale = backing
        }

        presentStudioWithImage(
            croppedCG: capturedImage,
            logicalSize: logicalSize,
            scaleFactor: scale,
            strokes: [],
            preferredScreen: targetScreen
        )
    }

    /// Chụp toàn bộ màn hình hiện tại và sao chép thẳng vào Clipboard (không lưu file, không mở Studio).
    public func captureFullScreenToClipboard() {
        if screenImage == nil {
            startCapture(quickCopy: true)
        }
        guard screenImage != nil else { return }
        self.selectionRect = CGRect(origin: .zero, size: screenFrame.size)
        self.hasSelection = true
        copyToClipboard()
    }

    // MARK: - Screen & Active Window Resolution

    private func preferredTargetScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLoc) }
            ?? NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func screenContaining(quartzRect: CGRect) -> NSScreen? {
        guard let primaryH = NSScreen.screens.first?.frame.height else { return nil }
        let appKitRect = CGRect(
            x: quartzRect.origin.x,
            y: primaryH - (quartzRect.origin.y + quartzRect.height),
            width: quartzRect.width,
            height: quartzRect.height
        )
        let center = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        if let byCenter = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return byCenter
        }
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let inter = screen.frame.intersection(appKitRect)
            if !inter.isNull && !inter.isEmpty {
                let area = inter.width * inter.height
                if area > bestArea {
                    bestArea = area
                    bestScreen = screen
                }
            }
        }
        return bestScreen
    }

    private func isWindowIntersectingAnyScreen(_ quartzRect: CGRect) -> Bool {
        guard let primaryH = NSScreen.screens.first?.frame.height else { return true }
        let appKitRect = CGRect(
            x: quartzRect.origin.x,
            y: primaryH - (quartzRect.origin.y + quartzRect.height),
            width: quartzRect.width,
            height: quartzRect.height
        )
        return NSScreen.screens.contains { $0.frame.intersects(appKitRect) }
    }

    private func focusedWindowBoundsAX(pid: pid_t) -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let appAX = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appAX, 0.05)

        var focusedObj: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appAX, kAXFocusedWindowAttribute as CFString, &focusedObj) == .success,
              let focusedCF = focusedObj,
              CFGetTypeID(focusedCF) == AXUIElementGetTypeID() else {
            return nil
        }
        let winAX = focusedCF as! AXUIElement
        AXUIElementSetMessagingTimeout(winAX, 0.05)

        var posObj: CFTypeRef?
        var sizeObj: CFTypeRef?
        guard AXUIElementCopyAttributeValue(winAX, kAXPositionAttribute as CFString, &posObj) == .success,
              AXUIElementCopyAttributeValue(winAX, kAXSizeAttribute as CFString, &sizeObj) == .success,
              let posCF = posObj, CFGetTypeID(posCF) == AXValueGetTypeID(),
              let sizeCF = sizeObj, CFGetTypeID(sizeCF) == AXValueGetTypeID() else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posCF as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeCF as! AXValue, .cgSize, &size)
        guard size.width >= 40 && size.height >= 40 else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func findActiveWindowTarget(excludingOwnProcess: Bool) -> (windowID: CGWindowID, bounds: CGRect)? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        struct WindowCandidate {
            let id: CGWindowID
            let pid: pid_t
            let layer: Int
            let bounds: CGRect
        }

        let systemOwners: Set<String> = [
            "Window Server", "WindowServer", "Dock", "Notification Center", "Control Center", "Spotlight"
        ]

        var candidates: [WindowCandidate] = []
        candidates.reserveCapacity(windowList.count)

        for entry in windowList {
            guard let num = entry[kCGWindowNumber as String] as? UInt32,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  layer >= 0 && layer <= 20,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 40 && bounds.height >= 40 else {
                continue
            }
            let alpha = (entry[kCGWindowAlpha as String] as? Double) ?? 1.0
            guard alpha > 0.01 else { continue }
            let owner = (entry[kCGWindowOwnerName as String] as? String) ?? ""
            if systemOwners.contains(owner) { continue }
            guard isWindowIntersectingAnyScreen(bounds) else { continue }

            candidates.append(WindowCandidate(id: CGWindowID(num), pid: pid, layer: layer, bounds: bounds))
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        if let frontPID, (frontPID != myPID || !excludingOwnProcess) {
            let frontCandidates = candidates.filter { $0.pid == frontPID }
            if !frontCandidates.isEmpty {
                // 1. Ưu tiên cửa sổ đang thực sự focus theo Accessibility API
                if let axBounds = focusedWindowBoundsAX(pid: frontPID) {
                    let tol: CGFloat = 6.0
                    let matchesAX: (WindowCandidate) -> Bool = { c in
                        abs(c.bounds.origin.x - axBounds.origin.x) <= tol &&
                        abs(c.bounds.origin.y - axBounds.origin.y) <= tol &&
                        abs(c.bounds.width - axBounds.width) <= tol &&
                        abs(c.bounds.height - axBounds.height) <= tol
                    }
                    if let exactNormal = frontCandidates.first(where: { $0.layer == 0 && matchesAX($0) }) {
                        return (exactNormal.id, exactNormal.bounds)
                    }
                    if let exactAny = frontCandidates.first(where: matchesAX) {
                        return (exactAny.id, exactAny.bounds)
                    }
                }

                // 2. Fallback: cửa sổ layer 0 trên cùng của ứng dụng đang focus
                if let topNormal = frontCandidates.first(where: { $0.layer == 0 }) {
                    return (topNormal.id, topNormal.bounds)
                }

                // 3. Nếu app chỉ mở hộp thoại/panel nổi
                if let topFloating = frontCandidates.first(where: { $0.bounds.width >= 80 && $0.bounds.height >= 80 }) {
                    return (topFloating.id, topFloating.bounds)
                }
            }
        }

        // Fallback khi Finder không có cửa sổ nào đang mở, hoặc HyperMac chỉ vừa mở popover/Studio
        let otherNormal = candidates.filter { $0.pid != myPID && $0.layer == 0 }
        if let primaryH = NSScreen.screens.first?.frame.height {
            let mouseLoc = NSEvent.mouseLocation
            let mouseQuartz = CGPoint(x: mouseLoc.x, y: primaryH - mouseLoc.y)
            if let underMouse = otherNormal.first(where: { $0.bounds.contains(mouseQuartz) }) {
                return (underMouse.id, underMouse.bounds)
            }
        }

        if excludingOwnProcess || frontPID == myPID, let topOther = otherNormal.first {
            return (topOther.id, topOther.bounds)
        }

        return nil
    }

    private func captureWindowImage(windowID: CGWindowID) -> CGImage? {
        let listOpt = CGWindowListOption.optionIncludingWindow.rawValue
        let imgOpt = CGWindowImageOption([.boundsIgnoreFraming, .bestResolution]).rawValue

        if CGPreflightScreenCaptureAccess(),
           let fn = cgCaptureSym,
           let unmanaged = fn(CGRect.null, listOpt, windowID, imgOpt) {
            let img = unmanaged.takeRetainedValue()
            if img.width >= 10 && img.height >= 10 {
                return img
            }
        }

        let tempPath = "/tmp/hypermac_window_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let res = shell("/usr/sbin/screencapture -x -o -l \(windowID) \"\(tempPath)\"")
        if res.exitCode == 0 {
            let fileURL = URL(fileURLWithPath: tempPath)
            if let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(src, 0, nil),
               image.width >= 10 && image.height >= 10 {
                return image
            }
        }

        if let fn = cgCaptureSym,
           let unmanaged = fn(CGRect.null, listOpt, windowID, imgOpt) {
            let img = unmanaged.takeRetainedValue()
            if img.width >= 10 && img.height >= 10 {
                return img
            }
        }

        return nil
    }

    // MARK: - Capture Screen CGImage

    private func captureScreenImage(screen: NSScreen) -> CGImage? {
        let primaryH = NSScreen.screens[0].frame.height
        let f = screen.frame
        let cgRect = CGRect(
            x: f.origin.x,
            y: primaryH - (f.origin.y + f.height),
            width: f.width,
            height: f.height
        )

        // Khi tiến trình đã có quyền CGPreflightScreenCaptureAccess trực tiếp, chụp tức thì qua CoreGraphics
        if CGPreflightScreenCaptureAccess(),
           let fn = cgCaptureSym,
           let unmanaged = fn(cgRect, 1, 0, 0) {
            return unmanaged.takeRetainedValue()
        }

        // Trường hợp người dùng vừa cấp quyền trong System Settings nhưng chưa khởi động lại app:
        // dùng tiến trình con /usr/sbin/screencapture để nhận token TCC mới ngay lập tức, tránh chụp màn hình đen.
        let tempPath = "/tmp/hypermac_screenshot_\(UUID().uuidString).png"
        let res = shell("/usr/sbin/screencapture -x -C -R \(Int(cgRect.origin.x)),\(Int(cgRect.origin.y)),\(Int(cgRect.width)),\(Int(cgRect.height)) \"\(tempPath)\"")
        if res.exitCode == 0,
           let nsImg = NSImage(contentsOfFile: tempPath),
           let image = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try? FileManager.default.removeItem(atPath: tempPath)
            return image
        }
        try? FileManager.default.removeItem(atPath: tempPath)

        if let fn = cgCaptureSym, let unmanaged = fn(cgRect, 1, 0, 0) {
            return unmanaged.takeRetainedValue()
        }

        return nil
    }

    // MARK: - Switch Screen (Tab Shortcut for Multi-Display setups)

    public func switchScreen() {
        guard NSScreen.screens.count > 1 else { return }
        let screens = NSScreen.screens
        guard let currentIndex = screens.firstIndex(where: { $0.frame == self.screenFrame }) else { return }
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]

        self.screenFrame = nextScreen.frame
        guard let capturedImage = captureScreenImage(screen: nextScreen) else { return }
        self.screenImage = capturedImage
        self.scaleFactor = CGFloat(capturedImage.width) / nextScreen.frame.width
        self.screenNSImage = NSImage(cgImage: capturedImage, size: nextScreen.frame.size)

        self.selectionRect = .zero
        self.hasSelection = false
        self.strokes = []
        self.redoStack = []
        self.activeStroke = nil

        createOrUpdateOverlayPanel(on: nextScreen)
    }

    // MARK: - Overlay Window Presentation

    private func createOrUpdateOverlayPanel(on screen: NSScreen) {
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
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true

        let hostingView = ScreenshotHostingView(rootView: ScreenshotOverlayView(manager: self))
        if #available(macOS 13.0, *) {
            hostingView.safeAreaRegions = []
        }
        panel.contentView = hostingView
        self.overlayPanel = panel

        panel.setFrame(screen.frame, display: true)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSCursor.crosshair.set()
    }

    // MARK: - Transition from Snipping Overlay to Snapzy Studio Editor

    public func openStudioEditor() {
        guard let baseCG = screenImage,
              selectionRect.width >= 10,
              selectionRect.height >= 10 else { return }

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

        // Convert any strokes drawn on the screen overlay into image-local coordinates
        let offset = selectionRect.origin
        let convertedStrokes: [DrawnStroke] = strokes.map { s in
            var copy = s
            copy.points = s.points.map { CGPoint(x: $0.x - offset.x, y: $0.y - offset.y) }
            return copy
        }

        presentStudioWithImage(
            croppedCG: croppedCG,
            logicalSize: logicalSize,
            scaleFactor: scale,
            strokes: convertedStrokes,
            preferredScreen: targetScreen
        )
    }

    private func presentStudioWithImage(
        croppedCG: CGImage,
        logicalSize: CGSize,
        scaleFactor: CGFloat,
        strokes: [DrawnStroke],
        preferredScreen: NSScreen?
    ) {
        // Dismiss any active snipping overlay
        if let panel = overlayPanel {
            panel.orderOut(nil)
            panel.contentView = nil
            overlayPanel = nil
        }
        self.isActive = false
        self.isQuickCopyMode = false
        gIsScreenshotActive = false
        self.screenImage = nil
        self.screenNSImage = nil
        self.selectionRect = .zero
        self.hasSelection = false
        self.isSpaceHeld = false
        gIsSpacePressed = false
        NSCursor.arrow.set()

        // Populate Studio Editor state
        self.scaleFactor = scaleFactor
        self.studioBaseCGImage = croppedCG
        self.studioLogicalSize = logicalSize
        self.studioBaseNSImage = NSImage(cgImage: croppedCG, size: logicalSize)
        self.studioCropRect = CGRect(origin: .zero, size: logicalSize)
        self.isCroppingInStudio = false
        self.strokes = strokes
        self.redoStack = []
        self.activeStroke = nil
        self.selectedStrokeID = nil
        self.editingTextStrokeID = nil
        self.extractedOCRText = nil
        self.isOCRPopoverPresented = false
        self.studioZoom = 1.0

        // Reset canvas beautifier to clean defaults on each new capture
        self.backgroundPreset = .none
        self.canvasPadding = 0
        self.cornerRadius = 0
        self.shadowIntensity = 0
        self.aspectRatio = .auto

        if currentTool == .move || currentTool == .crop {
            currentTool = .arrow
        }

        presentStudioWindow(preferredScreen: preferredScreen)
    }

    private func presentStudioWindow(preferredScreen: NSScreen? = nil) {
        if let existing = studioWindow {
            existing.orderOut(nil)
            existing.contentView = nil
            studioWindow = nil
        }

        let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let winW = min(max(980, studioLogicalSize.width + 360), visible.width - 48)
        let winH = min(max(660, studioLogicalSize.height + 220), visible.height - 48)
        let originX = visible.midX - winW / 2
        let originY = visible.midY - winH / 2

        let window = ScreenshotStudioWindow(
            contentRect: NSRect(x: originX, y: originY, width: winW, height: winH),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = tr("HyperMac Studio — Chỉnh sửa & Chú thích ảnh", "HyperMac Studio — Screenshot Annotate & Editor")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 560)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: ScreenshotStudioEditorView(manager: self))
        window.contentView = hosting
        self.studioWindow = window
        self.isStudioOpen = true

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
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
        self.strokes = []
        self.redoStack = []
        self.activeStroke = nil
        self.selectedStrokeID = nil
        self.editingTextStrokeID = nil
    }

    public func handleStudioEscape() {
        if editingTextStrokeID != nil {
            commitActiveTextEditing()
        } else if isCroppingInStudio {
            isCroppingInStudio = false
            currentTool = .select
        } else if selectedStrokeID != nil {
            selectedStrokeID = nil
        } else {
            closeStudioEditor()
        }
    }

    public func handleStudioKeyCommand(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isStudioOpen else { return false }

        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasAlt = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        // Khi đang nhập chữ vào chú thích văn bản, chỉ bắt Esc để kết thúc nhập,
        // nhường ⌘C / ⌘V / ⌘A / ⌫ cho ô TextField xử lý bình thường.
        if editingTextStrokeID != nil {
            if keyCode == 53 && !hasCmd && !hasCtrl && !hasAlt && !hasShift {
                commitActiveTextEditing()
                return true
            }
            return false
        }

        // ⌘C (keycode 8) -> Sao chép ảnh vào Clipboard & Đóng Studio ngay
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 8 {
            copyToClipboard()
            return true
        }

        // ⌘S (keycode 1) -> Lưu nhanh PNG vào Downloads/Screenshots & Đóng Studio
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 1 {
            saveToDownloads()
            return true
        }

        // ⌘⇧S (keycode 1 + Shift) -> Mở hộp thoại Lưu thành...
        if hasCmd && !hasCtrl && !hasAlt && hasShift && keyCode == 1 {
            saveAsWithPanel()
            return true
        }

        // ⌘Z / ⌘⇧Z (keycode 6) -> Hoàn tác / Làm lại nét vẽ
        if hasCmd && !hasCtrl && !hasAlt && keyCode == 6 {
            if hasShift {
                redoLastStroke()
            } else {
                undoLastStroke()
            }
            return true
        }

        // ⌘W (keycode 13) -> Đóng cửa sổ Studio
        if hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 13 {
            closeStudioEditor()
            return true
        }

        // Enter / Return (keycode 36 hoặc 76) -> Áp dụng cắt ảnh nếu đang Crop, ngược lại Sao chép & Đóng
        if !hasCmd && !hasCtrl && !hasAlt && !hasShift && (keyCode == 36 || keyCode == 76) {
            if isCroppingInStudio {
                applyStudioCrop()
            } else {
                copyToClipboard()
            }
            return true
        }

        // Delete / Backspace (keycode 51 hoặc 117) -> Xoá chú thích đang chọn
        if !hasCmd && !hasCtrl && !hasAlt && !hasShift && (keyCode == 51 || keyCode == 117) {
            if selectedStrokeID != nil {
                deleteSelectedStroke()
                return true
            }
        }

        // Esc (keycode 53) -> Huỷ chọn / Huỷ cắt / Đóng cửa sổ Studio
        if !hasCmd && !hasCtrl && !hasAlt && !hasShift && keyCode == 53 {
            handleStudioEscape()
            return true
        }

        return false
    }

    public func resetCanvasEffects() {
        withAnimation(.easeInOut(duration: 0.15)) {
            backgroundPreset = .none
            canvasPadding = 0
            cornerRadius = 0
            shadowIntensity = 0
            aspectRatio = .auto
            watermarkMode = .none
        }
        showStatusBanner(tr("Đã đặt lại nền, khoảng đệm, bo góc và bóng đổ", "Reset background, padding, corners & shadow"))
    }

    // MARK: - Cancel Capture

    public func cancelCapture() {
        if let panel = overlayPanel {
            panel.orderOut(nil)
            panel.contentView = nil
            overlayPanel = nil
        }
        self.isActive = false
        self.isQuickCopyMode = false
        gIsScreenshotActive = false
        self.screenImage = nil
        self.screenNSImage = nil
        self.isSpaceHeld = false
        gIsSpacePressed = false
        NSCursor.arrow.set()
        self.strokes = []
        self.redoStack = []
        self.activeStroke = nil
        self.selectionRect = .zero
        self.hasSelection = false
        self.isSpaceHeld = false
    }

    // MARK: - Stroke & Annotation Management (Undo / Redo / Select / Delete / Text)

    public func addStroke(_ stroke: DrawnStroke) {
        strokes.append(stroke)
        redoStack.removeAll()
        selectedStrokeID = stroke.id
    }

    public func undoLastStroke() {
        commitActiveTextEditing()
        guard let last = strokes.popLast() else { return }
        redoStack.append(last)
        if selectedStrokeID == last.id {
            selectedStrokeID = nil
        }
    }

    public func redoLastStroke() {
        commitActiveTextEditing()
        guard let next = redoStack.popLast() else { return }
        strokes.append(next)
        selectedStrokeID = next.id
    }

    public func deleteSelectedStroke() {
        guard let id = selectedStrokeID,
              let idx = strokes.firstIndex(where: { $0.id == id }) else { return }
        let removed = strokes.remove(at: idx)
        redoStack.append(removed)
        selectedStrokeID = nil
    }

    public func clearAllStrokes() {
        commitActiveTextEditing()
        guard !strokes.isEmpty else { return }
        strokes.removeAll()
        selectedStrokeID = nil
        nextCounterValue = 1
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
        selectedStrokeID = newStroke.id
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
                if selectedStrokeID == id { selectedStrokeID = nil }
            } else {
                strokes[idx].text = editingTextValue
            }
        }
        editingTextStrokeID = nil
        editingTextValue = ""
    }

    public func hitTestStroke(at point: CGPoint) -> DrawnStroke? {
        for stroke in strokes.reversed() {
            if stroke.boundingRect.insetBy(dx: -6, dy: -6).contains(point) {
                return stroke
            }
        }
        return nil
    }

    // MARK: - Studio Crop & Rotate 90°

    public func applyStudioCrop() {
        guard let baseCG = studioBaseCGImage else { return }
        let crop = studioCropRect.intersection(CGRect(origin: .zero, size: studioLogicalSize))
        guard crop.width >= 20 && crop.height >= 20 else {
            isCroppingInStudio = false
            return
        }

        let scaleX = CGFloat(baseCG.width) / max(1, studioLogicalSize.width)
        let scaleY = CGFloat(baseCG.height) / max(1, studioLogicalSize.height)
        let pixelRect = CGRect(
            x: round(crop.origin.x * scaleX),
            y: round(crop.origin.y * scaleY),
            width: round(crop.width * scaleX),
            height: round(crop.height * scaleY)
        )
        guard let cropped = baseCG.cropping(to: pixelRect) else { return }

        // Shift existing strokes by crop origin
        for i in strokes.indices {
            strokes[i].translate(by: CGSize(width: -crop.origin.x, height: -crop.origin.y))
        }

        let newSize = CGSize(width: round(crop.width), height: round(crop.height))
        studioBaseCGImage = cropped
        studioLogicalSize = newSize
        studioBaseNSImage = NSImage(cgImage: cropped, size: newSize)
        studioCropRect = CGRect(origin: .zero, size: newSize)
        isCroppingInStudio = false
        if currentTool == .crop {
            currentTool = .select
        }
        showStatusBanner(tr("Đã cắt ảnh (\(Int(newSize.width)) × \(Int(newSize.height)))", "Cropped image (\(Int(newSize.width)) × \(Int(newSize.height)))"))
    }

    public func rotateStudioImage(clockwise: Bool) {
        commitActiveTextEditing()
        guard let baseCG = studioBaseCGImage else { return }
        let srcW = baseCG.width
        let srcH = baseCG.height
        let dstW = srcH
        let dstH = srcW

        guard let colorSpace = baseCG.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: dstW,
                  height: dstH,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return }

        ctx.saveGState()
        if clockwise {
            ctx.translateBy(x: 0, y: CGFloat(dstH))
            ctx.rotate(by: -.pi / 2)
        } else {
            ctx.translateBy(x: CGFloat(dstW), y: 0)
            ctx.rotate(by: .pi / 2)
        }
        ctx.draw(baseCG, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
        ctx.restoreGState()

        guard let rotatedCG = ctx.makeImage() else { return }
        let oldLogical = studioLogicalSize
        let newLogical = CGSize(width: oldLogical.height, height: oldLogical.width)

        // Rotate existing annotation points in top-left logical coordinates
        for i in strokes.indices {
            strokes[i].points = strokes[i].points.map { pt in
                if clockwise {
                    return CGPoint(x: oldLogical.height - pt.y, y: pt.x)
                } else {
                    return CGPoint(x: pt.y, y: oldLogical.width - pt.x)
                }
            }
        }

        studioBaseCGImage = rotatedCG
        studioLogicalSize = newLogical
        studioBaseNSImage = NSImage(cgImage: rotatedCG, size: newLogical)
        studioCropRect = CGRect(origin: .zero, size: newLogical)
    }

    // MARK: - Apple Vision OCR & Auto-Redaction (Snapzy Smart Privacy)

    public func extractTextViaVision() {
        let sourceCG = isStudioOpen ? studioBaseCGImage : renderCompositeImage()
        guard let cgImage = sourceCG else { return }

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n")
            DispatchQueue.main.async {
                guard let self else { return }
                self.extractedOCRText = joined
                self.isOCRPopoverPresented = true
                if !joined.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(joined, forType: .string)
                    self.showStatusBanner(tr("Đã trích xuất \(lines.count) dòng văn bản & chép vào Clipboard", "Extracted \(lines.count) text lines & copied to Clipboard"))
                } else {
                    self.showStatusBanner(tr("Không tìm thấy văn bản nào trong ảnh", "No text detected in image"))
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["vi-VN", "en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    public func autoRedactSensitiveData() {
        guard let cgImage = studioBaseCGImage else { return }
        let logicalSize = studioLogicalSize
        isScanningSensitiveData = true

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            var sensitiveRects: [CGRect] = []

            let patterns = [
                "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}",          // Email
                "(?:\\+?84|0)[0-9]{8,10}",                                    // Phone VN
                "\\b(?:\\d[ -]*?){13,19}\\b",                                 // Credit card / ID number
                "\\b(?:sk-|ghp_|gho_|AIza|AKIA|ya29\\.|eyJ)[A-Za-z0-9_\\-\\.]{10,}", // API keys / JWT
                "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"                            // IPv4 address
            ]
            let regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0) }

            for obs in observations {
                guard let top = obs.topCandidates(1).first else { continue }
                let str = top.string
                let fullRange = NSRange(str.startIndex..<str.endIndex, in: str)
                let isSensitive = regexes.contains { $0.firstMatch(in: str, options: [], range: fullRange) != nil }
                    || str.lowercased().contains("password")
                    || str.lowercased().contains("mật khẩu")
                    || str.lowercased().contains("secret")
                    || str.lowercased().contains("token")

                if isSensitive {
                    let bb = obs.boundingBox // Vision bottom-left normalized (0...1)
                    let rect = CGRect(
                        x: bb.origin.x * logicalSize.width,
                        y: (1.0 - bb.origin.y - bb.height) * logicalSize.height,
                        width: bb.width * logicalSize.width,
                        height: bb.height * logicalSize.height
                    ).insetBy(dx: -4, dy: -2)
                    sensitiveRects.append(rect)
                }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isScanningSensitiveData = false
                if sensitiveRects.isEmpty {
                    self.showStatusBanner(tr("Không tìm thấy dữ liệu nhạy cảm (Email, SĐT, Key...)", "No sensitive data found"))
                } else {
                    for r in sensitiveRects {
                        let p1 = CGPoint(x: r.minX, y: r.minY)
                        let p2 = CGPoint(x: r.maxX, y: r.maxY)
                        self.strokes.append(DrawnStroke(
                            tool: .blur,
                            points: [p1, p2],
                            colorHex: self.selectedColorHex,
                            lineWidth: 3,
                            blurStyle: self.blurStyle,
                            blurIntensity: self.blurIntensity
                        ))
                    }
                    self.showStatusBanner(tr("Đã tự động làm mờ \(sensitiveRects.count) vùng nhạy cảm", "Auto-redacted \(sensitiveRects.count) sensitive regions"))
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["vi-VN", "en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - High-Res Composite Render Engine (Supports Both Snipping & Full Studio Canvas)

    public func renderCompositeImage() -> CGImage? {
        if isStudioOpen {
            return renderStudioCompositeImage()
        }
        guard let baseCG = screenImage else { return nil }
        guard selectionRect.width >= 5 && selectionRect.height >= 5 else { return nil }

        let scale = self.scaleFactor
        let pixelCropRect = CGRect(
            x: round(selectionRect.origin.x * scale),
            y: round(selectionRect.origin.y * scale),
            width: round(selectionRect.width * scale),
            height: round(selectionRect.height * scale)
        )
        guard let croppedBase = baseCG.cropping(to: pixelCropRect) else { return nil }
        let localStrokes: [DrawnStroke] = strokes.map { s in
            var copy = s
            copy.points = s.points.map { CGPoint(x: $0.x - selectionRect.origin.x, y: $0.y - selectionRect.origin.y) }
            return copy
        }
        return renderImageWithAnnotations(
            baseCG: croppedBase,
            logicalSize: selectionRect.size,
            strokes: localStrokes,
            backgroundPreset: .none,
            padding: 0,
            cornerRadius: 0,
            shadowIntensity: 0,
            aspectRatio: .auto,
            spotlightOpacity: spotlightOpacity,
            watermarkMode: .none,
            watermarkText: "",
            watermarkOpacity: 0.35
        )
    }

    public func renderStudioCompositeImage() -> CGImage? {
        commitActiveTextEditing()
        guard let baseCG = studioBaseCGImage else { return nil }
        return renderImageWithAnnotations(
            baseCG: baseCG,
            logicalSize: studioLogicalSize,
            strokes: strokes,
            backgroundPreset: backgroundPreset,
            padding: canvasPadding,
            cornerRadius: cornerRadius,
            shadowIntensity: shadowIntensity,
            aspectRatio: aspectRatio,
            spotlightOpacity: spotlightOpacity,
            watermarkMode: watermarkMode,
            watermarkText: watermarkText,
            watermarkOpacity: watermarkOpacity
        )
    }

    private func renderImageWithAnnotations(
        baseCG: CGImage,
        logicalSize: CGSize,
        strokes: [DrawnStroke],
        backgroundPreset: StudioBackgroundPreset,
        padding: CGFloat,
        cornerRadius: CGFloat,
        shadowIntensity: CGFloat,
        aspectRatio: CanvasAspectRatio,
        spotlightOpacity: CGFloat,
        watermarkMode: WatermarkMode,
        watermarkText: String,
        watermarkOpacity: CGFloat
    ) -> CGImage? {
        let scale = CGFloat(baseCG.width) / max(1, logicalSize.width)
        let imgW = CGFloat(baseCG.width)
        let imgH = CGFloat(baseCG.height)
        guard imgW > 0 && imgH > 0 else { return nil }

        guard let colorSpace = baseCG.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        // Step 1: Render the inner annotated image (base screenshot + blur/pixelate + spotlight + vector/text annotations)
        guard let innerCtx = CGContext(
            data: nil,
            width: Int(imgW),
            height: Int(imgH),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let fullImgRect = CGRect(x: 0, y: 0, width: imgW, height: imgH)
        innerCtx.draw(baseCG, in: fullImgRect)

        // 1A. Render Blur / Pixelate strokes directly on the image pixels
        let blurStrokes = strokes.filter { $0.tool == .blur && $0.points.count >= 2 }
        if !blurStrokes.isEmpty {
            let pixelatedCG = generateFilteredCGImage(from: baseCG, style: .pixelated, scale: scale)
            let gaussianCG = generateFilteredCGImage(from: baseCG, style: .gaussian, scale: scale)

            for bs in blurStrokes {
                let p1 = bs.points[0]
                let p2 = bs.points[bs.points.count - 1]
                let logicalRect = CGRect(
                    x: min(p1.x, p2.x),
                    y: min(p1.y, p2.y),
                    width: abs(p2.x - p1.x),
                    height: abs(p2.y - p1.y)
                )
                // Convert top-left logical rect to CG bottom-left pixel rect
                let cgRect = CGRect(
                    x: logicalRect.origin.x * scale,
                    y: imgH - (logicalRect.origin.y + logicalRect.height) * scale,
                    width: logicalRect.width * scale,
                    height: logicalRect.height * scale
                )
                innerCtx.saveGState()
                innerCtx.clip(to: cgRect)
                switch bs.blurStyle {
                case .pixelated:
                    if let px = pixelatedCG { innerCtx.draw(px, in: fullImgRect) }
                case .gaussian:
                    if let gs = gaussianCG { innerCtx.draw(gs, in: fullImgRect) }
                case .solidTape:
                    innerCtx.setFillColor(bs.nsColor.cgColor)
                    innerCtx.fill(cgRect)
                }
                innerCtx.restoreGState()
            }
        }

        // 1B. Flip to top-left logical coordinates for Spotlight, Shapes, Text, Counter & Watermark
        innerCtx.saveGState()
        innerCtx.translateBy(x: 0, y: imgH)
        innerCtx.scaleBy(x: scale, y: -scale)

        // Spotlight dimming regions
        let spotlightStrokes = strokes.filter { $0.tool == .spotlight && $0.points.count >= 2 }
        if !spotlightStrokes.isEmpty {
            innerCtx.saveGState()
            let path = CGMutablePath()
            path.addRect(CGRect(origin: .zero, size: logicalSize))
            for sp in spotlightStrokes {
                let p1 = sp.points[0]
                let p2 = sp.points[sp.points.count - 1]
                let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                path.addRoundedRect(in: r, cornerWidth: 8, cornerHeight: 8)
            }
            innerCtx.addPath(path)
            innerCtx.setFillColor(NSColor.black.withAlphaComponent(spotlightOpacity).cgColor)
            innerCtx.fillPath(using: .evenOdd)
            innerCtx.restoreGState()
        }

        // Vector & Text Strokes
        for stroke in strokes where stroke.tool != .blur && stroke.tool != .spotlight {
            drawStroke(stroke, in: innerCtx)
        }

        // Watermark
        let cleanWM = watermarkText.trimmingCharacters(in: .whitespacesAndNewlines)
        if watermarkMode != .none && !cleanWM.isEmpty {
            drawWatermark(text: cleanWM, mode: watermarkMode, opacity: watermarkOpacity, logicalSize: logicalSize, in: innerCtx)
        }

        innerCtx.restoreGState()

        guard let annotatedInnerCG = innerCtx.makeImage() else { return nil }

        // Step 2: If no background/padding/cornerRadius is active, return the annotated image directly
        let effectivePad = backgroundPreset == .none ? 0 : padding
        if backgroundPreset == .none && effectivePad == 0 && cornerRadius <= 0 {
            return annotatedInnerCG
        }

        // Step 3: Compose onto Studio Canvas (Background + Aspect Ratio + Padding + Shadow + Rounded Corners)
        var canvasLogicalW = logicalSize.width + effectivePad * 2
        var canvasLogicalH = logicalSize.height + effectivePad * 2
        if let targetRatio = aspectRatio.numericRatio, targetRatio > 0 {
            let currentRatio = canvasLogicalW / max(1, canvasLogicalH)
            if currentRatio < targetRatio {
                canvasLogicalW = round(canvasLogicalH * targetRatio)
            } else if currentRatio > targetRatio {
                canvasLogicalH = round(canvasLogicalW / targetRatio)
            }
        }

        let outW = Int(round(canvasLogicalW * scale))
        let outH = Int(round(canvasLogicalH * scale))
        guard outW > 0 && outH > 0,
              let outCtx = CGContext(
                  data: nil,
                  width: outW,
                  height: outH,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return annotatedInnerCG }

        let outRect = CGRect(x: 0, y: 0, width: CGFloat(outW), height: CGFloat(outH))

        // 3A. Draw Studio Background
        if backgroundPreset == .frosted,
           let frostedCG = generateFilteredCGImage(from: baseCG, style: .gaussian, scale: scale * 2.2) {
            outCtx.draw(frostedCG, in: outRect)
            outCtx.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
            outCtx.fill(outRect)
        } else if !backgroundPreset.gradientHexes.isEmpty {
            let cgColors = backgroundPreset.gradientHexes.compactMap { NSColor(hex: $0)?.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) {
                outCtx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: CGFloat(outH)),
                    end: CGPoint(x: CGFloat(outW), y: 0),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }

        // 3B. Position of inner screenshot inside canvas
        let cardW = imgW
        let cardH = imgH
        let cardX = round((CGFloat(outW) - cardW) / 2)
        let cardY = round((CGFloat(outH) - cardH) / 2)
        let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)
        let radPx = min(cornerRadius * scale, min(cardW, cardH) / 2)
        let roundedPath = CGPath(roundedRect: cardRect, cornerWidth: radPx, cornerHeight: radPx, transform: nil)

        // 3C. Draw Drop Shadow behind rounded screenshot
        if shadowIntensity > 0 && backgroundPreset != .none {
            outCtx.saveGState()
            let alpha = min(0.75, (shadowIntensity / 100.0) * 0.65)
            let blurRad = max(6, (shadowIntensity / 100.0) * 42.0 * scale)
            let offsetY = -max(3, (shadowIntensity / 100.0) * 14.0 * scale)
            outCtx.setShadow(
                offset: CGSize(width: 0, height: offsetY),
                blur: blurRad,
                color: NSColor.black.withAlphaComponent(alpha).cgColor
            )
            outCtx.addPath(roundedPath)
            outCtx.setFillColor(NSColor.black.cgColor)
            outCtx.fillPath()
            outCtx.restoreGState()
        }

        // 3D. Draw Clipped Screenshot + Subtle Border
        outCtx.saveGState()
        outCtx.addPath(roundedPath)
        outCtx.clip()
        outCtx.draw(annotatedInnerCG, in: cardRect)
        outCtx.restoreGState()

        if radPx > 0 {
            outCtx.saveGState()
            outCtx.addPath(roundedPath)
            outCtx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
            outCtx.setLineWidth(max(1, scale * 0.75))
            outCtx.strokePath()
            outCtx.restoreGState()
        }

        return outCtx.makeImage() ?? annotatedInnerCG
    }

    public func generateFilteredCGImage(from source: CGImage, style: BlurStyle, scale: CGFloat) -> CGImage? {
        let ciInput = CIImage(cgImage: source)
        let extent = ciInput.extent
        switch style {
        case .pixelated:
            let filter = CIFilter.pixellate()
            filter.inputImage = ciInput.clampedToExtent()
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            filter.scale = Float(max(10, 12 * scale))
            guard let out = filter.outputImage?.cropped(to: extent) else { return nil }
            return ciContext.createCGImage(out, from: extent)
        case .gaussian:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciInput.clampedToExtent()
            filter.radius = Float(max(8, 10 * scale))
            guard let out = filter.outputImage?.cropped(to: extent) else { return nil }
            return ciContext.createCGImage(out, from: extent)
        case .solidTape:
            return nil
        }
    }

    // MARK: - CoreGraphics Vector & Text Stroke Renderer

    private func drawStroke(_ stroke: DrawnStroke, in ctx: CGContext) {
        guard !stroke.points.isEmpty else { return }

        ctx.saveGState()
        ctx.setStrokeColor(stroke.nsColor.cgColor)
        ctx.setFillColor(stroke.nsColor.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(stroke.lineWidth)

        switch stroke.lineDashStyle {
        case .solid:
            ctx.setLineDash(phase: 0, lengths: [])
        case .dashed:
            ctx.setLineDash(phase: 0, lengths: [stroke.lineWidth * 3.0, stroke.lineWidth * 2.0])
        case .dotted:
            ctx.setLineDash(phase: 0, lengths: [stroke.lineWidth * 0.8, stroke.lineWidth * 2.2])
        }

        if stroke.tool == .marker {
            ctx.setAlpha(0.38)
        } else {
            ctx.setAlpha(1.0)
        }

        switch stroke.tool {
        case .pen, .marker:
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.beginPath()
            ctx.move(to: stroke.points[0])
            for pt in stroke.points.dropFirst() {
                ctx.addLine(to: pt)
            }
            ctx.strokePath()

        case .line:
            guard stroke.points.count >= 2 else { break }
            ctx.beginPath()
            ctx.move(to: stroke.points[0])
            ctx.addLine(to: stroke.points[stroke.points.count - 1])
            ctx.strokePath()

        case .arrow:
            guard stroke.points.count >= 2 else { break }
            ctx.setLineDash(phase: 0, lengths: [])
            let start = stroke.points[0]
            let end = stroke.points[stroke.points.count - 1]
            drawArrowInContext(ctx: ctx, start: start, end: end, lineWidth: stroke.lineWidth, style: stroke.arrowStyle, color: stroke.nsColor)

        case .rect:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(path)
            if stroke.isFilled {
                ctx.fillPath()
            } else {
                ctx.strokePath()
            }

        case .filledRect:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()

        case .oval:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            if stroke.isFilled {
                ctx.fillEllipse(in: rect)
            } else {
                ctx.strokeEllipse(in: rect)
            }

        case .counter:
            let center = stroke.points[0]
            let radius = max(13, stroke.lineWidth * 3.4)
            if stroke.points.count >= 2 {
                let end = stroke.points[stroke.points.count - 1]
                if hypot(end.x - center.x, end.y - center.y) > radius + 6 {
                    drawArrowInContext(ctx: ctx, start: center, end: end, lineWidth: max(2.5, stroke.lineWidth), style: .straight, color: stroke.nsColor)
                }
            }
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            ctx.setFillColor(stroke.nsColor.cgColor)
            ctx.fillEllipse(in: circleRect)
            ctx.restoreGState()

            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: circleRect)

            let numStr = "\(stroke.counterNumber)" as NSString
            let font = NSFont.systemFont(ofSize: radius * 1.05, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: stroke.colorHex.uppercased() == "#FFFFFF" ? NSColor.black : NSColor.white
            ]
            let sz = numStr.size(withAttributes: attrs)
            drawTopLeftString(numStr, at: CGPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2), attributes: attrs, in: ctx)

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
                if stroke.textBoxStyle == .solidPill {
                    ctx.setFillColor(stroke.nsColor.cgColor)
                } else {
                    ctx.setFillColor(NSColor.black.withAlphaComponent(0.78).cgColor)
                }
                ctx.fillPath()
                ctx.restoreGState()
            }
            drawTopLeftString(nsStr, at: CGPoint(x: origin.x + padX, y: origin.y + padY), attributes: attrs, in: ctx)

        case .select, .blur, .spotlight, .crop, .move:
            break
        }

        ctx.restoreGState()
    }

    private func drawArrowInContext(ctx: CGContext, start: CGPoint, end: CGPoint, lineWidth: CGFloat, style: ArrowStyle, color: NSColor) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = hypot(dx, dy)
        guard dist >= 4 else { return }

        let tangentAngle: CGFloat
        ctx.beginPath()
        ctx.move(to: start)

        if style == .straight {
            ctx.addLine(to: end)
            tangentAngle = atan2(dy, dx)
        } else {
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let perpX = -dy / dist
            let perpY = dx / dist
            let sign: CGFloat = (style == .curvedLeft) ? -1.0 : 1.0
            let bend = min(80, dist * 0.26) * sign
            let ctrl = CGPoint(x: mid.x + perpX * bend, y: mid.y + perpY * bend)
            ctx.addQuadCurve(to: end, control: ctrl)
            tangentAngle = atan2(end.y - ctrl.y, end.x - ctrl.x)
        }
        ctx.strokePath()

        let arrowLength: CGFloat = max(13, lineWidth * 3.6)
        let arrowAngle: CGFloat = .pi / 6
        let p1 = CGPoint(
            x: end.x - arrowLength * cos(tangentAngle - arrowAngle),
            y: end.y - arrowLength * sin(tangentAngle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(tangentAngle + arrowAngle),
            y: end.y - arrowLength * sin(tangentAngle + arrowAngle)
        )
        ctx.beginPath()
        ctx.move(to: p1)
        ctx.addLine(to: end)
        ctx.addLine(to: p2)
        ctx.strokePath()
    }

    private func drawWatermark(text: String, mode: WatermarkMode, opacity: CGFloat, logicalSize: CGSize, in ctx: CGContext) {
        let nsStr = text as NSString
        let font = NSFont.systemFont(ofSize: max(13, min(22, logicalSize.width * 0.024)), weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(opacity),
            .strokeColor: NSColor.black.withAlphaComponent(opacity * 0.5),
            .strokeWidth: -1.5
        ]
        let sz = nsStr.size(withAttributes: attrs)

        switch mode {
        case .none:
            break
        case .corner:
            let pt = CGPoint(x: max(12, logicalSize.width - sz.width - 16), y: max(12, logicalSize.height - sz.height - 14))
            drawTopLeftString(nsStr, at: pt, attributes: attrs, in: ctx)
        case .diagonal:
            ctx.saveGState()
            ctx.translateBy(x: logicalSize.width / 2, y: logicalSize.height / 2)
            ctx.rotate(by: -.pi / 6)
            drawTopLeftString(nsStr, at: CGPoint(x: -sz.width / 2, y: -sz.height / 2), attributes: attrs, in: ctx)
            ctx.restoreGState()
        case .tiled:
            let stepX = max(140, sz.width + 80)
            let stepY = max(90, sz.height + 64)
            var y: CGFloat = 24
            while y < logicalSize.height {
                var x: CGFloat = 24
                while x < logicalSize.width {
                    ctx.saveGState()
                    ctx.translateBy(x: x + sz.width / 2, y: y + sz.height / 2)
                    ctx.rotate(by: -.pi / 8)
                    drawTopLeftString(nsStr, at: CGPoint(x: -sz.width / 2, y: -sz.height / 2), attributes: attrs, in: ctx)
                    ctx.restoreGState()
                    x += stepX
                }
                y += stepY
            }
        }
    }

    private func drawTopLeftString(_ string: NSString, at point: CGPoint, attributes: [NSAttributedString.Key: Any], in ctx: CGContext) {
        ctx.saveGState()
        let prev = NSGraphicsContext.current
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.current = nsCtx
        string.draw(at: point, withAttributes: attributes)
        NSGraphicsContext.current = prev
        ctx.restoreGState()
    }

    // MARK: - Pin Screenshot to Screen (Snapzy Floating Reference Window)

    public func pinToScreen() {
        guard let finalCG = renderCompositeImage() else { return }
        let outLogicalSize = CGSize(
            width: round(CGFloat(finalCG.width) / max(1, scaleFactor)),
            height: round(CGFloat(finalCG.height) / max(1, scaleFactor))
        )
        let nsImage = NSImage(cgImage: finalCG, size: outLogicalSize)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let maxW = min(560, screen.visibleFrame.width * 0.45)
        let maxH = min(440, screen.visibleFrame.height * 0.45)
        let ratio = min(1.0, min(maxW / max(1, outLogicalSize.width), maxH / max(1, outLogicalSize.height)))
        let winSize = NSSize(width: max(160, round(outLogicalSize.width * ratio)), height: max(100, round(outLogicalSize.height * ratio)))
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - winSize.width - 28,
            y: screen.visibleFrame.maxY - winSize.height - 28
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: winSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.aspectRatio = winSize

        let view = PinnedScreenshotView(image: nsImage) { [weak self, weak panel] in
            if let panel {
                panel.orderOut(nil)
                self?.pinnedWindows.removeAll { $0 === panel }
            }
        }
        let hosting = NSHostingView(rootView: view)
        if #available(macOS 13.0, *) {
            hosting.safeAreaRegions = []
        }
        panel.contentView = hosting
        panel.makeKeyAndOrderFront(nil)
        pinnedWindows.append(panel)

        NSSound(named: "Tink")?.play()
        if isStudioOpen {
            closeStudioEditor()
        } else {
            cancelCapture()
        }
    }

    // MARK: - Copy Action (⌘C)

    public func copyToClipboard() {
        guard let finalCG = renderCompositeImage() else {
            if isStudioOpen { closeStudioEditor() } else { cancelCapture() }
            return
        }

        let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
        let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
        let rep = NSBitmapImageRep(cgImage: finalCG)
        rep.size = NSSize(width: logicalW, height: logicalH)

        let pngData = rep.representation(using: .png, properties: [:])
        let tiffData = rep.representation(using: .tiff, properties: [:])

        let pb = NSPasteboard.general
        pb.clearContents()
        if let pngData = pngData {
            pb.setData(pngData, forType: .png)
        }
        if let tiffData = tiffData {
            pb.setData(tiffData, forType: .tiff)
        }

        NSSound(named: "Glass")?.play()

        if isStudioOpen {
            closeStudioEditor()
        } else {
            cancelCapture()
        }
    }

    // MARK: - Save Action (⌘S -> Downloads/Screenshots, ⌘⇧S -> Save Panel)

    public func saveToDownloads() {
        guard let finalCG = renderCompositeImage() else {
            if isStudioOpen { closeStudioEditor() } else { cancelCapture() }
            return
        }

        let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
        let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
        let rep = NSBitmapImageRep(cgImage: finalCG)
        rep.size = NSSize(width: logicalW, height: logicalH)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            if isStudioOpen { closeStudioEditor() } else { cancelCapture() }
            return
        }

        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let screenshotsDir = downloadsDir.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot_\(timestamp).png"
        let fileURL = screenshotsDir.appendingPathComponent(filename)

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

        if isStudioOpen {
            closeStudioEditor()
        } else {
            cancelCapture()
        }
    }

    public func saveAsWithPanel() {
        guard let finalCG = renderCompositeImage() else { return }
        let logicalW = round(CGFloat(finalCG.width) / max(1, scaleFactor))
        let logicalH = round(CGFloat(finalCG.height) / max(1, scaleFactor))
        let rep = NSBitmapImageRep(cgImage: finalCG)
        rep.size = NSSize(width: logicalW, height: logicalH)

        let savePanel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        savePanel.nameFieldStringValue = "HyperMac_\(formatter.string(from: Date())).png"
        savePanel.canCreateDirectories = true
        savePanel.level = .modalPanel

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else { return }

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

// MARK: - Key-Capable Panel, Hosting View & Studio Window Subclasses

private final class ScreenshotHostingView: NSHostingView<ScreenshotOverlayView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

private final class ScreenshotKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

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
            if !manager.hasSelection {
                // Cho phép bấm 2 nút trên thanh gợi ý đầu màn hình (Chụp toàn màn hình / Mở Studio ngay)
                let hintBarRect = CGRect(x: w / 2 - 280, y: 24, width: 560, height: 52)
                if hintBarRect.contains(pt) {
                    isTrackingRegionDrag = false
                    super.sendEvent(event)
                    return
                }

                // Bắt đầu kéo chọn vùng chụp trực tiếp ở tầng AppKit (hoạt động ngay cả khi phím ⌘/⇧ chưa nhả hết)
                isTrackingRegionDrag = true
                regionDragOrigin = pt
                spaceMoveStartMouse = .zero
                manager.isDraggingSelection = false
                manager.selectionRect = .zero
                return
            }

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
                    manager.hasSelection = true
                    if manager.isQuickCopyMode {
                        manager.copyToClipboard()
                    } else if manager.autoOpenEditorAfterCapture {
                        manager.openStudioEditor()
                    }
                } else {
                    manager.selectionRect = .zero
                    manager.hasSelection = false
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

// MARK: - Hex Color Helper for AppKit & SwiftUI

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
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: clean).scanHexInt64(&int) else { return nil }
        if clean.count == 6 {
            let r = CGFloat((int >> 16) & 0xFF) / 255.0
            let g = CGFloat((int >> 8) & 0xFF) / 255.0
            let b = CGFloat(int & 0xFF) / 255.0
            self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
        } else {
            self.init(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        }
    }
}
