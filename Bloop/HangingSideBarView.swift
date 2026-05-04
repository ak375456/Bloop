//
//  HangerSidebarView.swift
//  Bloop
//

import SwiftUI
import AppKit

struct HangerSidebarView: View {
    @EnvironmentObject var walker: MenuBarWalker
    let selectedID: UUID?

    @State private var showSaved = false
    @State private var showNudge = false

    var body: some View {
        let isActive = selectedID != nil && walker.isHanging(characterID: selectedID!)

        Form {
            if let id = selectedID, isActive {
                let config = walker.hangingConfigBinding(for: id)

                // ── Position & Display ──────────────────────────
                Section {
                    Toggle(isOn: config.extendedDrop) {
                        Text("Extended Drop").font(.caption)
                    }
                    .padding(.vertical, 4)
                    .help("Allow the character to hang further down the screen.")

                    Toggle(isOn: config.isFlipped) {
                        Text("Flip Horizontally").font(.caption)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Horizontal Position: \(Int(config.horizontalPosition.wrappedValue))")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: config.horizontalPosition,
                               in: 0...(NSScreen.main?.frame.width ?? 1440))
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Vertical Drop: \(Int(config.verticalOffset.wrappedValue))")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: config.verticalOffset,
                               in: 0...maxDrop(extended: config.extendedDrop.wrappedValue))
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Rotation: \(Int(config.rotationAngle.wrappedValue))")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: config.rotationAngle, in: -180...180)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("Size: \(Int(config.size.wrappedValue))")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: config.size, in: 20...400)
                    }
                    .padding(.vertical, 4)

                } header: {
                    Text("Position & Display")
                }

                // ── Rope ────────────────────────────────────────
                Section {
                    let ropeEnabledBinding = Binding<Bool>(
                        get: { config.wrappedValue.rope != nil },
                        set: { enabled in
                            var c = config.wrappedValue
                            c.rope = enabled ? (c.rope ?? RopeConfig.default) : nil
                            config.wrappedValue = c
                        }
                    )

                    Toggle(isOn: ropeEnabledBinding) {
                        Text("Show Rope").font(.caption)
                    }
                    .padding(.vertical, 4)

                    if config.wrappedValue.rope != nil {

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Style")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 5) {
                                ForEach(1...6, id: \.self) { idx in
                                    Button {
                                        var c = config.wrappedValue
                                        c.rope?.styleIndex = idx
                                        config.wrappedValue = c
                                    } label: {
                                        Group {
                                            if let img = NSImage(named: String(format: "rope_%02d", idx)) {
                                                Image(nsImage: img)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(3)
                                            } else {
                                                Image(systemName: "line.diagonal")
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        .frame(width: 28, height: 28)
                                        .background(
                                            (config.wrappedValue.rope?.styleIndex ?? 1) == idx
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.gray.opacity(0.1)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .strokeBorder(
                                                    (config.wrappedValue.rope?.styleIndex ?? 1) == idx
                                                        ? Color.accentColor : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rope Size: \(Int(config.wrappedValue.rope?.size ?? 40))")
                                .font(.caption).foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { config.wrappedValue.rope?.size ?? 40 },
                                    set: { v in
                                        var c = config.wrappedValue
                                        c.rope?.size = v
                                        config.wrappedValue = c
                                    }
                                ),
                                in: 10...200
                            )
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rope Vertical: \(Int(config.wrappedValue.rope?.verticalOffset ?? 0))px")
                                .font(.caption).foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { config.wrappedValue.rope?.verticalOffset ?? 0 },
                                    set: { v in
                                        var c = config.wrappedValue
                                        c.rope?.verticalOffset = v
                                        config.wrappedValue = c
                                    }
                                ),
                                in: 0...200
                            )
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rope Horizontal: \(Int(config.wrappedValue.rope?.horizontalOffset ?? 0))px")
                                .font(.caption).foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { config.wrappedValue.rope?.horizontalOffset ?? 0 },
                                    set: { v in
                                        var c = config.wrappedValue
                                        c.rope?.horizontalOffset = v
                                        config.wrappedValue = c
                                    }
                                ),
                                in: -100...100
                            )
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Rope")
                }

                // ── On Click ────────────────────────────────────
                Section {
                    Toggle(isOn: config.isInteractive) {
                        Text("Enable Click").font(.caption)
                    }
                    .padding(.vertical, 4)
                    .help("Makes the character clickable on screen.")

                    if config.isInteractive.wrappedValue {
                        LinkPickerView(link: config.link)
                            .padding(.vertical, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    Text("On Click")
                }

                // ── Nudge ───────────────────────────────────────
                Section {
                    Toggle(isOn: $showNudge) {
                        Text("Nudge Position").font(.caption)
                    }
                    .padding(.vertical, 4)

                    if showNudge {
                        VStack(spacing: 12) {
                            nudgeAxis(
                                label: "Vertical",
                                upIcon: "arrow.up", downIcon: "arrow.down",
                                value: config.verticalOffset,
                                min: 0,
                                max: maxDrop(extended: config.extendedDrop.wrappedValue)
                            )
                            nudgeAxis(
                                label: "Horizontal",
                                upIcon: "arrow.left", downIcon: "arrow.right",
                                value: config.horizontalPosition,
                                min: 0,
                                max: NSScreen.main?.frame.width ?? 1440
                            )
                        }
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    Text("Nudge")
                }

                // ── Save ────────────────────────────────────────
                Section {
                    Button {
                        walker.saveHangingSettings(for: id)
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
                    Text("Select a hanging character to edit its position and size.")
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

    private func maxDrop(extended: Bool) -> CGFloat {
        extended ? (NSScreen.main?.frame.height ?? 1200) - 50 : 300
    }

    @ViewBuilder
    private func nudgeAxis(
        label: String,
        upIcon: String,
        downIcon: String,
        value: Binding<CGFloat>,
        min minVal: CGFloat,
        max maxVal: CGFloat
    ) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button {
                    value.wrappedValue = Swift.max(minVal, value.wrappedValue - 1)
                } label: {
                    Image(systemName: upIcon).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.regular)

                Text("\(Int(value.wrappedValue)) px")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 50)

                Button {
                    value.wrappedValue = Swift.min(maxVal, value.wrappedValue + 1)
                } label: {
                    Image(systemName: downIcon).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.regular)
            }
        }
    }
}

// MARK: - Link Picker

private struct LinkPickerView: View {
    @Binding var link: HangingLink

    @State private var mode: Mode = .none
    @State private var urlText: String = ""
    @State private var shortcutText: String = ""
    @State private var apps: [InstalledApp] = []
    @State private var appSearch: String = ""
    @State private var loadingApps = false

    enum Mode: String, CaseIterable {
        case none = "None"
        case app = "App"
        case url = "URL"
        case shortcut = "Shortcut"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Mode selector ────────────────────────────────────────
            HStack(spacing: 6) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        mode = m
                        if m == .app && apps.isEmpty { loadApps() }
                        if m == .none { link = .none }
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(mode == m ? Color.accentColor : Color.gray.opacity(0.15))
                            .foregroundColor(mode == m ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Mode content ─────────────────────────────────────────
            switch mode {
            case .none:
                EmptyView()

            case .app:
                appPickerContent

            case .url:
                TextField("https://example.com", text: $urlText)
                    .textFieldStyle(.roundedBorder).font(.caption)
                    .onSubmit { link = .url(urlText) }
                Button("Set URL") { link = .url(urlText) }
                    .font(.caption).disabled(urlText.isEmpty)

            case .shortcut:
                TextField("Shortcut name", text: $shortcutText)
                    .textFieldStyle(.roundedBorder).font(.caption)
                    .onSubmit { link = .shortcut(shortcutText) }
                Button("Set Shortcut") { link = .shortcut(shortcutText) }
                    .font(.caption).disabled(shortcutText.isEmpty)
                Text("Must match the exact name in the Shortcuts app.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // ── Current link badge ───────────────────────────────────
            if link != .none {
                HStack(spacing: 6) {
                    Image(systemName: link.icon).font(.caption2)
                    Text(link.displayName).font(.caption).lineLimit(1)
                    Spacer()
                    Button {
                        link = .none; mode = .none
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .onAppear { syncModeFromLink() }
    }

    // MARK: - App picker UI

    @ViewBuilder
    private var appPickerContent: some View {
        if loadingApps {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Loading apps…").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

        } else if apps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No apps found.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Retry") { loadApps() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }

        } else {
            // Search bar — .plain style so SwiftUI Form chrome never swallows key events
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Search apps…", text: $appSearch)
                    .font(.caption)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !appSearch.isEmpty {
                    Button { appSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.gray.opacity(0.25), lineWidth: 0.5)
            )

            // Results list
            let results = filteredApps
            if results.isEmpty {
                Text("No apps match \"\(appSearch)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(results) { app in
                            appRow(app)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }

    @ViewBuilder
    private func appRow(_ app: InstalledApp) -> some View {
        let isSelected: Bool = {
            if case .app(let bid, _) = link { return bid == app.id }
            return false
        }()

        Button {
            link = .app(bundleID: app.id, name: app.name)
        } label: {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }

                Text(app.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private var filteredApps: [InstalledApp] {
        let query = appSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        let words = query.lowercased().split(separator: " ").map(String.init)
        return apps.filter { app in
            let name = app.name.lowercased()
            return words.allSatisfy { name.contains($0) }
        }
    }

    // MARK: - App loading

    private func loadApps() {
        guard !loadingApps else { return }
        loadingApps = true
        Task.detached(priority: .userInitiated) {
            let fetched = Self.scanInstalledApps()
            await MainActor.run {
                self.apps = fetched
                self.loadingApps = false
            }
        }
    }

    /// Scans all standard macOS app locations directly.
    /// Bypasses InstalledApp.fetchAll() entirely — runs on a background thread.
    private static func scanInstalledApps() -> [InstalledApp] {
        let fm = FileManager.default
        let ws = NSWorkspace.shared

        var searchDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
        ]
        // Add ~/Applications if it exists
        if let userApps = fm.urls(for: .applicationDirectory,
                                   in: .userDomainMask).first {
            searchDirs.append(userApps)
        }

        var seen   = Set<String>()
        var result = [InstalledApp]()

        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for url in entries where url.pathExtension == "app" {
                guard let bundle   = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.isEmpty,
                      !seen.contains(bundleID)
                else { continue }

                seen.insert(bundleID)

                // Pick the best available display name.
                // NSWorkspace on macOS has no localizedDescription(forApplicationAt:) —
                // that is iOS-only. Use CFBundle keys directly instead.
                let displayName  = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                let bundleName   = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                let name: String = (displayName?.nilIfEmpty)
                    ?? (bundleName?.nilIfEmpty)
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = ws.icon(forFile: url.path)
                result.append(InstalledApp(id: bundleID, name: name, icon: icon))
            }
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Sync mode from existing link value

    private func syncModeFromLink() {
        switch link {
        case .none:            mode = .none
        case .app:             mode = .app;      loadApps()
        case .url(let s):      mode = .url;      urlText = s
        case .shortcut(let s): mode = .shortcut; shortcutText = s
        }
    }
}

// MARK: - String helper

private extension String {
    /// Returns nil when the string is empty, self otherwise.
    /// Lets us chain optional name lookups with ?? cleanly.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
