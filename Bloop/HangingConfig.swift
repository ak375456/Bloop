//
//  HangingConfig.swift
//  Bloop
//

import CoreGraphics

struct RopeConfig: Codable, Equatable {
    var styleIndex: Int           // 1–6  (matches rope_01.webp … rope_06.webp)
    var size: CGFloat             // width of the rope image
    var verticalOffset: CGFloat   // how far down from the window top the rope starts
    var horizontalOffset: CGFloat // left/right nudge relative to character centre

    static let `default` = RopeConfig(
        styleIndex: 1,
        size: 40,
        verticalOffset: 0,
        horizontalOffset: 0
    )
}

struct HangingConfig: Codable {
    var size: CGFloat
    var horizontalPosition: CGFloat
    var verticalOffset: CGFloat
    var extendedDrop: Bool
    var isFlipped: Bool
    var rotationAngle: Double
    var link: HangingLink
    var isInteractive: Bool
    var rope: RopeConfig?

    static let `default` = HangingConfig(
        size: 48,
        horizontalPosition: 200,
        verticalOffset: 0,
        extendedDrop: false,
        isFlipped: false,
        rotationAngle: 0,
        link: .none,
        isInteractive: false,
        rope: nil
    )
}
