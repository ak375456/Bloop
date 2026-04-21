//
//  CreateHangerView.swift
//  Bloop
//

import SwiftUI
import AppKit
import Vision
import UniformTypeIdentifiers

// MARK: - Brush Mode

enum BrushMode {
    case erase, restore
}

// MARK: - Main View

struct CreateHangerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: CustomCharacterStore

    @State private var step: Int = 1
    @State private var originalImage: NSImage? = nil
    @State private var processedImage: NSImage? = nil
    @State private var maskImage: NSImage? = nil
    @State private var isProcessing = false
    @State private var characterSize: CGFloat = 120
    @State private var characterName: String = ""
    @State private var showNameError = false

    @State private var brushMode: BrushMode = .erase
    @State private var brushSize: CGFloat = 30
    @State private var brushSoftness: CGFloat = 0.5
    @State private var previewOpacity: CGFloat = 0.5
    @State private var isManualMode: Bool = false

    // Rope state
    @State private var ropeEnabled: Bool = false
    @State private var ropeStyleIndex: Int = 1
    @State private var ropeSize: CGFloat = 40
    @State private var ropeVerticalOffset: CGFloat = 0
    @State private var ropeHorizontalOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Create Hanging Character")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Spacer()

                HStack(spacing: 6) {
                    ForEach(1...2, id: \.self) { s in
                        Circle()
                            .fill(s == step ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // ── Privacy Notice ───────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom characters are stored locally on your device.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("We never store or share your images.")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.07))

            Group {
                if step == 1 { step1View }
                else         { step2View }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ── Footer ───────────────────────────────────────────
            HStack {
                if step > 1 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                Spacer()
                if step == 1 {
                    Button("Next: Name & Rope") { withAnimation { step = 2 } }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(processedImage == nil)
                } else {
                    Button("Save Character") { saveCharacter() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(characterName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 600, height: 660)
        .background(.regularMaterial)
    }

    // MARK: - Step 1: Upload + BG Removal

    private var step1View: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    if isManualMode, let original = originalImage {
                        BrushCanvasView(
                            originalImage: original,
                            maskImage: $maskImage,
                            brushMode: brushMode,
                            brushSize: brushSize,
                            brushSoftness: brushSoftness,
                            previewOpacity: previewOpacity,
                            onCompositeUpdated: { processedImage = $0 }
                        )
                        .frame(height: previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if let img = processedImage ?? originalImage {
                        ZStack {
                            CheckerboardView()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .opacity(processedImage != nil ? 1 : 0)
                            Image(nsImage: img)
                                .resizable().scaledToFit()
                                .frame(height: previewHeight - 16)
                        }
                        .frame(height: previewHeight)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentColor.opacity(0.6))
                            Text("Click to select an image")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: previewHeight)
                .onTapGesture { if originalImage == nil { pickImage() } }

                HStack(spacing: 10) {
                    Button { pickImage() } label: {
                        Label(originalImage == nil ? "Select Image" : "Change Image",
                              systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered).controlSize(.regular)

                    if originalImage != nil {
                        Button {
                            isManualMode = false; removeBackground()
                        } label: {
                            HStack {
                                if isProcessing { ProgressView().scaleEffect(0.7) }
                                else { Image(systemName: "wand.and.stars") }
                                Text("Auto Remove BG")
                            }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.regular)
                        .disabled(isProcessing)

                        Button { isManualMode = true } label: {
                            Label("Manual Brush", systemImage: "paintbrush.pointed")
                        }
                        .if(isManualMode)  { $0.buttonStyle(.borderedProminent) }
                        .if(!isManualMode) { $0.buttonStyle(.bordered) }
                        .controlSize(.regular)
                    }
                }

                if originalImage != nil {
                    GroupBox {
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Character Size: \(Int(characterSize))px")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("This is the saved output size")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            Slider(value: $characterSize, in: 40...400, step: 10)

                            if processedImage != nil || isManualMode {
                                Divider()
                                HStack {
                                    Text("BG Preview Opacity")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(previewOpacity * 100))%")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(value: $previewOpacity, in: 0...1)
                            }

                            if isManualMode {
                                Divider()
                                Text("Brush Settings")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker("Mode", selection: $brushMode) {
                                    Label("Erase",   systemImage: "eraser.fill")
                                        .tag(BrushMode.erase)
                                    Label("Restore", systemImage: "paintbrush.fill")
                                        .tag(BrushMode.restore)
                                }
                                .pickerStyle(.segmented)
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.system(size: 8)).foregroundStyle(.secondary)
                                    Slider(value: $brushSize, in: 5...120, step: 1)
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 18)).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("Size: \(Int(brushSize))px")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                    Spacer()
                                }
                                HStack {
                                    Text("Edge Softness").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(brushSoftness < 0.25 ? "Sharp"
                                         : brushSoftness < 0.65 ? "Medium" : "Soft")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                HStack {
                                    Text("Sharp").font(.caption2).foregroundStyle(.tertiary)
                                    Slider(value: $brushSoftness, in: 0...1)
                                    Text("Soft").font(.caption2).foregroundStyle(.tertiary)
                                }
                                HStack {
                                    Button("Reset Mask") {
                                        maskImage = nil; processedImage = originalImage
                                    }
                                    .font(.caption).foregroundStyle(.red).buttonStyle(.plain)
                                    Spacer()
                                    Button("Apply Auto BG then Refine") {
                                        isManualMode = false
                                        removeBackground { isManualMode = true }
                                    }
                                    .font(.caption).foregroundColor(.accentColor)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text("Settings").font(.caption).fontWeight(.semibold)
                    }
                }
            }
            .padding(24)
        }
    }

    private var previewHeight: CGFloat { min(max(characterSize + 40, 160), 260) }

    // MARK: - Step 2: Name + Rope

    private var step2View: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Character preview
                if let charImg = processedImage ?? originalImage {
                    Image(nsImage: charImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                }

                Text("Looking good! Give your character a name and optionally add a rope.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // ── Name ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Character Name", systemImage: "pencil")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    TextField("e.g. My Cat, Space Alien…", text: $characterName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(maxWidth: 320)
                        .onSubmit { saveCharacter() }
                    if showNameError {
                        Text("Please enter a name.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }

                Divider()

                // ── Rope ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Rope (optional)", systemImage: "line.diagonal")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $ropeEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .scaleEffect(0.85)
                    }

                    if ropeEnabled {
                        // Style picker grid
                        RopeStylePicker(selectedStyle: $ropeStyleIndex)

                        GroupBox {
                            VStack(spacing: 12) {
                                // Size
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Rope Size: \(Int(ropeSize))px")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    Slider(value: $ropeSize, in: 10...200, step: 2)
                                }

                                Divider()

                                // Vertical position from top of screen
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Vertical Position: \(Int(ropeVerticalOffset))px from top")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    Slider(value: $ropeVerticalOffset, in: 0...200, step: 1)
                                }

                                Divider()

                                // Horizontal nudge relative to character
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Horizontal Offset: \(Int(ropeHorizontalOffset))px")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    Slider(value: $ropeHorizontalOffset, in: -100...100, step: 1)
                                }
                            }
                            .padding(.vertical, 4)
                        } label: {
                            Text("Rope Position").font(.caption).fontWeight(.semibold)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: 360)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: ropeEnabled)

                Text("You can adjust the rope and character after placing it on your screen.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Image Picking

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes  = [UTType.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let img = NSImage(contentsOf: url) {
            originalImage  = img
            processedImage = nil
            maskImage      = nil
            isManualMode   = false
            removeBackground()
        }
    }

    // MARK: - Auto BG Removal

    private func removeBackground(completion: (() -> Void)? = nil) {
        guard let original = originalImage else { return }
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            let (result, mask) = await Self.removeBackgroundVision(from: original)
            await MainActor.run {
                processedImage = result ?? original
                maskImage      = mask
                isProcessing   = false
                completion?()
            }
        }
    }

    private static func removeBackgroundVision(from image: NSImage) async -> (NSImage?, NSImage?) {
        guard #available(macOS 12.0, *),
              let tiff    = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return (nil, nil) }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage)
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return (nil, nil) }
            let maskBuffer = try result.generateScaledMaskForImage(
                forInstances: result.allInstances, from: handler)
            let maskCI  = CIImage(cvPixelBuffer: maskBuffer)
            let blended = ciImage.applyingFilter("CIBlendWithMask", parameters: [
                "inputMaskImage": maskCI, "inputBackgroundImage": CIImage.empty()
            ])
            let ctx = CIContext()
            guard let cgBlended = ctx.createCGImage(blended, from: blended.extent)
            else { return (nil, nil) }
            let resultImg = NSImage(cgImage: cgBlended,
                                    size: NSSize(width: cgBlended.width,
                                                 height: cgBlended.height))
            guard let cgMask = ctx.createCGImage(maskCI, from: maskCI.extent)
            else { return (resultImg, nil) }
            let maskImg = NSImage(cgImage: cgMask,
                                  size: NSSize(width: cgMask.width, height: cgMask.height))
            return (resultImg, maskImg)
        } catch { return (nil, nil) }
    }

    // MARK: - Save

    private func saveCharacter() {
        let name = characterName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { showNameError = true; return }
        guard let charImg = processedImage ?? originalImage else { return }

        let trimmed = charImg.trimmingTransparentPixels()
        let maxSavedSize: CGFloat = 1024
        let longestSide = max(trimmed.size.width, trimmed.size.height)
        let saveImage: NSImage = longestSide > maxSavedSize
            ? trimmed.scaledProportionally(to: CGSize(width: maxSavedSize, height: maxSavedSize))
            : trimmed

        let screenWidth = NSScreen.main?.frame.width ?? 1440

        let ropeConfig: RopeConfig? = ropeEnabled
            ? RopeConfig(
                styleIndex: ropeStyleIndex,
                size: ropeSize,
                verticalOffset: ropeVerticalOffset,
                horizontalOffset: ropeHorizontalOffset
              )
            : nil

        // If a rope is attached, push the character down so it starts below the rope bottom
        let charVerticalOffset: CGFloat
        if ropeEnabled,
           let ropeImg = NSImage(named: String(format: "rope_%02d", ropeStyleIndex)),
           ropeImg.size.width > 0 {
            let ropeAspect = ropeImg.size.height / ropeImg.size.width
            let ropeH = ropeSize * ropeAspect
            charVerticalOffset = ropeVerticalOffset + ropeH
        } else {
            charVerticalOffset = 0
        }

        store.save(
            image: saveImage,
            name: name,
            initialConfig: HangingConfig(
                size: characterSize,
                horizontalPosition: screenWidth / 2,
                verticalOffset: charVerticalOffset,
                extendedDrop: false,
                isFlipped: false,
                rotationAngle: 0,
                link: .none,
                isInteractive: false,
                rope: ropeConfig
            )
        )
        dismiss()
    }
}

