//
//  HangingCharacter.swift
//  Bloop
//

import AppKit

protocol AnyHangingCharacter: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var image: NSImage? { get }
    var thumbnail: NSImage? { get }
}

struct HangingCharacter: Identifiable, Equatable, AnyHangingCharacter {
    let id: UUID
    let name: String
    let imageName: String
    let isPro: Bool

    init(name: String, imageName: String, isPro: Bool = false) {
        self.id        = UUID()
        self.name      = name
        self.imageName = imageName
        self.isPro     = isPro
    }

    var image: NSImage?     { NSImage(named: imageName) }
    var thumbnail: NSImage? { image }
}

extension CustomHangingCharacter: AnyHangingCharacter {}
