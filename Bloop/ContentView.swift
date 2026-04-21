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
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(CharacterStore.all) { character in
                                let isWalking = walker.isWalking(characterID: character.id)
                                CharacterCard(
                                    character: character,
                                    isSelected: selectedID == character.id,
                                    isWalking: isWalking
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                        selectedID = selectedID == character.id ? nil : character.id
                                    }
                                } onPlay: {
                                    if let screen = NSScreen.main {
                                        walker.toggleWalk(for: character, on: screen)
                                        if walker.isWalking(characterID: character.id) {
                                            withAnimation { selectedID = character.id }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !HangingStore.all.isEmpty {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(HangingStore.all) { character in
                                        let isHanging = walker.isHanging(characterID: character.id)
                                        HangerCard(
                                            character: character,
                                            isSelected: selectedHangerID == character.id,
                                            isHanging: isHanging
                                        ) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                                selectedHangerID = selectedHangerID == character.id ? nil : character.id
                                            }
                                        } onPlay: {
                                            walker.toggleHang(for: character)
                                            if walker.isHanging(characterID: character.id) {
                                                withAnimation { selectedHangerID = character.id }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            }

                            if !customStore.characters.isEmpty {
                                if !HangingStore.all.isEmpty {
                                    HStack {
                                        Text("Custom")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        VStack { Divider() }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                                }

                                LazyVGrid(columns: columns, spacing: 20) {
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
                                .padding(.top, HangingStore.all.isEmpty ? 24 : 0)
                            }

                            if HangingStore.all.isEmpty && customStore.characters.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer(minLength: 40)
                                    Image(systemName: "figure.arms.open")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text("No hangers yet")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Button {
                                        showCreateHanger = true
                                    } label: {
                                        Label("Create Custom Character", systemImage: "plus.circle.fill")
                                            .frame(minWidth: 200)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Button {
                                    showCreateHanger = true
                                } label: {
                                    Label("Create Custom Character", systemImage: "plus.circle.fill")
                                        .frame(minWidth: 200)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .padding(.top, 20)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    .sheet(isPresented: $showCreateHanger) {
                        CreateHangerView(store: customStore)
                    }
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

// MARK: - Sidebar Settings View

private struct SidebarView: View {
    @EnvironmentObject var walker: MenuBarWalker
    let selectedID: UUID?

    @State private var showSaved = false
    @State private var showNudge = false

    var body: some View {
        let isActive = selectedID != nil && walker.isWalking(characterID: selectedID!)

        Form {
            if let id = selectedID, isActive {
                let config = walker.configBinding(for: id)

                Section {
                    Toggle(isOn: config.extendedVertical) {
                        Text("Extended Drop")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .help("Allows the character to move all the way down to the bottom of the screen.")

                    VStack(alignment: .leading) {
                        Text("Vertical Position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: config.verticalOffset, in: -10...maxVerticalOffset(extended: config.extendedVertical.wrappedValue))
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Movement Speed: \(String(format: "%.1f", config.movementSpeed.wrappedValue)) px/f")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: config.movementSpeed, in: 0.1...10.0)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Character Size: \(Int(config.characterSize.wrappedValue))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: config.characterSize, in: 16...120)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Animation Speed")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            AnimChip(title: "50ms", targetTicks: 3, currentTicks: config.ticksPerFrame)
                            AnimChip(title: "80ms", targetTicks: 5, currentTicks: config.ticksPerFrame)
                            AnimChip(title: "100ms", targetTicks: 6, currentTicks: config.ticksPerFrame)
                            AnimChip(title: "140ms", targetTicks: 8, currentTicks: config.ticksPerFrame)
                        }
                    }
                    .padding(.vertical, 4)

                } header: {
                    Text("Live Controls")
                }

                Section {
                    Toggle(isOn: $showNudge) {
                        Text("Nudge Position")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)

                    if showNudge {
                        VStack(spacing: 8) {
                            Text("Vertical")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                Button {
                                    config.verticalOffset.wrappedValue = max(
                                        -10,
                                        config.verticalOffset.wrappedValue - 1
                                    )
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)

                                Text("\(Int(config.verticalOffset.wrappedValue)) px")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 50)

                                Button {
                                    config.verticalOffset.wrappedValue = min(
                                        maxVerticalOffset(extended: config.extendedVertical.wrappedValue),
                                        config.verticalOffset.wrappedValue + 1
                                    )
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    Text("Nudge")
                }

                Section {
                    Button {
                        walker.saveSettings(for: id)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showNudge)
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
        Button {
            currentTicks = targetTicks
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
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
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6,
                        y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                thumbnailView
                    .frame(height: 110)
                    .clipped()

                Divider()

                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                if isSelected {
                    Button { onPlay() } label: {
                        Label(isWalking ? "Stop" : "Walk",
                              systemImage: isWalking ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isWalking ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
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
            Image(nsImage: img)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor.opacity(0.5))
                )
                .padding(16)
        }
    }
}

// MARK: - Hanger Card

private struct HangerCard: View {
    let character: HangingCharacter
    let isSelected: Bool
    let isHanging: Bool
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6, y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                thumbnailView
                    .frame(height: 110)
                    .clipped()

                Divider()

                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                if isSelected {
                    Button { onPlay() } label: {
                        Label(isHanging ? "Remove" : "Hang",
                              systemImage: isHanging ? "stop.fill" : "pin.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isHanging ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
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
            Image(nsImage: img)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    Image(systemName: "pin.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor.opacity(0.5))
                )
                .padding(16)
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
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.07),
                        radius: isSelected ? 16 : 6, y: isSelected ? 8 : 2)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    thumbnailView.frame(height: 110).clipped()

                    Button { onDelete() } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }

                Divider()

                Text(character.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                if isSelected {
                    Button { onPlay() } label: {
                        Label(isHanging ? "Remove" : "Hang",
                              systemImage: isHanging ? "stop.fill" : "pin.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isHanging ? .red : .accentColor)
                    .controlSize(.regular)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
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
            Image(nsImage: img)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .padding(16)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    Image(systemName: "pin.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor.opacity(0.5))
                )
                .padding(16)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MenuBarWalker())
}