// MARK: - Rope Style Picker

private struct RopeStylePicker: View {
    @Binding var selectedStyle: Int
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style")
                .font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...6, id: \.self) { index in
                    Button {
                        selectedStyle = index
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedStyle == index
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.gray.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedStyle == index
                                                ? Color.accentColor
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )

                            if let ropeImg = NSImage(named: String(format: "rope_%02d", index)) {
                                Image(nsImage: ropeImg)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                            } else {
                                Image(systemName: "line.diagonal")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedStyle)
                }
            }
        }
    }
}

// MARK: - BrushCanvasView

struct BrushCanvasView: NSViewRepresentable {
    let originalImage: NSImage
    @Binding var maskImage: NSImage?
    var brushMode: BrushMode
    var brushSize: CGFloat
    var brushSoftness: CGFloat
    var previewOpacity: CGFloat
    var onCompositeUpdated: (NSImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> BrushCanvasNSView {
        let view = BrushCanvasNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: BrushCanvasNSView, context: Context) {
        context.coordinator.parent = self
        if nsView.originalImage !== originalImage {
            nsView.originalImage = originalImage
            if let m = maskImage { nsView.maskImage = m }
        }
        nsView.brushMode      = brushMode
        nsView.brushSize      = brushSize
        nsView.brushSoftness  = brushSoftness
        nsView.previewOpacity = previewOpacity
        nsView.needsDisplay   = true
    }

    class Coordinator {
        var parent: BrushCanvasView
        init(_ parent: BrushCanvasView) { self.parent = parent }
        func compositeUpdated(_ image: NSImage) { parent.onCompositeUpdated(image) }
    }
}

// MARK: - BrushCanvasNSView

class BrushCanvasNSView: NSView {
    weak var coordinator: BrushCanvasView.Coordinator?

