//
//  HangingOverlayWindow.swift
//  Bloop
//

import AppKit
import SwiftUI

final class HangingOverlayWindow: NSWindow {

    init(walker: MenuBarWalker) {
        super.init(contentRect: .zero, styleMask: [.borderless],
                   backing: .buffered, defer: false)
        isOpaque             = false
        backgroundColor      = .clear
        level                = .statusBar
        collectionBehavior   = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents   = true
        hasShadow            = false
        isReleasedWhenClosed = false
        contentView          = NSHostingView(rootView: HangingOverlayView(walker: walker))
    }

    func updateMousePassthrough(walker: MenuBarWalker) {
        // Click handling is done via global event monitor in MenuBarWalker
    }
}

// MARK: - Overlay View

struct HangingOverlayView: View {
    @ObservedObject var walker: MenuBarWalker

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(walker.activeHangers.values), id: \.id) { hanger in
                    if let img = hanger.character.image {
                        HangingCharacterView(
                            image: img,
                            config: hanger.config,
                            windowSize: geo.size
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Individual Hanging Character View

private struct HangingCharacterView: View {
    let image: NSImage
    let config: HangingConfig
    let windowSize: CGSize

    // Aspect-correct character size
    private var imageSize: CGSize {
        guard image.size.height > 0 else {
            return CGSize(width: config.size, height: config.size)
        }
        let aspect = image.size.width / image.size.height
        return CGSize(width: config.size * aspect, height: config.size)
    }

    // Character centre in overlay coordinate space (origin = top-left)
    private var charCentreX: CGFloat { config.horizontalPosition }
    private var charCentreY: CGFloat { config.verticalOffset + config.size / 2 }

    var body: some View {
        ZStack {
            // ── Rope — rendered first so it sits behind the character ──
            if let rope = config.rope,
               let ropeImg = NSImage(named: String(format: "rope_%02d", rope.styleIndex)) {

                let ropeAspect: CGFloat = ropeImg.size.width > 0
                    ? ropeImg.size.height / ropeImg.size.width
                    : 1.0

                let ropeW = rope.size
                let ropeH = ropeW * ropeAspect

                // Rope centre X = character centre X + horizontal nudge
                let ropeCentreX = charCentreX + rope.horizontalOffset

                // Rope top sits at rope.verticalOffset from the window top,
                // so rope centre Y = rope.verticalOffset + ropeH / 2
                let ropeCentreY = rope.verticalOffset + ropeH / 2

                Image(nsImage: ropeImg)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: ropeW, height: ropeH)
                    .position(x: ropeCentreX, y: ropeCentreY)
                    .frame(width: windowSize.width, height: windowSize.height,
                           alignment: .topLeading)
                    .allowsHitTesting(false)
            }

            // ── Character — rendered on top of rope ───────────────────
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: imageSize.width, height: imageSize.height)
                .scaleEffect(x: config.isFlipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(config.rotationAngle))
                .position(x: charCentreX, y: charCentreY)
                .frame(width: windowSize.width, height: windowSize.height,
                       alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }
}
