//
//  BloopApp.swift
//  Bloop
//

import SwiftUI

@main
struct BloopApp: App {

    @StateObject private var walker = MenuBarWalker()
    
    // Read the globally saved theme preference
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(walker)
                // Apply the selected color scheme to the entire app window
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 420, height: 360)
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
