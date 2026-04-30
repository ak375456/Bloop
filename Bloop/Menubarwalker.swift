//
//  MenuBarWalker.swift
//  Bloop
//

import AppKit
import SwiftUI
import Combine

// MARK: - CharacterConfig

struct CharacterConfig: Codable {
    var verticalOffset: CGFloat
    var movementSpeed: CGFloat
    var ticksPerFrame: Int
    var characterSize: CGFloat
    var extendedVertical: Bool
}

// MARK: - RenderItem
// Tiny Sendable value passed from the animation actor to the canvas each frame.

struct RenderItem: Sendable {
    let cgImage: CGImage
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let flipped: Bool
}

// MARK: - AnimationEngine
// Owns all mutable animation state. Runs on its own actor — never touches @MainActor.
// Sendable conformance is safe: all stored types are either value types or CGImage
// (which is a thread-safe Core Foundation object).

actor AnimationEngine {

    struct ActiveCharacter {
        let id: UUID
        let character: Character
        let cgFrames: [CGImage]
        var frameIndex: Int = 0
        var tickCount:  Int = 0
        var positionX:  CGFloat
        var facingRight: Bool = false
        var config: CharacterConfig
    }

    private var characters: [UUID: ActiveCharacter] = [:]

    func add(_ c: ActiveCharacter) {
        characters[c.id] = c
    }

    func remove(id: UUID) {
        characters.removeValue(forKey: id)
    }

    func removeAll() {
        characters.removeAll()
    }

    func updateConfig(_ config: CharacterConfig, for id: UUID) {
        characters[id]?.config = config
    }

    /// Advances every character by one tick and returns a render snapshot.
    func tick(screenWidth: CGFloat) -> [RenderItem] {
        var items = [RenderItem]()
        items.reserveCapacity(characters.count)

        for id in characters.keys {
            guard var c = characters[id] else { continue }

            c.tickCount += 1
            if c.tickCount % max(1, c.config.ticksPerFrame) == 0 {
                c.frameIndex = (c.frameIndex + 1) % c.cgFrames.count
            }

            let delta = c.facingRight ? c.config.movementSpeed : -c.config.movementSpeed
            c.positionX += delta
            if c.positionX < -c.config.characterSize { c.positionX = screenWidth + c.config.characterSize }
            if c.positionX > screenWidth + c.config.characterSize { c.positionX = -c.config.characterSize }

            characters[id] = c

            items.append(RenderItem(
                cgImage: c.cgFrames[c.frameIndex],
                x:       c.positionX,
                y:       16 + c.config.verticalOffset,
                size:    c.config.characterSize,
                flipped: !c.facingRight
            ))
        }
        return items
    }
}

// MARK: - CharacterProxy
// Lightweight @Published-safe stand-in used only by the sidebar config UI.
// Holds no frames or CGImages.

final class CharacterProxy: Identifiable {
    let id: UUID
    let name: String
    var config: CharacterConfig
    init(id: UUID, name: String, config: CharacterConfig) {
        self.id = id; self.name = name; self.config = config
    }
}

// MARK: - MenuBarWalker

@MainActor
final class MenuBarWalker: ObservableObject {

    // ── Hangers ─────────────────────────────────────────────────────────────

    struct ActiveHanger: Identifiable {
        let id: UUID
        let character: any AnyHangingCharacter
        var config: HangingConfig
    }

    @Published var activeHangers: [UUID: ActiveHanger] = [:]
    private var hangingWindow: HangingOverlayWindow?
    private var clickMonitor: Any?

    func isHanging(characterID: UUID) -> Bool { activeHangers[characterID] != nil }

    func toggleHang(for character: HangingCharacter) {
        if activeHangers[character.id] != nil {
            activeHangers.removeValue(forKey: character.id)
            if activeHangers.isEmpty {
                hangingWindow?.orderOut(nil); hangingWindow = nil; stopClickMonitor()
            } else {
                updateHangingWindowFrame()
                hangingWindow?.updateMousePassthrough(walker: self)
            }
        } else {
            activeHangers[character.id] = ActiveHanger(
                id: character.id, character: character,
                config: loadHangingConfig(for: character))
            if hangingWindow == nil { hangingWindow = HangingOverlayWindow(walker: self) }
            updateHangingWindowFrame()
            hangingWindow?.updateMousePassthrough(walker: self)
            startClickMonitor()
        }
    }

