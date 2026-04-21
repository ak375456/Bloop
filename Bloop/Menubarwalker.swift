//
//  MenuBarWalker.swift
//  Bloop
//
//  Manages multiple walking characters and their individual settings,
//  drawing them all onto a single transparent overlay window.
//

import AppKit
import SwiftUI
import Combine

// The saved configuration for a character
struct CharacterConfig: Codable {
    var verticalOffset: CGFloat
    var movementSpeed: CGFloat
    var ticksPerFrame: Int
    var characterSize: CGFloat
    var extendedVertical: Bool
}

@MainActor
final class MenuBarWalker: ObservableObject {
    
    struct ActiveHanger: Identifiable {
        let id: UUID
        let character: any AnyHangingCharacter
        var config: HangingConfig
    }

    @Published var activeHangers: [UUID: ActiveHanger] = [:]
    private var hangingWindow: HangingOverlayWindow?
    private var clickMonitor: Any?

    func isHanging(characterID: UUID) -> Bool {
        activeHangers[characterID] != nil
    }

    func toggleHang(for character: HangingCharacter) {
        if activeHangers[character.id] != nil {
            activeHangers.removeValue(forKey: character.id)
            if activeHangers.isEmpty {
                hangingWindow?.orderOut(nil)
                hangingWindow = nil
                stopClickMonitor()
            } else {
                updateHangingWindowFrame()
                hangingWindow?.updateMousePassthrough(walker: self)

            }
        } else {
            let config = loadHangingConfig(for: character)
            let hanger = ActiveHanger(id: character.id, character: character, config: config)
            activeHangers[character.id] = hanger

            if hangingWindow == nil {
                hangingWindow = HangingOverlayWindow(walker: self)
            }
            updateHangingWindowFrame()
            hangingWindow?.updateMousePassthrough(walker: self)
            startClickMonitor()
        }
    }
    func toggleHangCustom(for character: CustomHangingCharacter) {
        if activeHangers[character.id] != nil {
            activeHangers.removeValue(forKey: character.id)
            if activeHangers.isEmpty {
                hangingWindow?.orderOut(nil)
                hangingWindow = nil
                stopClickMonitor()
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
            let hanger = ActiveHanger(id: character.id, character: character, config: config)
            activeHangers[character.id] = hanger

            if hangingWindow == nil {
                hangingWindow = HangingOverlayWindow(walker: self)
            }
            updateHangingWindowFrame()
            hangingWindow?.updateMousePassthrough(walker: self)
            startClickMonitor()
        }
    }

    func stopHanging(characterID: UUID) {
        activeHangers.removeValue(forKey: characterID)
        if activeHangers.isEmpty {
            hangingWindow?.orderOut(nil)
            hangingWindow = nil
            stopClickMonitor()
        } else {
            updateHangingWindowFrame()
        }
    }

    private func loadHangingConfigByName(name: String) -> HangingConfig {
        let key = "bloop_hang_\(name)"
        if let data = UserDefaults.standard.data(forKey: key),
           let config = try? JSONDecoder().decode(HangingConfig.self, from: data) {
            return config
        }
        return .default
    }

    func stopAllHangers() {
        activeHangers.removeAll()
        hangingWindow?.orderOut(nil)
        hangingWindow = nil
        stopClickMonitor() 
    }

    private func updateHangingWindowFrame() {
        guard let screen = NSScreen.main, let win = hangingWindow else { return }
        let f = screen.frame
        let needsExtended = activeHangers.values.contains { $0.config.extendedDrop }
        let windowH: CGFloat = needsExtended ? f.height : 300
        win.setFrame(NSRect(x: f.minX, y: f.maxY - windowH, width: f.width, height: windowH), display: true)
        win.orderFrontRegardless()
    }

    private func loadHangingConfig(for character: HangingCharacter) -> HangingConfig {
        let key = "bloop_hang_\(character.name)"
        if let data = UserDefaults.standard.data(forKey: key),
           let config = try? JSONDecoder().decode(HangingConfig.self, from: data) {
            return config
        }
        // Default horizontal position: spread evenly based on index
        var cfg = HangingConfig.default
        if let idx = HangingStore.all.firstIndex(where: { $0.id == character.id }) {
            cfg.horizontalPosition = CGFloat(100 + idx * 120)
        }
        return cfg
    }

    func saveHangingSettings(for characterID: UUID) {
        guard let hanger = activeHangers[characterID] else { return }
        let key = "bloop_hang_\(hanger.character.name)"
        if let data = try? JSONEncoder().encode(hanger.config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func hangingConfigBinding(for id: UUID) -> Binding<HangingConfig> {
        Binding(
            get: { self.activeHangers[id]?.config ?? .default },
            set: { newValue in
                if self.activeHangers[id] != nil {
                    self.activeHangers[id]!.config = newValue
                    self.updateHangingWindowFrame()
                    self.hangingWindow?.updateMousePassthrough(walker: self)
                }
            }
        )
    }

    // Represents a single character currently walking on screen
    struct ActiveCharacter: Identifiable {
        let id: UUID
        let character: Character
        var frames: [NSImage]
        var frameIndex: Int = 0
        var tickCount: Int = 0
        var positionX: CGFloat
        var facingRight: Bool = false
        var currentFrame: NSImage?
        var config: CharacterConfig
    }

    // Dictionary holding all currently walking characters
    @Published var activeCharacters: [UUID: ActiveCharacter] = [:]

    private var timer: Timer?
    private var overlayWindow: CharacterOverlayWindow?

    // MARK: - Public API
    
    /// Checks if a specific character is currently walking
    func isWalking(characterID: UUID) -> Bool {
        return activeCharacters[characterID] != nil
    }

    /// Toggles the walk state for a specific character
    func toggleWalk(for character: Character, on screen: NSScreen) {
        if activeCharacters[character.id] != nil {
            // Stop this specific character
            activeCharacters.removeValue(forKey: character.id)
            if activeCharacters.isEmpty {
                stopAll()
            } else {
                updateWindowFrame()
            }
        } else {
            // Start this character
            let frames = character.loadFrames()
            guard !frames.isEmpty else { return }
            
            let config = loadConfig(for: character)
            let newActive = ActiveCharacter(
                id: character.id,
                character: character,
                frames: frames,
                positionX: screen.frame.width + config.characterSize,
                currentFrame: frames[0],
                config: config
            )
            
            activeCharacters[character.id] = newActive
            
            // Boot up the window & timer if this is the first character
            if overlayWindow == nil {
                overlayWindow = CharacterOverlayWindow(walker: self)
                updateWindowFrame()
                
                timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.tick() }
                }
                RunLoop.main.add(timer!, forMode: .common)
            } else {
                updateWindowFrame()
            }
        }
    }

    /// Stops all characters globally
    func stopAll() {
        timer?.invalidate()
        timer = nil
        activeCharacters.removeAll()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    // MARK: - Config & Settings
    
    private func loadConfig(for character: Character) -> CharacterConfig {
        let key = "bloop_settings_\(character.name)"
        if let data = UserDefaults.standard.data(forKey: key),
           let config = try? JSONDecoder().decode(CharacterConfig.self, from: data) {
            return config
        }
        // Defaults if no save exists
        return CharacterConfig(
            verticalOffset: 0,
            movementSpeed: character.walkSpeed,
            ticksPerFrame: character.ticksPerFrame,
            characterSize: character.frameSize.width,
            extendedVertical: false
        )
    }

    func saveSettings(for characterID: UUID) {
        guard let active = activeCharacters[characterID] else { return }
        let key = "bloop_settings_\(active.character.name)"
        if let data = try? JSONEncoder().encode(active.config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Creates a direct binding for the Sidebar to edit a live character's settings safely
    func configBinding(for id: UUID) -> Binding<CharacterConfig> {
        Binding(
            get: {
                self.activeCharacters[id]?.config ?? CharacterConfig(verticalOffset: 0, movementSpeed: 1, ticksPerFrame: 5, characterSize: 36, extendedVertical: false)
            },
            set: { newValue in
                if self.activeCharacters[id] != nil {
                    self.activeCharacters[id]!.config = newValue
                    self.updateWindowFrame()
                }
            }
        )
    }

    // MARK: - Window & Tick Logic

    private func updateWindowFrame() {
        guard let screen = NSScreen.main, let win = overlayWindow else { return }
        let f = screen.frame
        // If *any* active character has extended vertical enabled, expand the window to full screen height
        let needsExtended = activeCharacters.values.contains { $0.config.extendedVertical }
        let windowH: CGFloat = needsExtended ? f.height : 150
        
        win.setFrame(NSRect(x: f.minX, y: f.maxY - windowH, width: f.width, height: windowH), display: true)
        win.orderFrontRegardless()
    }

    private func tick() {
        guard !activeCharacters.isEmpty else { return }
        
        // Loop through and update every active character
        for (id, var char) in activeCharacters {
            char.tickCount += 1
            
            // Advance frame
            if char.tickCount % max(1, char.config.ticksPerFrame) == 0 {
                char.frameIndex = (char.frameIndex + 1) % char.frames.count
                char.currentFrame = char.frames[char.frameIndex]
            }
            
            // Move
            let delta = char.facingRight ? char.config.movementSpeed : -char.config.movementSpeed
            char.positionX += delta
            
            // Wrap around screen
            if let screen = NSScreen.main {
                let w = screen.frame.width
                if char.positionX < -char.config.characterSize { char.positionX = w + char.config.characterSize }
                if char.positionX > w + char.config.characterSize { char.positionX = -char.config.characterSize }
            }
            
            // Save updated state back into dictionary
            activeCharacters[id] = char
        }
        
    }
    // Add this method:
    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.handleGlobalClick(event: event)
            }
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func handleGlobalClick(event: NSEvent) {
        // NSEvent.locationInWindow is in screen coords when there's no window
        // Convert from AppKit screen coordinates (origin bottom-left) to match our overlay
        guard let screen = NSScreen.main else { return }

        let screenPoint = event.locationInWindow  // global monitor gives screen coords directly
        
        for hanger in activeHangers.values {
            guard hanger.config.isInteractive, hanger.config.link != .none else { continue }

            // Character center in screen coordinates (AppKit: Y=0 at bottom)
            let charX = hanger.config.horizontalPosition
            // Our overlay window top = screen.frame.maxY - windowHeight
            // Character Y in overlay view = size/2 + verticalOffset from top of window
            let windowH: CGFloat = hanger.config.extendedDrop ? screen.frame.height : 300
            let windowBottom = screen.frame.maxY - windowH
            let charScreenY = windowBottom + windowH - (hanger.config.size / 2 + hanger.config.verticalOffset)

            let halfSize = hanger.config.size / 2
            let charRect = CGRect(
                x: charX - halfSize,
                y: charScreenY - halfSize,
                width: hanger.config.size,
                height: hanger.config.size
            )

            if charRect.contains(screenPoint) {
                hanger.config.link.trigger()
                return
            }
        }
    }
    
}

// MARK: - Overlay Window & View

final class CharacterOverlayWindow: NSWindow {
    init(walker: MenuBarWalker) {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: OverlayView(walker: walker))
    }
    
}

private struct OverlayView: View {
    @ObservedObject var walker: MenuBarWalker

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Render every active character based on its own specific state and settings
                ForEach(Array(walker.activeCharacters.values)) { char in
                    if let img = char.currentFrame {
                        Image(nsImage: img)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: char.config.characterSize, height: char.config.characterSize)
                            .scaleEffect(x: char.facingRight ? 1 : -1, y: 1)
                            .position(x: char.positionX, y: 16 + char.config.verticalOffset)
                    }
                }
            }
        }
    }
}

