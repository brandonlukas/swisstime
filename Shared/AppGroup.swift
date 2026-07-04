import Foundation

/// The one place both processes agree on where the data lives. Widgets run
/// in their own process and can't see the app's Documents, so the stores
/// write into the shared App Group container instead.
enum AppGroup {
    static let id = "group.com.brandonlukas.swisstime"

    /// The shared container, or the app's Documents when the group is
    /// unavailable (missing provisioning) — the app still works alone.
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// The shared home for a store file, migrating the pre-group copy out
    /// of Documents the first time (copy, not move — a failed write later
    /// should never have destroyed the only good file).
    static func dataFileURL(_ name: String) -> URL {
        let shared = containerURL.appendingPathComponent(name)
        let legacy = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: shared.path),
           FileManager.default.fileExists(atPath: legacy.path),
           shared != legacy {
            try? FileManager.default.copyItem(at: legacy, to: shared)
        }
        return shared
    }
}