    var originalImage: NSImage? { didSet { rebuildOriginalCG(); rebuildComposite() } }
    var brushMode: BrushMode    = .erase
    var brushSize: CGFloat      = 30
    var brushSoftness: CGFloat  = 0.5
    var previewOpacity: CGFloat = 0.5

    var maskImage: NSImage {
        get { maskNSImage }
        set { importMask(from: newValue) }
    }

    private var maskNSImage: NSImage  = NSImage()
    private var maskCtx: CGContext?
    private var maskW: Int            = 0
    private var maskH: Int            = 0
    private var originalCG: CGImage?
    private var compositeCG: CGImage?
    private var cursorPoint: CGPoint? = nil
    private var lastPoint: CGPoint?   = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        let opts: NSTrackingArea.Options = [
            .mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect
        ]
        addTrackingArea(NSTrackingArea(rect: .zero, options: opts, owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }

    private func imageDrawRect() -> NSRect {
        guard let sz = originalImage?.size, sz.width > 0, sz.height > 0 else { return bounds }
        let vs = bounds.size
        let s  = min(vs.width / sz.width, vs.height / sz.height)
        return NSRect(x: (vs.width  - sz.width  * s) / 2,
                      y: (vs.height - sz.height * s) / 2,
                      width:  sz.width  * s,
                      height: sz.height * s)
    }

    private func viewPointToMaskPixel(_ vp: CGPoint) -> CGPoint {
        let dr = imageDrawRect()
        guard dr.width > 0, dr.height > 0 else { return .zero }
        return CGPoint(
            x: ((vp.x - dr.minX) / dr.width)        * CGFloat(maskW),
            y: (1 - (vp.y - dr.minY) / dr.height)   * CGFloat(maskH)
        )
    }

    private func rebuildOriginalCG() {
        guard let img = originalImage,
              let cg  = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { originalCG = nil; return }
        originalCG = cg
        if maskCtx == nil || maskW != cg.width || maskH != cg.height {
            createMaskContext(width: cg.width, height: cg.height, fillWhite: true)
        }
    }

    private func createMaskContext(width: Int, height: Int, fillWhite: Bool) {
        maskW = width; maskH = height
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return }
        if fillWhite {
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        maskCtx = ctx
        syncMaskNSImage()
    }

    private func importMask(from nsImg: NSImage) {
        guard maskW > 0, maskH > 0, let ctx = maskCtx else { maskNSImage = nsImg; return }
        guard let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: maskW, height: maskH))
        syncMaskNSImage(); rebuildComposite(); needsDisplay = true
    }

