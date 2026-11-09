import SwiftUI
import AppKit

// MARK: - Snapzy-Inspired Post-Capture Studio Editor Window View

public struct ScreenshotStudioEditorView: View {
    @ObservedObject var manager: ScreenshotManager

    public init(manager: ScreenshotManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Primary Tool Bar (13 Tools + Rotate + Smart Vision Actions + Undo/Redo)
            topPrimaryToolbar

            Divider().opacity(0.25)

            // 2. Context Sub-Toolbar (Colors, Stroke Width, Arrow/Line/Blur/Text Styles)
            contextStyleToolbar

            Divider().opacity(0.25)

            // 3. Main Workspace: Interactive Studio Canvas + Right Beautifier Sidebar
            HStack(spacing: 0) {
                studioCanvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if manager.isSidebarVisible {
                    Divider().opacity(0.25)
                    studioBeautifierSidebar
                        .frame(width: 265)
                        .transition(.move(edge: .trailing))
                }
            }

            Divider().opacity(0.25)

            // 4. Bottom Action & Export Footer
            bottomExportFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            if let msg = manager.statusBannerMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: FS.body))
                        .foregroundStyle(Tone.good)
                    Text(msg)
                        .font(.system(size: FS.label, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                .padding(.top, 92)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .popover(isPresented: $manager.isOCRPopoverPresented) {
            ocrResultPopover
        }
    }

    // MARK: - 1. Top Primary Toolbar

    private var topPrimaryToolbar: some View {
        HStack(spacing: 4) {
            // Reserve left space for macOS window traffic lights
            Spacer().frame(width: 66)

            // All 13 Studio Tools
            HStack(spacing: 3) {
                ForEach(ScreenshotTool.studioTools, id: \.self) { tool in
                    studioToolButton(tool)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Divider().frame(height: 22).padding(.horizontal, 4)

            // Rotate Left / Right 90°
            HStack(spacing: 2) {
                Button {
                    manager.rotateStudioImage(clockwise: false)
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.system(size: FS.body, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(tr("Xoay trái 90°", "Rotate Left 90°"))

                Button {
                    manager.rotateStudioImage(clockwise: true)
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: FS.body, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(tr("Xoay phải 90°", "Rotate Right 90°"))
            }

            Divider().frame(height: 22).padding(.horizontal, 4)

            // Smart Vision Tools: Auto-Redact Sensitive Data + OCR Text Extract
            HStack(spacing: 4) {
                Button {
                    manager.autoRedactSensitiveData()
                } label: {
                    HStack(spacing: 4) {
                        if manager.isScanningSensitiveData {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: FS.caption))
                        }
                        Text(tr("Tự che nhạy cảm", "Auto-Redact"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                    )
                    .foregroundStyle(Color.orange)
                }
                .buttonStyle(.plain)
                .help(tr("Tự động quét và làm mờ Email, SĐT, API Key, Mật khẩu trên ảnh", "Automatically detect and redact emails, phone numbers, API keys"))

                Button {
                    manager.extractTextViaVision()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: FS.caption))
                        Text(tr("Trích xuất chữ", "Extract Text"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(tr("Nhận diện và sao chép văn bản trong ảnh (OCR)", "Extract and copy text from screenshot (OCR)"))
            }

            Spacer(minLength: 4)

            // Undo / Redo / Delete / Clear
            HStack(spacing: 3) {
                Button {
                    manager.undoLastStroke()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: FS.body, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(manager.strokes.isEmpty ? Color.secondary.opacity(0.35) : Color.primary)
                }
                .buttonStyle(.plain)
                .disabled(manager.strokes.isEmpty)
                .help(tr("Hoàn tác (⌘Z)", "Undo (⌘Z)"))

                Button {
                    manager.redoLastStroke()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: FS.body, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(manager.redoStack.isEmpty ? Color.secondary.opacity(0.35) : Color.primary)
                }
                .buttonStyle(.plain)
                .disabled(manager.redoStack.isEmpty)
                .help(tr("Làm lại (⌘⇧Z)", "Redo (⌘⇧Z)"))

                if manager.selectedStrokeID != nil {
                    Button {
                        manager.deleteSelectedStroke()
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.system(size: FS.body))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Tone.bad)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Xóa mục đang chọn (⌫)", "Delete selected item (⌫)"))
                }

                if !manager.strokes.isEmpty {
                    Button {
                        manager.clearAllStrokes()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: FS.caption))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Tone.bad)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Xóa toàn bộ chú thích", "Clear all annotations"))
                }

                Divider().frame(height: 18).padding(.horizontal, 2)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        manager.isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: FS.body, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(manager.isSidebarVisible ? Color.accentColor : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                .fill(manager.isSidebarVisible ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(tr("Hiện/ẩn thanh khung nền Studio", "Toggle Studio Canvas Sidebar"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func studioToolButton(_ tool: ScreenshotTool) -> some View {
        let isSelected = manager.currentTool == tool
        return Button {
            manager.commitActiveTextEditing()
            manager.currentTool = tool
            if tool == .crop {
                manager.isCroppingInStudio = true
                manager.studioCropRect = CGRect(origin: .zero, size: manager.studioLogicalSize)
            } else {
                manager.isCroppingInStudio = false
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: FS.body, weight: isSelected ? .semibold : .regular))
                Text(tool.title)
                    .font(.system(size: FS.caption, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    // MARK: - 2. Context Style Sub-Toolbar

    private var contextStyleToolbar: some View {
        HStack(spacing: 12) {
            // Color Palette Swatches
            HStack(spacing: 5) {
                ForEach(manager.availableColors, id: \.self) { hex in
                    Button {
                        manager.selectedColorHex = hex
                        updateSelectedStrokeColor(hex)
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(manager.selectedColorHex == hex ? Color.accentColor : Color.primary.opacity(0.25),
                                            lineWidth: manager.selectedColorHex == hex ? 2.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 18)

            // Stroke Width Slider
            if [.pen, .marker, .arrow, .line, .rect, .oval, .counter].contains(manager.currentTool) {
                HStack(spacing: 6) {
                    Text(tr("Độ dày:", "Size:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $manager.strokeWidth, in: 1.5...16.0)
                        .frame(width: 90)
                        .controlSize(.small)
                    Text("\(Int(round(manager.strokeWidth)))pt")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                }
            }

            // Arrow Bend Style (Straight / Curved Left / Curved Right)
            if manager.currentTool == .arrow {
                Divider().frame(height: 18)
                HStack(spacing: 4) {
                    Text(tr("Kiểu mũi tên:", "Curve:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach(ArrowStyle.allCases, id: \.self) { style in
                        chipButton(
                            title: style.title,
                            icon: style.icon,
                            isSelected: manager.arrowStyle == style
                        ) {
                            manager.arrowStyle = style
                        }
                    }
                }
            }

            // Line Dash Style (Solid / Dashed / Dotted)
            if [.line, .rect, .oval].contains(manager.currentTool) {
                Divider().frame(height: 18)
                HStack(spacing: 4) {
                    ForEach(LineDashStyle.allCases, id: \.self) { dash in
                        chipButton(title: dash.title, isSelected: manager.lineDashStyle == dash) {
                            manager.lineDashStyle = dash
                        }
                    }
                }
            }

            // Shape Fill Toggle
            if [.rect, .oval].contains(manager.currentTool) {
                Toggle(tr("Tô đặc", "Fill"), isOn: $manager.isShapeFilled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: FS.caption, weight: .medium))
            }

            // Text Controls (Font Size + Box Style)
            if manager.currentTool == .text {
                HStack(spacing: 8) {
                    Text(tr("Cỡ chữ:", "Font:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $manager.fontSize, in: 12...54)
                        .frame(width: 85)
                        .controlSize(.small)
                    Text("\(Int(manager.fontSize))pt")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Divider().frame(height: 16)

                    ForEach(TextBoxStyle.allCases, id: \.self) { style in
                        chipButton(title: style.title, isSelected: manager.textBoxStyle == style) {
                            manager.textBoxStyle = style
                        }
                    }
                }
            }

            // Counter Controls
            if manager.currentTool == .counter {
                HStack(spacing: 8) {
                    Text(tr("Số tiếp theo: #\(manager.nextCounterValue)", "Next: #\(manager.nextCounterValue)"))
                        .font(.system(size: FS.caption, weight: .semibold))
                    Button(tr("Đặt lại về 1", "Reset to 1")) {
                        manager.nextCounterValue = 1
                    }
                    .font(.system(size: FS.caption, weight: .medium))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))

                    Text(tr("• Bấm để đặt số, kéo chuột để thêm mũi tên chỉ hướng", "• Click to place badge, drag to attach pointer arrow"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
            }

            // Blur Controls (Pixelated / Gaussian / Solid Tape)
            if manager.currentTool == .blur {
                HStack(spacing: 6) {
                    Text(tr("Kiểu làm mờ:", "Blur Type:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach(BlurStyle.allCases, id: \.self) { bStyle in
                        chipButton(title: bStyle.title, isSelected: manager.blurStyle == bStyle) {
                            manager.blurStyle = bStyle
                        }
                    }
                }
            }

            // Crop Action Buttons
            if manager.currentTool == .crop {
                HStack(spacing: 8) {
                    Text(tr("Kéo các cạnh trên ảnh để chọn vùng cắt", "Drag handles on the image to adjust crop box"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)

                    Button {
                        manager.applyStudioCrop()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text(tr("Áp dụng cắt", "Apply Crop"))
                        }
                        .font(.system(size: FS.caption, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        manager.isCroppingInStudio = false
                        manager.currentTool = .select
                    } label: {
                        Text(tr("Huỷ", "Cancel"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    private func updateSelectedStrokeColor(_ hex: String) {
        guard let id = manager.selectedStrokeID,
              let idx = manager.strokes.firstIndex(where: { $0.id == id }) else { return }
        manager.strokes[idx].colorHex = hex
    }

    // MARK: - 3. Interactive Studio Canvas Area

    private var studioCanvasArea: some View {
        GeometryReader { geo in
            let imgSize = manager.studioLogicalSize
            let effectivePad = manager.backgroundPreset == .none ? 0 : manager.canvasPadding
            let rawCanvasW = max(100, imgSize.width + effectivePad * 2)
            let rawCanvasH = max(100, imgSize.height + effectivePad * 2)

            let finalCanvasSize: CGSize = {
                if let ratio = manager.aspectRatio.numericRatio, ratio > 0 {
                    let cur = rawCanvasW / max(1, rawCanvasH)
                    if cur < ratio {
                        return CGSize(width: round(rawCanvasH * ratio), height: rawCanvasH)
                    } else if cur > ratio {
                        return CGSize(width: rawCanvasW, height: round(rawCanvasW / ratio))
                    }
                }
                return CGSize(width: rawCanvasW, height: rawCanvasH)
            }()

            let availW = max(200, geo.size.width - 40)
            let availH = max(200, geo.size.height - 40)
            let fitScale = min(1.0, min(availW / max(1, finalCanvasSize.width), availH / max(1, finalCanvasSize.height)))
            let displayScale = fitScale * manager.studioZoom

            ZStack {
                // Checkerboard / neutral workspace backdrop
                Color(nsColor: .underPageBackgroundColor)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Outer Studio Canvas (Gradient / Wallpaper / Frosted)
                        studioCanvasBackgroundView(size: finalCanvasSize)
                            .frame(width: finalCanvasSize.width, height: finalCanvasSize.height)
                            .shadow(color: .black.opacity(0.22), radius: 14, y: 4)

                        // Inner Screenshot + Annotations Card
                        ZStack(alignment: .topLeading) {
                            if let nsImg = manager.studioBaseNSImage {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: imgSize.width, height: imgSize.height)
                            }

                            // Drawn Annotations + Blur + Spotlight + Watermark
                            StudioAnnotationsCanvasView(
                                baseCGImage: manager.studioBaseCGImage,
                                logicalSize: imgSize,
                                strokes: manager.strokes,
                                activeStroke: manager.activeStroke,
                                selectedStrokeID: manager.selectedStrokeID,
                                spotlightOpacity: manager.spotlightOpacity,
                                watermarkMode: manager.watermarkMode,
                                watermarkText: manager.watermarkText,
                                watermarkOpacity: manager.watermarkOpacity
                            )
                            .frame(width: imgSize.width, height: imgSize.height)

                            // Interactive Gesture Surface in Image Coordinates
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(width: imgSize.width, height: imgSize.height)
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                        .onChanged { val in
                                            handleStudioCanvasDragChanged(val)
                                        }
                                        .onEnded { val in
                                            handleStudioCanvasDragEnded(val)
                                        }
                                )

                            // Inline Text Field when adding/editing a Text annotation
                            if manager.editingTextStrokeID != nil {
                                inlineTextEditorOverlay(imgSize: imgSize)
                            }

                            // Interactive Crop Overlay when Crop tool is active
                            if manager.currentTool == .crop && manager.isCroppingInStudio {
                                studioCropOverlay(imgSize: imgSize)
                            }
                        }
                        .frame(width: imgSize.width, height: imgSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: manager.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: manager.cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(manager.cornerRadius > 0 ? 0.22 : 0), lineWidth: 1)
                        )
                        .shadow(
                            color: .black.opacity(manager.backgroundPreset != .none ? (manager.shadowIntensity / 100.0) * 0.60 : 0),
                            radius: (manager.shadowIntensity / 100.0) * 26.0,
                            y: (manager.shadowIntensity / 100.0) * 10.0
                        )
                    }
                    .scaleEffect(displayScale)
                    .frame(
                        width: max(geo.size.width, finalCanvasSize.width * displayScale + 40),
                        height: max(geo.size.height, finalCanvasSize.height * displayScale + 40)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func studioCanvasBackgroundView(size: CGSize) -> some View {
        switch manager.backgroundPreset {
        case .none:
            Color.clear
        case .frosted:
            ZStack {
                if let nsImg = manager.studioBaseNSImage {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .blur(radius: 36)
                        .clipped()
                }
                Color.black.opacity(0.22)
            }
        default:
            let colors = manager.backgroundPreset.gradientHexes.map { Color(hex: $0) }
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func inlineTextEditorOverlay(imgSize: CGSize) -> some View {
        let pt = manager.editingTextPoint
        let clampedX = min(max(8, pt.x), max(8, imgSize.width - 220))
        let clampedY = min(max(8, pt.y), max(8, imgSize.height - 48))

        return HStack(spacing: 4) {
            TextField(tr("Nhập chú thích văn bản...", "Type text annotation..."), text: $manager.editingTextValue)
                .textFieldStyle(.plain)
                .font(.system(size: max(14, min(28, manager.fontSize)), weight: .semibold))
                .foregroundStyle(manager.textBoxStyle == .plain ? Color(hex: manager.selectedColorHex) : .white)
                .frame(minWidth: 160, maxWidth: 320)
                .onSubmit {
                    manager.commitActiveTextEditing()
                }

            Button {
                manager.commitActiveTextEditing()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: FS.subhead))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                .fill(manager.textBoxStyle == .solidPill ? Color(hex: manager.selectedColorHex) : Color.black.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: Rad.sm).stroke(Color.white.opacity(0.45), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .position(x: clampedX + 100, y: clampedY + 20)
    }

    // MARK: - Studio Canvas Drag & Click Handling

    private func handleStudioCanvasDragChanged(_ val: DragGesture.Value) {
        let start = val.startLocation
        let cur = val.location
        let dist = hypot(cur.x - start.x, cur.y - start.y)

        switch manager.currentTool {
        case .select:
            if manager.movingStrokeStartPoints == nil {
                if let hit = manager.hitTestStroke(at: start) {
                    manager.selectedStrokeID = hit.id
                    manager.movingStrokeStartPoints = hit.points
                } else {
                    manager.selectedStrokeID = nil
                }
            }
            if let id = manager.selectedStrokeID,
               let origPts = manager.movingStrokeStartPoints,
               let idx = manager.strokes.firstIndex(where: { $0.id == id }) {
                let dx = cur.x - start.x
                let dy = cur.y - start.y
                manager.strokes[idx].points = origPts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            }

        case .pen:
            if manager.activeStroke == nil {
                manager.activeStroke = DrawnStroke(
                    tool: .pen,
                    points: [start, cur],
                    colorHex: manager.selectedColorHex,
                    lineWidth: manager.strokeWidth
                )
            } else {
                manager.activeStroke?.points.append(cur)
            }

        case .marker:
            if manager.activeStroke == nil {
                manager.activeStroke = DrawnStroke(
                    tool: .marker,
                    points: [start, cur],
                    colorHex: manager.selectedColorHex,
                    lineWidth: max(12, manager.strokeWidth * 3.5)
                )
            } else {
                manager.activeStroke?.points.append(cur)
            }

        case .arrow:
            guard dist >= 3 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .arrow,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                arrowStyle: manager.arrowStyle
            )

        case .line:
            guard dist >= 3 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .line,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                lineDashStyle: manager.lineDashStyle
            )

        case .rect:
            guard dist >= 3 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .rect,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                lineDashStyle: manager.lineDashStyle,
                isFilled: manager.isShapeFilled
            )

        case .filledRect:
            guard dist >= 3 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .filledRect,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                isFilled: true
            )

        case .oval:
            guard dist >= 3 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .oval,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                lineDashStyle: manager.lineDashStyle,
                isFilled: manager.isShapeFilled
            )

        case .counter:
            let pts = dist > 12 ? [start, cur] : [start]
            manager.activeStroke = DrawnStroke(
                tool: .counter,
                points: pts,
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                counterNumber: manager.nextCounterValue
            )

        case .blur:
            guard dist >= 4 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .blur,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                blurStyle: manager.blurStyle,
                blurIntensity: manager.blurIntensity
            )

        case .spotlight:
            guard dist >= 4 else { return }
            manager.activeStroke = DrawnStroke(
                tool: .spotlight,
                points: [start, cur],
                colorHex: manager.selectedColorHex,
                lineWidth: 2
            )

        case .text, .crop, .move:
            break
        }
    }

    private func handleStudioCanvasDragEnded(_ val: DragGesture.Value) {
        manager.movingStrokeStartPoints = nil
        if manager.currentTool == .text {
            manager.beginTextAnnotation(at: val.startLocation)
            return
        }
        if manager.currentTool == .counter {
            let stroke = manager.activeStroke ?? DrawnStroke(
                tool: .counter,
                points: [val.startLocation],
                colorHex: manager.selectedColorHex,
                lineWidth: manager.strokeWidth,
                counterNumber: manager.nextCounterValue
            )
            manager.addStroke(stroke)
            manager.nextCounterValue += 1
            manager.activeStroke = nil
            return
        }
        if let stroke = manager.activeStroke {
            manager.addStroke(stroke)
            manager.activeStroke = nil
        }
    }

    // MARK: - Studio Interactive Crop Overlay

    private func studioCropOverlay(imgSize: CGSize) -> some View {
        let crop = manager.studioCropRect
        return ZStack(alignment: .topLeading) {
            // Dim outside crop area
            Path { p in
                p.addRect(CGRect(origin: .zero, size: imgSize))
                p.addRect(crop)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // Crop Border + Rule of Thirds Grid
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: crop.width, height: crop.height)
                .position(x: crop.midX, y: crop.midY)
                .allowsHitTesting(false)

            // 4 Corner Handles for Cropping
            studioCropHandle(at: CGPoint(x: crop.minX, y: crop.minY), handle: .topLeft, imgSize: imgSize)
            studioCropHandle(at: CGPoint(x: crop.maxX, y: crop.minY), handle: .topRight, imgSize: imgSize)
            studioCropHandle(at: CGPoint(x: crop.minX, y: crop.maxY), handle: .bottomLeft, imgSize: imgSize)
            studioCropHandle(at: CGPoint(x: crop.maxX, y: crop.maxY), handle: .bottomRight, imgSize: imgSize)
        }
    }

    private func studioCropHandle(at point: CGPoint, handle: ResizeHandle, imgSize: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .shadow(radius: 2)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { val in
                        if manager.cropDragHandle == nil {
                            manager.cropDragHandle = handle
                            manager.cropDragStartRect = manager.studioCropRect
                        }
                        let r = manager.cropDragStartRect
                        var nr = r
                        switch handle {
                        case .topLeft:
                            nr.origin.x = max(0, min(r.maxX - 30, r.origin.x + val.translation.width))
                            nr.origin.y = max(0, min(r.maxY - 30, r.origin.y + val.translation.height))
                            nr.size.width = r.maxX - nr.origin.x
                            nr.size.height = r.maxY - nr.origin.y
                        case .topRight:
                            nr.origin.y = max(0, min(r.maxY - 30, r.origin.y + val.translation.height))
                            nr.size.width = max(30, min(imgSize.width - r.minX, r.width + val.translation.width))
                            nr.size.height = r.maxY - nr.origin.y
                        case .bottomLeft:
                            nr.origin.x = max(0, min(r.maxX - 30, r.origin.x + val.translation.width))
                            nr.size.width = r.maxX - nr.origin.x
                            nr.size.height = max(30, min(imgSize.height - r.minY, r.height + val.translation.height))
                        case .bottomRight:
                            nr.size.width = max(30, min(imgSize.width - r.minX, r.width + val.translation.width))
                            nr.size.height = max(30, min(imgSize.height - r.minY, r.height + val.translation.height))
                        default:
                            break
                        }
                        manager.studioCropRect = nr
                    }
                    .onEnded { _ in
                        manager.cropDragHandle = nil
                    }
            )
    }

    // MARK: - 4. Right Sidebar: Studio Beautifier (Background, Padding, Corners, Shadow, Watermark)

    private var studioBeautifierSidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Label(tr("Khung nền Studio", "Studio Canvas"), systemImage: "sparkles.rectangle.stack")
                        .font(.system(size: FS.body, weight: .semibold))
                    Spacer()
                    Button {
                        manager.resetCanvasEffects()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Đặt lại nền, khoảng đệm, bóng đổ và bo góc", "Reset background, padding, shadow & corners"))
                }

                // Background Presets Grid
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Hình nền (Background)", "Background"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(StudioBackgroundPreset.allCases, id: \.self) { preset in
                            backgroundPresetTile(preset)
                        }
                    }
                }

                Divider().opacity(0.3)

                // Sliders: Padding, Corner Radius, Shadow
                VStack(alignment: .leading, spacing: 10) {
                    sliderControlRow(
                        title: tr("Khoảng đệm (Padding)", "Padding"),
                        value: $manager.canvasPadding,
                        range: 0...120,
                        unit: "px"
                    )

                    sliderControlRow(
                        title: tr("Bo góc ảnh", "Corner Radius"),
                        value: $manager.cornerRadius,
                        range: 0...32,
                        unit: "px"
                    )

                    sliderControlRow(
                        title: tr("Đổ bóng (Shadow)", "Drop Shadow"),
                        value: $manager.shadowIntensity,
                        range: 0...100,
                        unit: "%"
                    )

                    if manager.strokes.contains(where: { $0.tool == .spotlight }) || manager.currentTool == .spotlight {
                        sliderControlRow(
                            title: tr("Độ tối Đèn rọi", "Spotlight Dim"),
                            value: $manager.spotlightOpacity,
                            range: 0.25...0.85,
                            unit: "",
                            displayMultiplier: 100
                        )
                    }
                }

                Divider().opacity(0.3)

                // Aspect Ratio
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Tỷ lệ khung nền", "Aspect Ratio"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        ForEach(CanvasAspectRatio.allCases, id: \.self) { ratio in
                            chipButton(title: ratio.title, isSelected: manager.aspectRatio == ratio) {
                                manager.aspectRatio = ratio
                            }
                        }
                    }
                }

                Divider().opacity(0.3)

                // Watermark Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Watermark / Chữ ký", "Watermark"))
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField(tr("Nhập chữ ký / thương hiệu...", "Watermark text..."), text: $manager.watermarkText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: FS.label))

                    HStack(spacing: 4) {
                        ForEach(WatermarkMode.allCases, id: \.self) { mode in
                            chipButton(title: mode.title, isSelected: manager.watermarkMode == mode) {
                                manager.watermarkMode = mode
                            }
                        }
                    }

                    if manager.watermarkMode != .none {
                        sliderControlRow(
                            title: tr("Độ mờ Watermark", "Opacity"),
                            value: $manager.watermarkOpacity,
                            range: 0.10...0.90,
                            unit: "%",
                            displayMultiplier: 100
                        )
                    }
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func backgroundPresetTile(_ preset: StudioBackgroundPreset) -> some View {
        let isSelected = manager.backgroundPreset == preset
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                manager.backgroundPreset = preset
            }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    if preset == .none {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .frame(width: 18, height: 18)
                    } else {
                        let cols = preset.gradientHexes.map { Color(hex: $0) }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: cols, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 18, height: 18)
                    }
                }
                Text(preset.title)
                    .font(.system(size: FS.caption, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sliderControlRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        unit: String,
        displayMultiplier: CGFloat = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: FS.caption, weight: .medium))
                Spacer()
                Text("\(Int(round(value.wrappedValue * displayMultiplier)))\(unit)")
                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .controlSize(.small)
        }
    }

    private func chipButton(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: FS.caption))
                }
                Text(title)
                    .font(.system(size: FS.caption, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Bottom Export & Action Footer

    private var bottomExportFooter: some View {
        HStack(spacing: 10) {
            // Image Resolution Info + Zoom Controls
            HStack(spacing: 6) {
                let w = Int(round(manager.studioLogicalSize.width * manager.scaleFactor))
                let h = Int(round(manager.studioLogicalSize.height * manager.scaleFactor))
                Text("\(w) × \(h) px")
                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Divider().frame(height: 14)

                Button {
                    manager.studioZoom = max(0.5, manager.studioZoom - 0.15)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: FS.caption))
                }
                .buttonStyle(.plain)

                Text("\(Int(round(manager.studioZoom * 100)))%")
                    .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                    .frame(width: 38)

                Button {
                    manager.studioZoom = min(2.5, manager.studioZoom + 0.15)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: FS.caption))
                }
                .buttonStyle(.plain)

                Button(tr("Vừa khung", "Fit")) {
                    manager.studioZoom = 1.0
                }
                .font(.system(size: FS.caption, weight: .medium))
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            }

            Spacer()

            // Pin to Screen Button
            Button {
                manager.pinToScreen()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: FS.caption))
                    Text(tr("Ghim nổi", "Pin to Screen"))
                        .font(.system(size: FS.label, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(tr("Ghim ảnh nổi trên màn hình để đối chiếu", "Pin floating screenshot on screen"))

            // Save As... (⌘⇧S)
            Button {
                manager.saveAsWithPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: FS.caption))
                    Text(tr("Lưu thành...", "Save As..."))
                        .font(.system(size: FS.label, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)

            // Quick Save to Downloads/Screenshots (⌘S)
            Button {
                manager.saveToDownloads()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: FS.caption, weight: .semibold))
                    Text(tr("Lưu nhanh (⌘S)", "Quick Save (⌘S)"))
                        .font(.system(size: FS.label, weight: .semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Primary Action: Copy to Clipboard & Close (⌘C / Enter)
            Button {
                manager.copyToClipboard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: FS.caption, weight: .semibold))
                    Text(tr("Sao chép & Đóng (⌘C)", "Copy & Close (⌘C)"))
                        .font(.system(size: FS.label, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - OCR Result Popover

    private var ocrResultPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(tr("Văn bản trích xuất (OCR)", "Extracted Text (OCR)"), systemImage: "text.viewfinder")
                    .font(.system(size: FS.body, weight: .semibold))
                Spacer()
                Button(tr("Sao chép", "Copy")) {
                    if let text = manager.extractedOCRText {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        manager.showStatusBanner(tr("Đã sao chép văn bản OCR", "Copied OCR text"))
                    }
                    manager.isOCRPopoverPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView {
                Text(manager.extractedOCRText?.isEmpty == false ? manager.extractedOCRText! : tr("Không tìm thấy văn bản.", "No text found."))
                    .font(.system(size: FS.label, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(width: 360, height: 200)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
        }
        .padding(12)
    }
}

// MARK: - Shared Annotations Canvas View (Used by Studio & Snipping Overlay)

public struct StudioAnnotationsCanvasView: View {
    public let baseCGImage: CGImage?
    public let logicalSize: CGSize
    public let strokes: [DrawnStroke]
    public let activeStroke: DrawnStroke?
    public let selectedStrokeID: UUID?
    public let spotlightOpacity: CGFloat
    public let watermarkMode: WatermarkMode
    public let watermarkText: String
    public let watermarkOpacity: CGFloat
    public var clipRect: CGRect? = nil

    public var body: some View {
        Canvas { context, size in
            if let clip = clipRect, clip.width > 0 && clip.height > 0 {
                context.clip(to: Path(clip))
            }

            let allStrokes = strokes + (activeStroke.map { [$0] } ?? [])

            // 1. Blur / Pixelate / Redact Regions
            for stroke in allStrokes where stroke.tool == .blur && stroke.points.count >= 2 {
                renderBlurRegion(stroke, into: &context)
            }

            // 2. Spotlight Dimming
            let spotlights = allStrokes.filter { $0.tool == .spotlight && $0.points.count >= 2 }
            if !spotlights.isEmpty {
                var dimPath = Path()
                dimPath.addRect(CGRect(origin: .zero, size: size))
                for sp in spotlights {
                    let p1 = sp.points[0]
                    let p2 = sp.points[sp.points.count - 1]
                    let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                    dimPath.addRoundedRect(in: r, cornerSize: CGSize(width: 8, height: 8))
                }
                context.fill(dimPath, with: .color(.black.opacity(spotlightOpacity)), style: FillStyle(eoFill: true))
                for sp in spotlights {
                    let p1 = sp.points[0]
                    let p2 = sp.points[sp.points.count - 1]
                    let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                    context.stroke(Path(roundedRect: r, cornerRadius: 8), with: .color(.white.opacity(0.45)), lineWidth: 1.5)
                }
            }

            // 3. Vector & Text Annotations
            for stroke in allStrokes where stroke.tool != .blur && stroke.tool != .spotlight {
                renderVectorOrTextStroke(stroke, into: &context)
            }

            // 4. Selection Highlight Box
            if let selID = selectedStrokeID,
               let selected = strokes.first(where: { $0.id == selID }) {
                let box = selected.boundingRect
                context.stroke(
                    Path(roundedRect: box, cornerRadius: 4),
                    with: .color(.accentColor),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
            }

            // 5. Watermark Preview
            let cleanWM = watermarkText.trimmingCharacters(in: .whitespacesAndNewlines)
            if watermarkMode != .none && !cleanWM.isEmpty {
                renderWatermark(text: cleanWM, size: size, into: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func renderBlurRegion(_ stroke: DrawnStroke, into context: inout GraphicsContext) {
        let p1 = stroke.points[0]
        let p2 = stroke.points[stroke.points.count - 1]
        let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
        guard rect.width >= 2 && rect.height >= 2 else { return }

        switch stroke.blurStyle {
        case .solidTape:
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(hex: stroke.colorHex)))
        case .pixelated, .gaussian:
            // Draw mosaic blocks / frosted veil preview in live canvas (exact CoreImage filter is also rendered on export)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.black.opacity(0.42)))
            let step: CGFloat = stroke.blurStyle == .pixelated ? 10 : 16
            var x = rect.minX
            var rowToggle = false
            while x < rect.maxX {
                var y = rect.minY
                var colToggle = rowToggle
                while y < rect.maxY {
                    let cell = CGRect(x: x, y: y, width: min(step, rect.maxX - x), height: min(step, rect.maxY - y))
                    context.fill(Path(cell), with: .color(.white.opacity(colToggle ? 0.28 : 0.12)))
                    colToggle.toggle()
                    y += step
                }
                rowToggle.toggle()
                x += step
            }
            context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
    }

    private func renderVectorOrTextStroke(_ stroke: DrawnStroke, into context: inout GraphicsContext) {
        guard !stroke.points.isEmpty else { return }
        var ctx = context
        if stroke.tool == .marker {
            ctx.opacity = 0.38
        }
        let color = Color(hex: stroke.colorHex)
        let dashPattern: [CGFloat] = {
            switch stroke.lineDashStyle {
            case .solid:  return []
            case .dashed: return [stroke.lineWidth * 3.0, stroke.lineWidth * 2.0]
            case .dotted: return [stroke.lineWidth * 0.8, stroke.lineWidth * 2.2]
            }
        }()
        let strokeStyle = StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round, dash: dashPattern)

        switch stroke.tool {
        case .pen, .marker:
            var path = Path()
            path.move(to: stroke.points[0])
            for pt in stroke.points.dropFirst() {
                path.addLine(to: pt)
            }
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))

        case .line:
            guard stroke.points.count >= 2 else { break }
            var path = Path()
            path.move(to: stroke.points[0])
            path.addLine(to: stroke.points[stroke.points.count - 1])
            ctx.stroke(path, with: .color(color), style: strokeStyle)

        case .arrow:
            guard stroke.points.count >= 2 else { break }
            renderArrow(start: stroke.points[0], end: stroke.points[stroke.points.count - 1], lineWidth: stroke.lineWidth, style: stroke.arrowStyle, color: color, into: &ctx)

        case .rect:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            let path = Path(roundedRect: r, cornerRadius: 4)
            if stroke.isFilled {
                ctx.fill(path, with: .color(color))
            } else {
                ctx.stroke(path, with: .color(color), style: strokeStyle)
            }

        case .filledRect:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            ctx.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(color))

        case .oval:
            guard stroke.points.count >= 2 else { break }
            let p1 = stroke.points[0]
            let p2 = stroke.points[stroke.points.count - 1]
            let r = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
            let path = Path(ellipseIn: r)
            if stroke.isFilled {
                ctx.fill(path, with: .color(color))
            } else {
                ctx.stroke(path, with: .color(color), style: strokeStyle)
            }

        case .counter:
            let center = stroke.points[0]
            let radius = max(13, stroke.lineWidth * 3.4)
            if stroke.points.count >= 2 {
                let end = stroke.points[stroke.points.count - 1]
                if hypot(end.x - center.x, end.y - center.y) > radius + 6 {
                    renderArrow(start: center, end: end, lineWidth: max(2.5, stroke.lineWidth), style: .straight, color: color, into: &ctx)
                }
            }
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            ctx.fill(Path(ellipseIn: circleRect), with: .color(color))
            ctx.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 2)
            let fg: Color = stroke.colorHex.uppercased() == "#FFFFFF" ? .black : .white
            let text = Text("\(stroke.counterNumber)")
                .font(.system(size: radius * 1.05, weight: .bold, design: .rounded))
                .foregroundColor(fg)
            ctx.draw(text, at: center, anchor: .center)

        case .text:
            let content = stroke.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { break }
            let origin = stroke.points[0]
            let fg: Color = {
                switch stroke.textBoxStyle {
                case .plain:     return color
                case .solidPill: return stroke.colorHex.uppercased() == "#FFFFFF" ? .black : .white
                case .darkPill:  return .white
                }
            }()
            let resolved = ctx.resolve(
                Text(content)
                    .font(.system(size: stroke.fontSize, weight: .semibold))
                    .foregroundColor(fg)
            )
            let textSize = resolved.measure(in: CGSize(width: 1000, height: 400))
            let padX: CGFloat = 10
            let padY: CGFloat = 6
            let pillRect = CGRect(x: origin.x, y: origin.y, width: textSize.width + padX * 2, height: textSize.height + padY * 2)
            if stroke.textBoxStyle != .plain {
                let bg: Color = stroke.textBoxStyle == .solidPill ? color : Color.black.opacity(0.78)
                ctx.fill(Path(roundedRect: pillRect, cornerRadius: 8), with: .color(bg))
            }
            ctx.draw(resolved, at: CGPoint(x: origin.x + padX, y: origin.y + padY), anchor: .topLeading)

        case .select, .blur, .spotlight, .crop, .move:
            break
        }
    }

    private func renderArrow(start: CGPoint, end: CGPoint, lineWidth: CGFloat, style: ArrowStyle, color: Color, into ctx: inout GraphicsContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = hypot(dx, dy)
        guard dist >= 4 else { return }

        var path = Path()
        path.move(to: start)
        let tangentAngle: CGFloat

        if style == .straight {
            path.addLine(to: end)
            tangentAngle = atan2(dy, dx)
        } else {
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let perpX = -dy / dist
            let perpY = dx / dist
            let sign: CGFloat = (style == .curvedLeft) ? -1.0 : 1.0
            let bend = min(80, dist * 0.26) * sign
            let ctrl = CGPoint(x: mid.x + perpX * bend, y: mid.y + perpY * bend)
            path.addQuadCurve(to: end, control: ctrl)
            tangentAngle = atan2(end.y - ctrl.y, end.x - ctrl.x)
        }

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
        path.move(to: p1)
        path.addLine(to: end)
        path.addLine(to: p2)

        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func renderWatermark(text: String, size: CGSize, into ctx: inout GraphicsContext) {
        let resolved = ctx.resolve(
            Text(text)
                .font(.system(size: max(13, min(22, size.width * 0.024)), weight: .semibold))
                .foregroundColor(.white.opacity(watermarkOpacity))
        )
        let sz = resolved.measure(in: size)
        switch watermarkMode {
        case .none:
            break
        case .corner:
            ctx.draw(resolved, at: CGPoint(x: max(12, size.width - sz.width - 16), y: max(12, size.height - sz.height - 14)), anchor: .topLeading)
        case .diagonal:
            var c = ctx
            c.translateBy(x: size.width / 2, y: size.height / 2)
            c.rotate(by: .degrees(-30))
            c.draw(resolved, at: .zero, anchor: .center)
        case .tiled:
            let stepX = max(140, sz.width + 80)
            let stepY = max(90, sz.height + 64)
            var y: CGFloat = 24
            while y < size.height {
                var x: CGFloat = 24
                while x < size.width {
                    var c = ctx
                    c.translateBy(x: x + sz.width / 2, y: y + sz.height / 2)
                    c.rotate(by: .degrees(-22))
                    c.draw(resolved, at: .zero, anchor: .center)
                    x += stepX
                }
                y += stepY
            }
        }
    }
}

// MARK: - Pinned Floating Screenshot Window View (Snapzy Pin to Screen)

struct PinnedScreenshotView: View {
    let image: NSImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Rad.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.65), lineWidth: 1.5)
                )

            HStack(spacing: 4) {
                Button {
                    if let tiff = image.tiffRepresentation {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setData(tiff, forType: .tiff)
                    }
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help(tr("Sao chép ảnh ghim", "Copy pinned image"))

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FS.caption, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
                .help(tr("Đóng ảnh ghim", "Close pinned image"))
            }
            .padding(8)
        }
    }
}

