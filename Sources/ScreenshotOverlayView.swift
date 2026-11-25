import SwiftUI
import AppKit

// MARK: - Minimal Region Selection Overlay View (Opens Studio on Release)

public struct ScreenshotOverlayView: View {
    @ObservedObject var manager: ScreenshotManager

    public init(manager: ScreenshotManager) {
        self.manager = manager
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Frozen Screen Image
                if let nsImage = manager.screenNSImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)
                }

                // Translucent Veil with Selection Cutout
                CutoutVeil(cutout: (manager.selectionRect.width > 0 && manager.selectionRect.height > 0) ? manager.selectionRect : .zero)
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)

                if manager.selectionRect.width > 0 && manager.selectionRect.height > 0 {
                    selectionPreview(for: manager.selectionRect)
                        .allowsHitTesting(false)
                } else {
                    hintPill(in: geo)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func hintPill(in geo: GeometryProxy) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder")
                .font(.system(size: FS.body, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(NSScreen.screens.count > 1
                 ? tr("Kéo chọn vùng để mở Studio • Space di chuyển • ⇥ Đổi màn • ⎋ Huỷ", "Drag area to open Studio • Space move • ⇥ Switch screen • ⎋ Cancel")
                 : tr("Kéo chọn vùng để mở Studio • Space di chuyển • ⎋ Huỷ", "Drag area to open Studio • Space move • ⎋ Cancel"))
                .font(.system(size: FS.label, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.84))
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .position(x: geo.size.width / 2, y: 48)
    }

    private func selectionPreview(for sel: CGRect) -> some View {
        let badgeY = sel.origin.y > 28 ? (sel.origin.y - 14) : (sel.origin.y + 16)
        let retinaW = Int(round(sel.width * manager.scaleFactor))
        let retinaH = Int(round(sel.height * manager.scaleFactor))

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(width: max(0, sel.width), height: max(0, sel.height))
                .position(x: sel.midX, y: sel.midY)

            if sel.width >= 40 && sel.height >= 20 {
                HStack(spacing: 4) {
                    Text("\(Int(sel.width)) × \(Int(sel.height))")
                        .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("(\(retinaW)×\(retinaH) px)")
                        .font(.system(size: FS.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Rad.sm, style: .continuous)
                        .fill(Color.black.opacity(0.8))
                )
                .position(x: min(sel.minX + 85, sel.midX), y: badgeY)
            }
        }
    }
}

private struct CutoutVeil: Shape {
    var cutout: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if cutout.width > 0 && cutout.height > 0 {
            path.addRect(cutout)
        }
        return path
    }
}
