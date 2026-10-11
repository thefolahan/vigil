import Foundation
import UserNotifications

/// Posts local notifications. Silently does nothing until permission is given.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter? {
        // The notification center needs a real app bundle, which a bare
        // `swift run` does not have.
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func requestPermission() {
        center?.delegate = self
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center?.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Shows notifications even while the panel is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// Sends a push to the ntfy app on your phone. The topic name is the only
/// secret, so it should be long and hard to guess.
enum PhoneAlert {
    static func send(topic: String, title: String, body: String) {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard topic.unicodeScalars.allSatisfy(allowed.contains),
              let url = URL(string: "https://ntfy.sh/\(topic)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue("eye", forHTTPHeaderField: "Tags")
        URLSession.shared.dataTask(with: request).resume()
    }
}