    private func syncMaskNSImage() {
        guard let ctx = maskCtx, let cg = ctx.makeImage() else { return }
        maskNSImage = NSImage(cgImage: cg, size: NSSize(width: maskW, height: maskH))
    }

    private func rebuildComposite() {
        guard let orig = originalCG, let ctx = maskCtx, let maskCG = ctx.makeImage()
        else { compositeCG = originalCG; return }
        let w = orig.width, h = orig.height
        guard let out = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                        CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        let rect    = CGRect(x: 0, y: 0, width: w, height: h)
        let blended = CIImage(cgImage: orig).applyingFilter("CIBlendWithMask", parameters: [
            "inputMaskImage": CIImage(cgImage: maskCG),
            "inputBackgroundImage": CIImage.empty()
        ])
        CIContext(cgContext: out, options: nil).draw(blended, in: rect, from: blended.extent)
        compositeCG = out.makeImage()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let dr = imageDrawRect()
        drawCheckerboard(ctx: ctx, in: dr)
        if previewOpacity > 0, let orig = originalCG {
            ctx.saveGState(); ctx.setAlpha(previewOpacity * 0.45)
            ctx.draw(orig, in: dr); ctx.restoreGState()
        }
        if let comp = compositeCG { ctx.draw(comp, in: dr) }
        if let cp = cursorPoint   { drawBrushCursor(ctx: ctx, at: cp) }
    }

