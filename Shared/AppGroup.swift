import Foundation

/// Shared App Group container so the widget extension and the main app
/// read/write the same SwiftData store. Both targets must carry the
/// matching `com.apple.security.application-groups` entitlement.
enum AppGroup {
    static let identifier = "group.com.moodlock.app"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group container unavailable — check the App Groups entitlement on both targets.")
        }
        return url
    }

    static var modelStoreURL: URL {
        containerURL.appendingPathComponent("MoodLock.sqlite")
    }
}
