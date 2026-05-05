//
//  Character.swift
//  Bloop
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
    let isPro: Bool

    init(
        name: String,
        framePrefix: String,
        frameCount: Int = 10,
        frameSize: CGSize = CGSize(width: 40, height: 40),
        walkSpeed: CGFloat = 1.5,
        ticksPerFrame: Int = 5,
        isPro: Bool = false
    ) {
        self.id           = UUID()
        self.name         = name
        self.framePrefix  = framePrefix
        self.frameCount   = frameCount
        self.frameSize    = frameSize
        self.walkSpeed    = walkSpeed
        self.ticksPerFrame = ticksPerFrame
        self.isPro        = isPro
    }

    func loadFrames() -> [NSImage] {
        (1...frameCount).compactMap { index in
            let name = String(format: "%@_%02d", framePrefix, index)
            guard let source = NSImage(named: name) else { return nil }
            return source.forceDecoded()
        }
    }

    var thumbnail: NSImage? {
        NSImage(named: String(format: "%@_01", framePrefix))
    }
}

private extension NSImage {
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
