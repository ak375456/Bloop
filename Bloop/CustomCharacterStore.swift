//
//  CustomCharacterStore.swift
//  Bloop
//

import AppKit
import Foundation
import Combine
import SwiftUI

struct CustomHangingCharacter: Identifiable, Codable {
    let id: UUID
    let name: String
    let imagePath: String
    var initialConfig: HangingConfig?

    init(id: UUID = UUID(),
         name: String,
         imagePath: String,
         initialConfig: HangingConfig? = nil) {
        self.id            = id
        self.name          = name
        self.imagePath     = imagePath
        self.initialConfig = initialConfig
    }

    var image: NSImage?     { NSImage(contentsOfFile: imagePath) }
    var thumbnail: NSImage? { image }
}

@MainActor
final class CustomCharacterStore: ObservableObject {
    static let shared = CustomCharacterStore()

    @Published var characters: [CustomHangingCharacter] = []

    private let storageDir: URL
    private let indexURL: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        storageDir = appSupport.appendingPathComponent("Bloop/CustomCharacters")
        indexURL   = storageDir.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        load()
    }

    func save(image: NSImage,
              name: String,
              initialConfig: HangingConfig? = nil) {

        let fileName = "\(UUID().uuidString).png"
        let fileURL  = storageDir.appendingPathComponent(fileName)

        guard let tiff   = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png    = bitmap.representation(using: .png, properties: [:]) else { return }

        try? png.write(to: fileURL)

        let character = CustomHangingCharacter(
            name: name,
            imagePath: fileURL.path,
            initialConfig: initialConfig
        )
        characters.append(character)
        persist()
    }

    func delete(_ character: CustomHangingCharacter) {
        try? FileManager.default.removeItem(atPath: character.imagePath)
        characters.removeAll { $0.id == character.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(characters) {
            try? data.write(to: indexURL)
        }
    }

    private func load() {
        guard let data  = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([CustomHangingCharacter].self, from: data)
        else { return }
        characters = saved.filter { FileManager.default.fileExists(atPath: $0.imagePath) }
    }
}