    private func drawCheckerboard(ctx: CGContext, in rect: NSRect) {
        let tile: CGFloat = 10
        for row in 0..<Int(ceil(rect.height / tile)) {
            for col in 0..<Int(ceil(rect.width / tile)) {
                ctx.setFillColor((row + col) % 2 == 0
                    ? CGColor.white : CGColor(gray: 0.85, alpha: 1))
                ctx.fill(CGRect(
                    x: rect.minX + CGFloat(col) * tile,
                    y: rect.minY + CGFloat(row) * tile,
                    width:  min(tile, rect.maxX - rect.minX - CGFloat(col) * tile),
                    height: min(tile, rect.maxY - rect.minY - CGFloat(row) * tile)
                ))
            }
        }
    }

    private func drawBrushCursor(ctx: CGContext, at vp: CGPoint) {
        let dr = imageDrawRect(); guard dr.width > 0 else { return }
        let r  = (brushSize / 2) * (dr.width / CGFloat(max(maskW, 1)))
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.6)); ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: vp.x-r,   y: vp.y-r,   width: r*2,     height: r*2))
        ctx.setStrokeColor(CGColor.white);            ctx.setLineWidth(0.75)
        ctx.strokeEllipse(in: CGRect(x: vp.x-r+1, y: vp.y-r+1, width: (r-1)*2, height: (r-1)*2))
        ctx.setFillColor(brushMode == .erase
            ? CGColor(red: 1,   green: 0.3, blue: 0.3, alpha: 0.9)
            : CGColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.9))
        ctx.fillEllipse(in: CGRect(x: vp.x-2, y: vp.y-2, width: 4, height: 4))
        ctx.restoreGState()
    }

    override func mouseMoved(with e: NSEvent)   {
        cursorPoint = convert(e.locationInWindow, from: nil); needsDisplay = true }
    override func mouseEntered(with e: NSEvent) {
        cursorPoint = convert(e.locationInWindow, from: nil); needsDisplay = true }
    override func mouseExited(with e: NSEvent)  { cursorPoint = nil; needsDisplay = true }

    override func mouseDown(with e: NSEvent) {
        let vp = convert(e.locationInWindow, from: nil)
        cursorPoint = vp; lastPoint = vp; paintStroke(at: vp)
    }
    override func mouseDragged(with e: NSEvent) {
        let vp = convert(e.locationInWindow, from: nil)
        cursorPoint = vp
        if let last = lastPoint { interpolatePaint(from: last, to: vp) }
        lastPoint = vp
    }
    override func mouseUp(with e: NSEvent) {
        lastPoint = nil
        syncMaskNSImage()
        if let cg = compositeCG {
            coordinator?.compositeUpdated(
                NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            )
        }
    }

    private func interpolatePaint(from: CGPoint, to: CGPoint) {
        let dr     = imageDrawRect()
        let stepPx = max((brushSize * (dr.width / CGFloat(max(maskW, 1)))) * 0.15, 1.0)
        let dist   = hypot(to.x - from.x, to.y - from.y)
        let steps  = max(Int(dist / stepPx), 1)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            paintStroke(at: CGPoint(x: from.x + (to.x - from.x) * t,
                                    y: from.y + (to.y - from.y) * t))
        }
    }

    private func paintStroke(at viewPoint: CGPoint) {
        guard let ctx = maskCtx, maskW > 0, maskH > 0 else { return }
        let mp     = viewPointToMaskPixel(viewPoint)
        let dr     = imageDrawRect(); guard dr.width > 0 else { return }
        let radius = max((brushSize / 2) / (dr.width / CGFloat(maskW)), 1.0)
        let isErase = (brushMode == .erase)
        let bx  = Int(max(mp.x - radius - 2, 0))
        let by  = Int(max(mp.y - radius - 2, 0))
        let bx2 = Int(min(mp.x + radius + 2, CGFloat(maskW)))
        let by2 = Int(min(mp.y + radius + 2, CGFloat(maskH)))
        guard bx2 > bx, by2 > by, let data = ctx.data else { return }
        let ptr      = data.bindMemory(to: UInt8.self, capacity: maskW * maskH)
        let bpr      = ctx.bytesPerRow
        let hardEdge = brushSoftness < 0.03
        for py in by..<by2 {
            for px in bx..<bx2 {
                let dist = sqrt(pow(CGFloat(px) - mp.x, 2) + pow(CGFloat(py) - mp.y, 2))
                guard dist <= radius else { continue }
                let alpha: CGFloat
                if hardEdge { alpha = 1 }
                else {
                    let t  = dist / radius
                    let hc = 1 - brushSoftness
                    alpha  = t < hc ? 1 : (1 + cos(((t - hc) / (1 - hc)) * .pi)) / 2
                }
                let idx = py * bpr + px
                let cur = CGFloat(ptr[idx]) / 255
                ptr[idx] = UInt8(max(0, min(255,
                    (isErase ? cur * (1 - alpha) : cur + (1 - cur) * alpha) * 255
                )))
            }
        }
        rebuildComposite()
        setNeedsDisplay(imageDrawRect())
    }
}

