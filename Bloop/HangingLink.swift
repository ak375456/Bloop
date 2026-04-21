//
//  HangingLink.swift
//  Bloop
//

import AppKit

enum HangingLink: Codable, Equatable {
    case none
    case app(bundleID: String, name: String)
    case url(String)
    case shortcut(String)

    enum CodingKeys: String, CodingKey {
        case type, value, name
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode("none", forKey: .type)
        case .app(let bundleID, let name):
            try c.encode("app",   forKey: .type)
            try c.encode(bundleID, forKey: .value)
            try c.encode(name,    forKey: .name)
        case .url(let str):
            try c.encode("url",  forKey: .type)
            try c.encode(str,    forKey: .value)
        case .shortcut(let name):
            try c.encode("shortcut", forKey: .type)
            try c.encode(name,       forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "app":
            let id   = try c.decode(String.self, forKey: .value)
            let name = try c.decode(String.self, forKey: .name)
            self = .app(bundleID: id, name: name)
        case "url":
            self = .url(try c.decode(String.self, forKey: .value))
        case "shortcut":
            self = .shortcut(try c.decode(String.self, forKey: .value))
        default:
            self = .none
        }
    }

    var displayName: String {
        switch self {
        case .none:              return "None"
        case .app(_, let name):  return name
        case .url(let str):      return str
        case .shortcut(let n):   return "⌘ \(n)"
        }
    }

    var icon: String {
        switch self {
        case .none:     return "slash.circle"
        case .app:      return "square.grid.2x2"
        case .url:      return "globe"
        case .shortcut: return "bolt.fill"
        }
    }

    func trigger() {
        switch self {
        case .none:
            break
        case .app(let bundleID, _):
            NSWorkspace.shared.open(
                URL(fileURLWithPath: NSWorkspace.shared
                    .urlForApplication(withBundleIdentifier: bundleID)?.path ?? "")
            )
        case .url(let str):
            if let url = URL(string: str) { NSWorkspace.shared.open(url) }
        case .shortcut(let name):
            let escaped = name.replacingOccurrences(of: " ", with: "%20")
            if let url = URL(string: "shortcuts://run-shortcut?name=\(escaped)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: NSImage?

    @MainActor
    static func fetchAll() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let ws = NSWorkspace.shared
        for url in ws.urlsForApplications(toOpen: URL(string: "file://")!) {
            guard let bundle = Bundle(url: url),
                  let bid    = bundle.bundleIdentifier else { continue }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
            apps.append(InstalledApp(id: bid, name: name, icon: ws.icon(forFile: url.path)))
        }
        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
