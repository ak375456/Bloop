//
//  SettingsView.swift
//  Bloop
//

import SwiftUI

// MARK: - App Appearance Enum
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Saves the theme preference globally using UserDefaults under the hood
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    
    // Automatically fetches the version number you set in Xcode's project settings
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            
            Divider()
            
            // ── Settings Form ──
            Form {
                // Appearance Section
                Section {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance")
                }
                
                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About MenuBar Pets")
                            .font(.headline)
                        Text("MenuBar Pets brings fun, animated and hanging characters directly to your macOS screen. Let them take a stroll while you work, adding a little bit of joy to your desktop experience.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                // Support & Legal Section
                Section {
                    // Feedback Email Link
                    Link(destination: URL(string: "mailto:ak375456@gmail.com?subject=MenuBar Pets%20Feedback")!) {
                        HStack {
                            Label("Send Feedback", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    // Privacy Policy Link (Placeholder URL)
                    Link(destination: URL(string: "https://ak375456.github.io/bloop-piracy/")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Support & Legal")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
        // Native frosted glass effect
        .background(.regularMaterial)
        // Applies the selected theme to this specific window
        .preferredColorScheme(colorScheme)
    }
    
    // Helper to convert the enum to SwiftUI's ColorScheme
    private var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#Preview {
    SettingsView()
}
