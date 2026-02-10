import Foundation
import UserNotifications

final class NotificationService {
    private let center: UNUserNotificationCenter?
    private var didRequest = false

    init() {
        let bundleURL = Bundle.main.bundleURL
        let isAppBundle = bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isAppBundle && !isPreview {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
    }

    func requestAuthorization() {
        guard let center, !didRequest else { return }
        didRequest = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