    func toggleHangCustom(for character: CustomHangingCharacter) {
        if activeHangers[character.id] != nil {
            activeHangers.removeValue(forKey: character.id)
            if activeHangers.isEmpty {
                hangingWindow?.orderOut(nil); hangingWindow = nil; stopClickMonitor()
            } else {
                updateHangingWindowFrame()
                hangingWindow?.updateMousePassthrough(walker: self)
            }
        } else {
            let config: HangingConfig = character.initialConfig ?? {
                var cfg = HangingConfig.default
                cfg.size = character.initialConfig?.size ?? 120
                return cfg
            }()
            activeHangers[character.id] = ActiveHanger(
                id: character.id, character: character, config: config)
            if hangingWindow == nil { hangingWindow = HangingOverlayWindow(walker: self) }
            updateHangingWindowFrame()
            hangingWindow?.updateMousePassthrough(walker: self)
            startClickMonitor()
        }
    }

    func stopHanging(characterID: UUID) {
        activeHangers.removeValue(forKey: characterID)
        if activeHangers.isEmpty {
            hangingWindow?.orderOut(nil); hangingWindow = nil; stopClickMonitor()
        } else {
            updateHangingWindowFrame()
        }
    }

    func stopAllHangers() {
        activeHangers.removeAll()
        hangingWindow?.orderOut(nil); hangingWindow = nil; stopClickMonitor()
    }

    private func updateHangingWindowFrame() {
        guard let screen = NSScreen.main, let win = hangingWindow else { return }
        let f = screen.frame
        let h: CGFloat = activeHangers.values.contains { $0.config.extendedDrop } ? f.height : 300
        win.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: f.width, height: h), display: true)
        win.orderFrontRegardless()
    }

    private func loadHangingConfig(for character: HangingCharacter) -> HangingConfig {
        let key = "bloop_hang_\(character.name)"
        if let data = UserDefaults.standard.data(forKey: key),
           let cfg = try? JSONDecoder().decode(HangingConfig.self, from: data) { return cfg }
        var cfg = HangingConfig.default
        if let idx = HangingStore.all.firstIndex(where: { $0.id == character.id }) {
            cfg.horizontalPosition = CGFloat(100 + idx * 120)
        }
        return cfg
    }

    func saveHangingSettings(for characterID: UUID) {
        guard let h = activeHangers[characterID] else { return }
        if let data = try? JSONEncoder().encode(h.config) {
            UserDefaults.standard.set(data, forKey: "bloop_hang_\(h.character.name)")
        }
    }

    func hangingConfigBinding(for id: UUID) -> Binding<HangingConfig> {
        Binding(
            get: { self.activeHangers[id]?.config ?? .default },
            set: { [weak self] v in
                guard let self, self.activeHangers[id] != nil else { return }
                self.activeHangers[id]!.config = v
                self.updateHangingWindowFrame()
                self.hangingWindow?.updateMousePassthrough(walker: self)
            }
        )
    }

    // ── Walking characters ───────────────────────────────────────────────────

    // The animation engine owns all mutable frame state on its own actor
    private let engine = AnimationEngine()

    // @Published only for the sidebar config UI
    @Published var activeCharacters: [UUID: CharacterProxy] = [:]

    private var displayLink: CADisplayLink?
    private var frameSkipCounter: Int = 0
    private var overlayWindow: CharacterOverlayWindow?
    private weak var canvasView: CharacterCanvasView?

    func isWalking(characterID: UUID) -> Bool { activeCharacters[characterID] != nil }

    func toggleWalk(for character: Character, on screen: NSScreen) {
        if activeCharacters[character.id] != nil {
            activeCharacters.removeValue(forKey: character.id)
            let engine = self.engine
            Task { await engine.remove(id: character.id) }
            if activeCharacters.isEmpty { stopAll() } else { updateWalkWindowFrame() }
        } else {
            let frames   = character.loadFrames()
            guard !frames.isEmpty else { return }
            let cgFrames = frames.compactMap {
                $0.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
            guard !cgFrames.isEmpty else { return }

            let config = loadConfig(for: character)
            activeCharacters[character.id] = CharacterProxy(
                id: character.id, name: character.name, config: config)

            let startX = screen.frame.width + config.characterSize
            let ac = AnimationEngine.ActiveCharacter(
                id: character.id, character: character,
                cgFrames: cgFrames, positionX: startX, config: config)
            let engine = self.engine
            Task { await engine.add(ac) }

            if overlayWindow == nil {
                let canvas = CharacterCanvasView()
                canvasView    = canvas
                overlayWindow = CharacterOverlayWindow(canvas: canvas)
                updateWalkWindowFrame()
                startDisplayLink()
            } else {
                updateWalkWindowFrame()
            }
        }
    }

    func stopAll() {
        stopDisplayLink()
        activeCharacters.removeAll()
        let engine = self.engine
        Task { await engine.removeAll() }
        overlayWindow?.orderOut(nil); overlayWindow = nil; canvasView = nil
    }

    // MARK: Config & Settings

    private func loadConfig(for character: Character) -> CharacterConfig {
        let key = "bloop_settings_\(character.name)"
        if let data = UserDefaults.standard.data(forKey: key),
           let cfg = try? JSONDecoder().decode(CharacterConfig.self, from: data) { return cfg }
        return CharacterConfig(
            verticalOffset: 0, movementSpeed: character.walkSpeed,
            ticksPerFrame: character.ticksPerFrame,
            characterSize: character.frameSize.width, extendedVertical: false)
    }

    func saveSettings(for characterID: UUID) {
        guard let proxy = activeCharacters[characterID] else { return }
        if let data = try? JSONEncoder().encode(proxy.config) {
            UserDefaults.standard.set(data, forKey: "bloop_settings_\(proxy.name)")
        }
    }

    func configBinding(for id: UUID) -> Binding<CharacterConfig> {
        Binding(
            get: {
                self.activeCharacters[id]?.config ?? CharacterConfig(
                    verticalOffset: 0, movementSpeed: 1, ticksPerFrame: 5,
                    characterSize: 36, extendedVertical: false)
            },
            set: { [weak self] newVal in
                guard let self, self.activeCharacters[id] != nil else { return }
                self.activeCharacters[id]!.config = newVal
                let engine = self.engine
                Task { await engine.updateConfig(newVal, for: id) }
                self.updateWalkWindowFrame()
            }
        )
    }

    // MARK: Display link (~30 fps)

    private func startDisplayLink() {
        guard displayLink == nil, let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(displayLinkFired))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate(); displayLink = nil; frameSkipCounter = 0
    }

    @objc private func displayLinkFired() {
        frameSkipCounter &+= 1
        guard frameSkipCounter % 2 == 0 else { return }

        guard let canvas = canvasView else { return }
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let engine = self.engine

        // Ask the engine (its own actor) to tick and return a render snapshot.
        // The snapshot is [RenderItem] which is Sendable, so crossing actor
        // boundaries is safe. Then hand it to the canvas on the main thread.
        Task { @MainActor [weak self, weak canvas] in
            guard self != nil, let canvas else { return }
            let items = await engine.tick(screenWidth: screenWidth)
            canvas.renderItems = items
            canvas.setNeedsDisplay(canvas.bounds)
        }
    }

    // MARK: Window frame

    private func updateWalkWindowFrame() {
        guard let screen = NSScreen.main, let win = overlayWindow else { return }
        let f = screen.frame
        let needsExtended = activeCharacters.values.contains { $0.config.extendedVertical }
        let h: CGFloat = needsExtended ? f.height : 150
        win.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: f.width, height: h), display: true)
        win.orderFrontRegardless()
    }

    // MARK: Click monitor

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in self.handleGlobalClick(event: event) }
        }
    }

    private func stopClickMonitor() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func handleGlobalClick(event: NSEvent) {
        guard let screen = NSScreen.main else { return }
        let pt = event.locationInWindow
        for h in activeHangers.values {
            guard h.config.isInteractive, h.config.link != .none else { continue }
            let windowH: CGFloat = h.config.extendedDrop ? screen.frame.height : 300
            let windowBottom = screen.frame.maxY - windowH
            let charY = windowBottom + windowH - (h.config.size / 2 + h.config.verticalOffset)
            let half  = h.config.size / 2
            let rect  = CGRect(x: h.config.horizontalPosition - half, y: charY - half,
                               width: h.config.size, height: h.config.size)
            if rect.contains(pt) { h.config.link.trigger(); return }
        }
    }
}

