//
//  Character.swift
//  Bloop
//
//  Data model for a walking character.
//
//  PERFORMANCE FIX applied:
//  loadFrames() now force-decodes each webp frame into a plain bitmap at load time.
//  NSImage with webp defers actual pixel decoding until the first draw call, which
//  causes hitches mid-animation. Drawing into a new NSImage up-front pays the cost
//  once during toggle, not on the first rendered frame.
//

import AppKit

struct Character: Identifiable, Equatable {
    let id: UUID
    let name: String
    let framePrefix: String
    let frameCount: Int
    let frameSize: CGSize
    let walkSpeed: CGFloat
    let ticksPerFrame: Int

    init(
        name: String,
        framePrefix: String,
        frameCount: Int = 10,
        frameSize: CGSize = CGSize(width: 40, height: 40),
        walkSpeed: CGFloat = 1.5,
        ticksPerFrame: Int = 5
    ) {
        self.id = UUID()
        self.name = name
        self.framePrefix = framePrefix
        self.frameCount = frameCount
        self.frameSize = frameSize
        self.walkSpeed = walkSpeed
        self.ticksPerFrame = ticksPerFrame
    }

    /// Loads and force-decodes all walk-cycle frames from the app bundle.
    /// Expects images named: <framePrefix>_01.webp, _02.webp … _0N.webp
    ///
    /// Force-decoding: NSImage(named:) with webp is lazy — the compressed bytes are
    /// loaded but pixels aren't decoded until first draw. Calling draw() into a fresh
    /// NSImage here forces that work onto the calling thread (background, via toggleWalk)
    /// so the animation loop never stalls waiting for a decode.
    func loadFrames() -> [NSImage] {
        (1...frameCount).compactMap { index in
            let name = String(format: "%@_%02d", framePrefix, index)
            guard let source = NSImage(named: name) else { return nil }
            return source.forceDecoded()
        }
    }

    /// Returns the first frame as a preview image for the card thumbnail.
    var thumbnail: NSImage? {
        NSImage(named: String(format: "%@_01", framePrefix))
    }
}

// MARK: - NSImage force-decode helper

private extension NSImage {
    /// Returns a new NSImage whose pixels are fully decoded into a bitmap.
    /// Safe to call from any thread.
    func forceDecoded() -> NSImage {
        let decoded = NSImage(size: size)
        decoded.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        decoded.unlockFocus()
        return decoded
    }
}
