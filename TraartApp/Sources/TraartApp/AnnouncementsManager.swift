import Foundation
import UserNotifications

final class AnnouncementsManager {
    static let shared = AnnouncementsManager()

    // URL of the announcements JSON — host on your website or GitHub Pages
    private static let feedURL = URL(string: "https://traart.ru/announcements.json")!

    private let defaults = UserDefaults(suiteName: "com.traart.app") ?? .standard
    private static let seenIDsKey = "seenAnnouncementIDs"
    private static let lastCheckKey = "lastAnnouncementCheck"
    private static let checkIntervalSeconds: TimeInterval = 15 * 60  // every 15 minutes

    private static let notificationCategory = "ANNOUNCEMENT"

    /// The most recently fetched announcement (cached in memory).
    private(set) var latestAnnouncement: Announcement?

    private init() {}

    // MARK: - Data Model

    struct AnnouncementAction: Codable {
        let title: String
        let url: String?
        let style: String?  // "primary" or "secondary"
    }

    struct Announcement: Codable {
        let id: String
        let title: String
        let body: String           // short text for push notification
        let date: String           // ISO 8601 date string
        let url: String?           // optional legacy link
        let badge: String?         // emoji badge for the title
        let detail: String?        // long rich text for the window (paragraphs separated by \n\n, > for quotes)
        let actions: [AnnouncementAction]?  // action buttons
        let minVersion: String?    // show only to users on this version or later
        let maxVersion: String?    // show only to users on this version or earlier
    }

    // MARK: - Public API

    /// Check for new announcements (throttled).
    func checkForAnnouncements() {
        guard shouldCheck() else { return }

        let request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            self.defaults.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

            guard let announcements = try? JSONDecoder().decode([Announcement].self, from: data) else {
                return
            }

            // Cache latest
            if let first = announcements.first {
                self.latestAnnouncement = first
            }

            let seenIDs = self.seenAnnouncementIDs
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            let newAnnouncements = announcements.filter { announcement in
                guard !seenIDs.contains(announcement.id) else { return false }
                if let minVer = announcement.minVersion, appVersion.compare(minVer, options: .numeric) == .orderedAscending {
                    return false
                }
                if let maxVer = announcement.maxVersion, appVersion.compare(maxVer, options: .numeric) == .orderedDescending {
                    return false
                }
                return true
            }

            for announcement in newAnnouncements {
                self.showNotification(for: announcement)
                self.markAsSeen(announcement.id)
            }

            // Auto-show window for the latest new announcement
            if let latest = newAnnouncements.first {
                DispatchQueue.main.async {
                    AnnouncementWindowController.shared.show(announcement: latest)
                }
            }
        }.resume()
    }

    /// Fetch the latest announcement (for showing window from menu).
    func fetchLatest(completion: @escaping (Announcement?) -> Void) {
        if let cached = latestAnnouncement {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        let request = URLRequest(url: Self.feedURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let announcements = try? JSONDecoder().decode([Announcement].self, from: data),
                  let first = announcements.first else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.latestAnnouncement = first
            DispatchQueue.main.async { completion(first) }
        }.resume()
    }

    // MARK: - Notification

    private func showNotification(for announcement: Announcement) {
        let content = UNMutableNotificationContent()
        content.title = announcement.title
        content.body = announcement.body
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory
        content.threadIdentifier = "traart-announcements"

        if let urlStr = announcement.url {
            content.userInfo = ["announcementURL": urlStr, "announcementID": announcement.id]
        } else {
            content.userInfo = ["announcementID": announcement.id]
        }

        let request = UNNotificationRequest(
            identifier: "announcement-\(announcement.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Handle notification tap — open window instead of browser.
    func handleNotificationAction(userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            AnnouncementWindowController.shared.showLatest()
        }
    }

    // MARK: - Seen Tracking

    private var seenAnnouncementIDs: Set<String> {
        let array = defaults.stringArray(forKey: Self.seenIDsKey) ?? []
        return Set(array)
    }

    private func markAsSeen(_ id: String) {
        var ids = defaults.stringArray(forKey: Self.seenIDsKey) ?? []
        ids.append(id)
        // Keep only last 100 to prevent unbounded growth
        if ids.count > 100 {
            ids = Array(ids.suffix(100))
        }
        defaults.set(ids, forKey: Self.seenIDsKey)
    }

    // MARK: - Throttling

    private func shouldCheck() -> Bool {
        let lastCheck = defaults.double(forKey: Self.lastCheckKey)
        guard lastCheck > 0 else { return true }
        return Date().timeIntervalSince1970 - lastCheck >= Self.checkIntervalSeconds
    }

}
