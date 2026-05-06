//
//  ContentView.swift
//  Bloop
//

import SwiftUI

struct ContentView: View {
    @State private var selectedHangerID: UUID? = nil
    @EnvironmentObject var walker: MenuBarWalker
    @State private var selectedID: UUID? = nil
    @State private var showSettings = false
    @State private var activeTab: Tab = .walkers
    @State private var showCreateHanger = false
    @StateObject private var customStore = CustomCharacterStore.shared
    @StateObject private var store = StoreKitManager.shared

    enum Tab { case walkers, hangers }

    let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    var body: some View {
        NavigationSplitView {
            Group {
                if activeTab == .walkers {
                    SidebarView(selectedID: selectedID)
                        .navigationTitle("Controls")
                } else {
                    HangerSidebarView(selectedID: selectedHangerID)
                        .navigationTitle("Controls")
                        .environmentObject(walker)
                }
            }
        } detail: {
            VStack(spacing: 0) {
                Picker("", selection: $activeTab) {
                    Text("Walkers").tag(Tab.walkers)
                    Text("Hangers").tag(Tab.hangers)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if activeTab == .walkers {
                    WalkersTabView(
                        selectedID: $selectedID,
                        storeKit: store
                    )
                } else {
                    HangersTabView(
                        selectedHangerID: $selectedHangerID,
                        showCreateHanger: $showCreateHanger,
                        customStore: customStore,
                        storeKit: store
                    )
                    .environmentObject(walker)
                }
            }
            .navigationTitle(activeTab == .walkers ? "Bloop" : "Hangers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if activeTab == .walkers && !walker.activeCharacters.isEmpty {
                        Button { walker.stopAll(); selectedID = nil }
                        label: { Label("Stop All", systemImage: "stop.fill").foregroundColor(.red) }
                    } else if activeTab == .hangers && !walker.activeHangers.isEmpty {
                        Button { walker.stopAllHangers(); selectedHangerID = nil }
                        label: { Label("Remove All", systemImage: "stop.fill").foregroundColor(.red) }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button { showSettings = true }
                    label: { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 450)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Walkers Tab

private struct WalkersTabView: View {
    @EnvironmentObject var walker: MenuBarWalker
    @Binding var selectedID: UUID?
    @ObservedObject var storeKit: StoreKitManager

    @State private var showPaywall = false

    let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(CharacterStore.all) { character in
                    let isLocked = character.isPro && !storeKit.isProUnlocked
                    let isWalking = walker.isWalking(characterID: character.id)

                    CharacterCard(
                        character: character,
                        isSelected: selectedID == character.id,
                        isWalking: isWalking,
                        isLocked: isLocked
                    ) {
                        if isLocked {
                            showPaywall = true
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                selectedID = selectedID == character.id ? nil : character.id
                            }
                        }
                    } onPlay: {
                        if isLocked {
                            showPaywall = true
                        } else {
                            if let screen = NSScreen.main {
                                walker.toggleWalk(for: character, on: screen)
                                if walker.isWalking(characterID: character.id) {
                                    withAnimation { selectedID = character.id }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(storeKit: storeKit, onPurchased: {
                showPaywall = false
            })
        }
    }
}

// MARK: - Hangers Tab

private struct HangersTabView: View {
    @Binding var selectedHangerID: UUID?
    @Binding var showCreateHanger: Bool
    @ObservedObject var customStore: CustomCharacterStore
    @ObservedObject var storeKit: StoreKitManager
    @EnvironmentObject var walker: MenuBarWalker

    @State private var showPaywall = false

    let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                CreateHeroBanner(isPro: storeKit.isProUnlocked) {
                    if storeKit.isProUnlocked {
                        showCreateHanger = true
                    } else {
                        showPaywall = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

                if !customStore.characters.isEmpty {
                    SectionDivider(label: "My characters")
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(customStore.characters) { character in
                            let isHanging = walker.isHanging(characterID: character.id)
                            CustomHangerCard(
                                character: character,
                                isSelected: selectedHangerID == character.id,
                                isHanging: isHanging
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    selectedHangerID = selectedHangerID == character.id ? nil : character.id
                                }
                            } onPlay: {
                                walker.toggleHangCustom(for: character)
                                if walker.isHanging(characterID: character.id) {
                                    withAnimation { selectedHangerID = character.id }
                                }
                            } onDelete: {
                                walker.stopHanging(characterID: character.id)
                                customStore.delete(character)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }

                if !HangingStore.all.isEmpty {
                    SectionDivider(label: "Built-in characters")
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(HangingStore.all) { character in
                            let isLocked = character.isPro && !storeKit.isProUnlocked
                            let isHanging = walker.isHanging(characterID: character.id)
                            HangerCard(
                                character: character,
                                isSelected: selectedHangerID == character.id,
                                isHanging: isHanging,
                                isLocked: isLocked
                            ) {
                                if isLocked {
                                    showPaywall = true
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                        selectedHangerID = selectedHangerID == character.id ? nil : character.id
                                    }
                                }
                            } onPlay: {
                                if isLocked {
                                    showPaywall = true
                                } else {
                                    walker.toggleHang(for: character)
                                    if walker.isHanging(characterID: character.id) {
                                        withAnimation { selectedHangerID = character.id }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showCreateHanger) {
            CreateHangerView(store: customStore)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(storeKit: storeKit, onPurchased: {
                showPaywall = false
                showCreateHanger = false
            })
        }
    }
}

// MARK: - Hero Create Banner

private struct CreateHeroBanner: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 40)
                    Image(systemName: isPro ? "plus.circle.fill" : "lock.fill")
                        .font(.system(size: isPro ? 20 : 16))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Create your own hanger")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        if !isPro {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    Text(isPro
                         ? "Upload any image — it hangs from the menu bar"
                         : "Unlock to upload any image as a hanging character")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Divider

private struct SectionDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.secondary.opacity(0.3))
        }
    }
}

// MARK: - Sidebar View

private struct SidebarView: View {
    @EnvironmentObject var walker: MenuBarWalker
    let selectedID: UUID?

    var body: some View {
        let isActive = selectedID != nil && walker.isWalking(characterID: selectedID!)

        Form {
            if let id = selectedID, isActive {
                SidebarControlsView(characterID: id)
            } else {
                VStack {
                    Spacer()
                    Text("Select a walking character to edit its settings.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding()
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 240)
    }
}

// MARK: - Sidebar Controls View

private struct SidebarControlsView: View {
    @EnvironmentObject var walker: MenuBarWalker
    let characterID: UUID

    @State private var showSaved = false
    @State private var showNudge = false
    @State private var config: CharacterConfig = CharacterConfig(
        verticalOffset: 0, movementSpeed: 1, ticksPerFrame: 5,
        characterSize: 36, extendedVertical: false)

    var body: some View {
        Section {
            Toggle(isOn: $config.extendedVertical) {
                Text("Extended Drop").font(.caption)
            }
            .padding(.vertical, 4)
            .help("Allows the character to move all the way down to the bottom of the screen.")

            VStack(alignment: .leading) {
                Text("Vertical Position")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(value: $config.verticalOffset,
                       in: -10...maxVerticalOffset(extended: config.extendedVertical))
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading) {
                Text("Movement Speed: \(String(format: "%.1f", config.movementSpeed)) px/f")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(value: $config.movementSpeed, in: 0.1...10.0)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading) {
                Text("Character Size: \(Int(config.characterSize))")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(value: $config.characterSize, in: 16...120)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Animation Speed")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    AnimChip(title: "50ms",  targetTicks: 3, currentTicks: $config.ticksPerFrame)
                    AnimChip(title: "80ms",  targetTicks: 5, currentTicks: $config.ticksPerFrame)
                    AnimChip(title: "100ms", targetTicks: 6, currentTicks: $config.ticksPerFrame)
                    AnimChip(title: "140ms", targetTicks: 8, currentTicks: $config.ticksPerFrame)
                }
            }
            .padding(.vertical, 4)

        } header: { Text("Live Controls") }

        Section {
            Toggle(isOn: $showNudge) {
                Text("Nudge Position").font(.caption)
            }
            .padding(.vertical, 4)

            if showNudge {
                VStack(spacing: 8) {
                    Text("Vertical")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        Button {
                            config.verticalOffset = max(-10, config.verticalOffset - 1)
                        } label: {
                            Image(systemName: "arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.regular)

                        Text("\(Int(config.verticalOffset)) px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary).frame(minWidth: 50)

                        Button {
                            config.verticalOffset = min(
                                maxVerticalOffset(extended: config.extendedVertical),
                                config.verticalOffset + 1)
                        } label: {
                            Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.regular)
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } header: { Text("Nudge") }

        Section {
            Button {
                walker.saveSettings(for: characterID)
                withAnimation { showSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showSaved = false }
                }
            } label: {
                Label(showSaved ? "Saved!" : "Save Settings",
                      systemImage: showSaved ? "checkmark" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(showSaved ? .green : .accentColor)
            .controlSize(.regular)
        }
        .onAppear {
            if let proxy = walker.activeCharacters[characterID] {
                config = proxy.config
            }
        }
        .onChange(of: config.extendedVertical) { pushConfig() }
        .onChange(of: config.verticalOffset)   { pushConfig() }
        .onChange(of: config.movementSpeed)    { pushConfig() }
        .onChange(of: config.characterSize)    { pushConfig() }
        .onChange(of: config.ticksPerFrame)    { pushConfig() }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showNudge)
    }

    private func pushConfig() {
        guard walker.activeCharacters[characterID] != nil else { return }
        walker.activeCharacters[characterID]!.config = config
        let engine = walker.engine
        Task { await engine.updateConfig(config, for: characterID) }
        walker.updateWalkWindowFramePublic()
    }

    func maxVerticalOffset(extended: Bool) -> CGFloat {
        extended ? (NSScreen.main?.frame.height ?? 1200) - 50 : 100
    }
}

// MARK: - Animation Chip Button

private struct AnimChip: View {
    let title: String
    let targetTicks: Int
    @Binding var currentTicks: Int

    var isSelected: Bool { currentTicks == targetTicks }

    var body: some View {
        Button { currentTicks = targetTicks } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 4).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Character Card

private struct CharacterCard: View {
    let character: Character
    let isSelected: Bool
    let isWalking: Bool
    let isLocked: Bool
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6, y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    thumbnailView
                        .frame(height: 110).clipped()
                        .opacity(isLocked ? 0.45 : 1.0)

                    if isLocked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                            Text("PRO").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.accentColor).cornerRadius(6).padding(8)
                    }
                }

                Divider()

                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 8)

                if isSelected && !isLocked {
                    Button { onPlay() } label: {
                        Label(isWalking ? "Stop" : "Walk",
                              systemImage: isWalking ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isWalking ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if isLocked {
                    Button { onPlay() } label: {
                        Label("Unlock", systemImage: "lock.open.fill")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10).padding(.bottom, 12)
                }
            }
        }
        .offset(y: isSelected && !isLocked ? -10 : 0)
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = character.thumbnail {
            Image(nsImage: img).resizable().interpolation(.medium).scaledToFit().padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12))
                .overlay(Image(systemName: "figure.walk").font(.system(size: 36))
                    .foregroundStyle(Color.accentColor.opacity(0.5))).padding(16)
        }
    }
}

// MARK: - Hanger Card

private struct HangerCard: View {
    let character: HangingCharacter
    let isSelected: Bool
    let isHanging: Bool
    let isLocked: Bool
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6, y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    thumbnailView.frame(height: 110).clipped()
                        .opacity(isLocked ? 0.45 : 1.0)

                    if isLocked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                            Text("PRO").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.accentColor).cornerRadius(6).padding(8)
                    }
                }

                Divider()

                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 8)

                if isSelected && !isLocked {
                    Button { onPlay() } label: {
                        Label(isHanging ? "Remove" : "Hang",
                              systemImage: isHanging ? "stop.fill" : "pin.fill")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isHanging ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if isLocked {
                    Button { onPlay() } label: {
                        Label("Unlock", systemImage: "lock.open.fill")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10).padding(.bottom, 12)
                }
            }
        }
        .offset(y: isSelected && !isLocked ? -10 : 0)
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = character.thumbnail {
            Image(nsImage: img).resizable().interpolation(.medium).scaledToFit().padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12))
                .overlay(Image(systemName: "pin.fill").font(.system(size: 36))
                    .foregroundStyle(Color.accentColor.opacity(0.5))).padding(16)
        }
    }
}

// MARK: - Custom Hanger Card

private struct CustomHangerCard: View {
    let character: CustomHangingCharacter
    let isSelected: Bool
    let isHanging: Bool
    let onTap: () -> Void
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6, y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    thumbnailView.frame(height: 110).clipped()
                    Button { onDelete() } label: {
                        Image(systemName: "trash.fill").font(.system(size: 10))
                            .foregroundColor(.white).padding(5)
                            .background(Color.red.opacity(0.8)).clipShape(Circle())
                    }
                    .buttonStyle(.plain).padding(6)
                }
                Divider()
                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 8)
                if isSelected {
                    Button { onPlay() } label: {
                        Label(isHanging ? "Remove" : "Hang",
                              systemImage: isHanging ? "stop.fill" : "pin.fill")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isHanging ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .offset(y: isSelected ? -10 : 0)
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = character.thumbnail {
            Image(nsImage: img).resizable().interpolation(.medium).scaledToFit().padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12))
                .overlay(Image(systemName: "pin.fill").font(.system(size: 36))
                    .foregroundStyle(Color.accentColor.opacity(0.5))).padding(16)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MenuBarWalker())
}
