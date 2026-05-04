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

    // Tracks which hanger is currently being pressed (squish phase)
    @State private var pressedID: UUID? = nil

    // Tracks which hangers have an active ripple
    @State private var ripplingIDs: Set<UUID> = []

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(walker.activeHangers.values), id: \.id) { hanger in
                    if let img = hanger.character.image {
                        HangingCharacterView(
                            image: img,
                            config: hanger.config,
                            windowSize: geo.size,
                            isPressed: pressedID == hanger.id,
                            isRippling: ripplingIDs.contains(hanger.id)
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // Listen for click notifications fired by MenuBarWalker
        .onReceive(
            NotificationCenter.default.publisher(
                for: .hangerDidReceiveClick
            )
        ) { note in
            guard let id = note.userInfo?["id"] as? UUID else { return }
            triggerClickAnimation(for: id)
        }
    }

    // MARK: - Animation sequencer

    private func triggerClickAnimation(for id: UUID) {
        // 1. Squish down
        withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
            pressedID = id
        }

        // 2. After 115 ms release — bouncy spring overshoots back to 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.115) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.35)) {
                pressedID = nil
            }

            // 3. Ripple fires on release, auto-clears after its duration
            ripplingIDs.insert(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                ripplingIDs.remove(id)
            }
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Post this from MenuBarWalker when a hanger is clicked.
    /// userInfo must contain ["id": hanger.id] (UUID).
    static let hangerDidReceiveClick = Notification.Name("hangerDidReceiveClick")
}

// MARK: - Individual Hanging Character View

private struct HangingCharacterView: View {
    let image: NSImage
    let config: HangingConfig
    let windowSize: CGSize

    // Animation state passed in from parent
    let isPressed: Bool
    let isRippling: Bool

    // How far the ripple has expanded (0 = just started, 1 = fully expanded)
    @State private var rippleProgress: CGFloat = 0

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

    // Squish deformation: compress vertically, spread horizontally on press
    private var squishScaleX: CGFloat { isPressed ? 1.15 : 1.0 }
    private var squishScaleY: CGFloat { isPressed ? 0.80 : 1.0 }

    // Overall bounce scale driven by the spring (applied on top of squish)
    private var bounceScale: CGFloat { isPressed ? 0.88 : 1.0 }

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

                let ropeCentreX = charCentreX + rope.horizontalOffset
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

            // ── Ripple ring — sits between rope and character ───────
            if isRippling {
                RippleRingView(
                    diameter: max(imageSize.width, imageSize.height)
                )
                .position(x: charCentreX, y: charCentreY)
                .frame(width: windowSize.width, height: windowSize.height,
                       alignment: .topLeading)
                .allowsHitTesting(false)
            }

            // ── Character — rendered on top ───────────────────────────
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: imageSize.width, height: imageSize.height)
                .scaleEffect(x: config.isFlipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(config.rotationAngle))
                // Squish deformation (fast, stiff spring)
                .scaleEffect(
                    x: squishScaleX,
                    y: squishScaleY,
                    anchor: .bottom         // squish from the bottom up — feels grounded
                )
                // Overall bounce scale (slow, loose spring for overshoot)
                .scaleEffect(bounceScale, anchor: .bottom)
                .animation(
                    isPressed
                        ? .spring(response: 0.12, dampingFraction: 0.7)   // snap down
                        : .spring(response: 0.48, dampingFraction: 0.32), // bouncy pop
                    value: isPressed
                )
                .position(x: charCentreX, y: charCentreY)
                .frame(width: windowSize.width, height: windowSize.height,
                       alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Ripple Ring

/// An expanding ring that fades out from the character's centre on click release.
private struct RippleRingView: View {
    let diameter: CGFloat

    @State private var scale: CGFloat = 0.25
    @State private var opacity: Double = 0.7

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.8), lineWidth: 2.5)
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) {
                    scale   = 2.4
                    opacity = 0.0
                }
            }
    }
}
