internal import AppKit

/// The cache stores VPN app icons by bundle ID because the compact view requests each app's icon
/// when it redraws every second. It does not cache a missing app, so the view shows the icon if the
/// app is installed later.
enum VPNAppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(for bundleID: String) -> NSImage? {
        if let icon = icons[bundleID] {
            return icon
        }

        guard let icon = lookUpIcon(for: bundleID) else {
            return nil
        }
        icons[bundleID] = icon
        return icon
    }

    private static func lookUpIcon(for bundleID: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        let parts = bundleID.components(separatedBy: ".")
        if parts.count > 2 {
            let parentID = parts.dropLast().joined(separator: ".")
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parentID) {
                return NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
        return nil
    }
}
