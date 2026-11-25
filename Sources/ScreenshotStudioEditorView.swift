import SwiftUI
import AppKit

// MARK: - Minimal Studio Editor View (Arrow & Text Only)

public struct ScreenshotStudioEditorView: View {
    @ObservedObject var manager: ScreenshotManager

    public init(manager: ScreenshotManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            topToolbar

            Divider().opacity(0.25)

            styleToolbar

            Divider().opacity(0.25)

            canvasArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.25)

            bottomFooter
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                )
                .padding(.top, 84)
            }
        }
    }

    // MARK: - Top Toolbar (Arrow & Text + Undo / Redo / Clear)

    private var topToolbar: some View {
        HStack(spacing: 8) {
            // Space for macOS traffic lights
            Spacer().frame(width: 66)

            // Only 2 tools: Arrow & Text
            HStack(spacing: 4) {
                ForEach(ScreenshotTool.allCases, id: \.self) { tool in
                    let isSelected = manager.currentTool == tool
                    Button {
                        manager.commitActiveTextEditing()
                        manager.currentTool = tool
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tool.icon)
                                .font(.system(size: FS.body, weight: isSelected ? .semibold : .medium))
                            Text(tool.title)
                                .font(.system(size: FS.label, weight: isSelected ? .semibold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: Rad.md).fill(Color.primary.opacity(0.05)))

            Spacer()

            HStack(spacing: 4) {
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

                if !manager.strokes.isEmpty {
                    Button {
                        manager.clearAllStrokes()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: FS.label))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Tone.bad)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Xoá tất cả chú thích", "Clear all annotations"))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Style Sub-Toolbar (Colors + Stroke Width / Font Size)

    private var styleToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                ForEach(manager.availableColors, id: \.self) { hex in
                    Button {
                        manager.selectedColorHex = hex
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

            if manager.currentTool == .arrow {
                HStack(spacing: 6) {
                    Text(tr("Độ dày:", "Size:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $manager.strokeWidth, in: 2.0...12.0)
                        .frame(width: 90)
                        .controlSize(.small)
                    Text("\(Int(round(manager.strokeWidth)))pt")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                }
            } else {
                HStack(spacing: 8) {
                    Text(tr("Cỡ chữ:", "Font:"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $manager.fontSize, in: 12...48)
                        .frame(width: 85)
                        .controlSize(.small)
                    Text("\(Int(manager.fontSize))pt")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Divider().frame(height: 16)

                    ForEach(TextBoxStyle.allCases, id: \.self) { style in
                        let selected = manager.textBoxStyle == style
                        Button {
                            manager.textBoxStyle = style
                        } label: {
                            Text(style.title)
                                .font(.system(size: FS.caption, weight: selected ? .semibold : .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.07)))
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Interactive Canvas Area

    private var canvasArea: some View {
        GeometryReader { geo in
            let imgSize = manager.studioLogicalSize
            let availW = max(160, geo.size.width - 36)
            let availH = max(160, geo.size.height - 36)
            let fitScale = min(1.0, min(availW / max(1, imgSize.width), availH / max(1, imgSize.height)))
            let displayScale = fitScale * manager.studioZoom

            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        if let nsImg = manager.studioBaseNSImage {
                            Image(nsImage: nsImg)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: imgSize.width, height: imgSize.height)
                        }

                        StudioAnnotationsCanvasView(
                            strokes: manager.strokes,
                            activeStroke: manager.activeStroke
                        )
                        .frame(width: imgSize.width, height: imgSize.height)

                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: imgSize.width, height: imgSize.height)
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { val in
                                        handleDragChanged(val)
                                    }
                                    .onEnded { val in
                                        handleDragEnded(val)
                                    }
                            )

                        if manager.editingTextStrokeID != nil {
                            inlineTextEditorOverlay(imgSize: imgSize)
                        }
                    }
                    .frame(width: imgSize.width, height: imgSize.height)
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
                    .scaleEffect(displayScale)
                    .frame(
                        width: max(geo.size.width, imgSize.width * displayScale + 36),
                        height: max(geo.size.height, imgSize.height * displayScale + 36)
                    )
                }
            }
        }
    }

    private func handleDragChanged(_ val: DragGesture.Value) {
        guard manager.currentTool == .arrow else { return }
        let start = val.startLocation
        let cur = val.location
        guard hypot(cur.x - start.x, cur.y - start.y) >= 3 else { return }
        manager.activeStroke = DrawnStroke(
            tool: .arrow,
            points: [start, cur],
            colorHex: manager.selectedColorHex,
            lineWidth: manager.strokeWidth
        )
    }

    private func handleDragEnded(_ val: DragGesture.Value) {
        if manager.currentTool == .text {
            manager.beginTextAnnotation(at: val.startLocation)
            return
        }
        if let stroke = manager.activeStroke {
            manager.addStroke(stroke)
            manager.activeStroke = nil
        }
    }

    private func inlineTextEditorOverlay(imgSize: CGSize) -> some View {
        let pt = manager.editingTextPoint
        let clampedX = min(max(8, pt.x), max(8, imgSize.width - 210))
        let clampedY = min(max(8, pt.y), max(8, imgSize.height - 44))

        return HStack(spacing: 4) {
            TextField(tr("Nhập chữ...", "Type text..."), text: $manager.editingTextValue)
                .textFieldStyle(.plain)
                .font(.system(size: max(14, min(28, manager.fontSize)), weight: .semibold))
                .foregroundStyle(manager.textBoxStyle == .plain ? Color(hex: manager.selectedColorHex) : .white)
                .frame(minWidth: 150, maxWidth: 300)
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
        .position(x: clampedX + 95, y: clampedY + 18)
    }

    // MARK: - Bottom Export Footer

    private var bottomFooter: some View {
        HStack(spacing: 8) {
            let w = Int(round(manager.studioLogicalSize.width * manager.scaleFactor))
            let h = Int(round(manager.studioLogicalSize.height * manager.scaleFactor))
            Text("\(w) × \(h) px")
                .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

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

            Button {
                manager.saveToDownloads()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: FS.caption, weight: .semibold))
                    Text(tr("Lưu (⌘S)", "Save (⌘S)"))
                        .font(.system(size: FS.label, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)

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
        .padding(.vertical, 8)
    }
}

// MARK: - Minimal Annotations Canvas (Arrow & Text Only)

public struct StudioAnnotationsCanvasView: View {
    public let strokes: [DrawnStroke]
    public let activeStroke: DrawnStroke?

    public var body: some View {
        Canvas { context, _ in
            let allStrokes = strokes + (activeStroke.map { [$0] } ?? [])
            for stroke in allStrokes {
                renderStroke(stroke, into: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func renderStroke(_ stroke: DrawnStroke, into ctx: inout GraphicsContext) {
        guard !stroke.points.isEmpty else { return }
        let color = Color(hex: stroke.colorHex)

        switch stroke.tool {
        case .arrow:
            guard stroke.points.count >= 2 else { return }
            let start = stroke.points[0]
            let end = stroke.points[stroke.points.count - 1]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dist = hypot(dx, dy)
            guard dist >= 4 else { return }

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

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
            path.move(to: p1)
            path.addLine(to: end)
            path.addLine(to: p2)

            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))

        case .text:
            let content = stroke.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return }
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
        }
    }
}
