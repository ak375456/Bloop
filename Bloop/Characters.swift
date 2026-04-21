//
//  Character.swift
//  Bloop
//
//  Data model for a walking character.
//

import AppKit

struct Character: Identifiable, Equatable {
    let id: UUID
    let name: String         // Display name, e.g. "Santa Claus"
    let framePrefix: String  // Image name prefix, e.g. "santa_clause_walking"
    let frameCount: Int      // How many frames (usually 6)
    let frameSize: CGSize    // Rendered size on the menu bar (points)
    let walkSpeed: CGFloat   // Points moved per tick at 60 fps
    let ticksPerFrame: Int   // Animation speed (lower = faster)

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

    /// Loads all walk-cycle frames from the app bundle.
    /// Expects images named: <framePrefix>_01.webp, _02.webp … _0N.webp
    func loadFrames() -> [NSImage] {
        (1...frameCount).compactMap { index in
            let name = String(format: "%@_%02d", framePrefix, index)
            return NSImage(named: name)
        }
    }

    /// Returns the first frame as a preview image for the card thumbnail.
    var thumbnail: NSImage? {
        NSImage(named: String(format: "%@_01", framePrefix))
    }
}
