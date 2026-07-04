import Foundation

/// The one place both processes agree on where the data lives. Widgets run
/// in their own process and can't see the app's Documents, so the stores
/// write into the shared App Group container instead.
enum AppGroup {
    static let id = "group.com.brandonlukas.swisstime"

    /// Belt for the Control Center intent: if the system ever resolves the
    /// control against the WIDGET's registration (today's OS provably uses
    /// the app's, but that's the OS's choice, not ours), perform() runs in
    /// the extension where in-memory latches are invisible to the app — so
    /// the extension writes this flag instead, and the app consumes it on
    /// activation.
    static let startSetsFlagKey = "deepLink.startSets"

    /// The shared container, or the app's Documents when the group is
    /// unavailable (missing provisioning) — the app still works alone.
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// The shared home for a store file, migrating the pre-group copy out
    /// of Documents the first time (copy, not move — a failed write later
    /// should never have destroyed the only good file). If the copy
    /// itself fails, the LEGACY url is returned for this session: the
    /// user keeps their data, nothing writes to the shared path, and the
    /// migration retries next launch. Returning the shared path on a
    /// failed copy would show an empty library whose first save then
    /// blocks migration forever.
    static func dataFileURL(_ name: String) -> URL {
        let shared = containerURL.appendingPathComponent(name)
        let legacy = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: shared.path),
           FileManager.default.fileExists(atPath: legacy.path),
           shared != legacy {
            do {
                try FileManager.default.copyItem(at: legacy, to: shared)
            } catch {
                return legacy
            }
        }
        return shared
    }
}