// MARK: - CharacterCanvasView
// Plain NSView. Receives [RenderItem] each frame and draws via CGContext.
// No SwiftUI, no layer diffing, no per-frame allocations beyond the snapshot array.

final class CharacterCanvasView: NSView {

    var renderItems: [RenderItem] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        // NSGraphicsContext wraps CGContext; set interpolation via NSGraphicsContext
        NSGraphicsContext.current?.imageInterpolation = .none

        let items = renderItems
        for item in items {
            let half = item.size / 2
            // NSView Y=0 is bottom; our y is distance from window top, so invert
            let rect = CGRect(
                x: item.x - half,
                y: bounds.height - item.y - half,
                width:  item.size,
                height: item.size
            )
            ctx.saveGState()
            if item.flipped {
                ctx.translateBy(x: rect.midX, y: rect.midY)
                ctx.scaleBy(x: -1, y: 1)
                ctx.translateBy(x: -rect.midX, y: -rect.midY)
            }
            ctx.draw(item.cgImage, in: rect)
            ctx.restoreGState()
        }
    }
}

// MARK: - CharacterOverlayWindow

final class CharacterOverlayWindow: NSWindow {
    init(canvas: CharacterCanvasView) {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque             = false
        backgroundColor      = .clear
        level                = .statusBar
        collectionBehavior   = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents   = true
        hasShadow            = false
        isReleasedWhenClosed = false
        contentView          = canvas
    }
}
