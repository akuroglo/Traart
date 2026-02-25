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

    // Callback for when user taps an announcement with a URL
    var onOpenURL: ((URL) -> Void)?

    private init() {}

    // MARK: - Data Model

    struct Announcement: Codable {
        let id: String
        let title: String
        let body: String
        let date: String           // ISO 8601 date string
        let url: String?           // optional link to open
        let minVersion: String?    // show only to users on this version or later
        let maxVersion: String?    // show only to users on this version or earlier
    }

    // MARK: - Public API

    /// Check for new announcements (throttled to once per day).
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
        }.resume()
    }

    /// Get all announcements that have been shown (for displaying in menu).
    func fetchAnnouncementsForMenu(completion: @escaping ([Announcement]) -> Void) {
        let request = URLRequest(url: Self.feedURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let announcements = try? JSONDecoder().decode([Announcement].self, from: data) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            // Return latest 5
            let latest = Array(announcements.prefix(5))
            DispatchQueue.main.async { completion(latest) }
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

    /// Handle notification tap — called from NotificationManager.
    func handleNotificationAction(userInfo: [AnyHashable: Any]) {
        if let urlStr = userInfo["announcementURL"] as? String,
           let url = URL(string: urlStr) {
            onOpenURL?(url)
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