// MARK: - CheckerboardView

struct CheckerboardView: View {
    var tileSize: CGFloat = 10
    var body: some View {
        Canvas { ctx, size in
            for row in 0...Int(size.height / tileSize) {
                for col in 0...Int(size.width / tileSize) {
                    ctx.fill(
                        Path(CGRect(x: CGFloat(col) * tileSize,
                                    y: CGFloat(row) * tileSize,
                                    width: tileSize, height: tileSize)),
                        with: .color((row + col) % 2 == 0 ? .white : Color(white: 0.85))
                    )
                }
            }
        }
    }
}

// MARK: - Helpers

extension View {
    @ViewBuilder
    func `if`<C: View>(_ condition: Bool, transform: (Self) -> C) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension NSImage {
    func trimmingTransparentPixels() -> NSImage {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return self }
        let width  = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return self }
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                        CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return self }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let threshold: UInt8 = 10
        var minX = width,  maxX = 0
        var minY = height, maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
                if alpha > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard minX <= maxX, minY <= maxY else { return self }
        let cropRect = CGRect(x: minX, y: minY,
                              width: maxX - minX + 1,
                              height: maxY - minY + 1)
        guard let cropped = cgImage.cropping(to: cropRect) else { return self }
        return NSImage(cgImage: cropped,
                       size: NSSize(width: cropRect.width, height: cropRect.height))
    }

    func scaledProportionally(to maxSize: CGSize) -> NSImage {
        let aspectWidth  = maxSize.width  / size.width
        let aspectHeight = maxSize.height / size.height
        let scale        = min(aspectWidth, aspectHeight)
        let newSize      = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }
}
