import Foundation
import UserNotifications

/// Tells the user that a meeting evaluation finished while the menu was closed: a long
/// meeting takes minutes, and nobody keeps the menu open for that. The message names
/// length and number of people, never what was said.
enum MeetingNotifier {
    /// Asked when a meeting starts, so the question never interrupts the end of one.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func finished(_ record: MeetingRecord) {
        let people = record.speakers.count == 1 ? String(localized: "1 Person") : String(localized: "\(record.speakers.count) Personen")
        post(title: String(localized: "Meeting ausgewertet"), body: String(localized: "\(duration(record.duration)), \(people). Im Diktat-Men\u{00FC} unter Meeting."))
    }

    /// Clicking this notification opens the meeting page with the online source picked.
    static let prepareAction = "prepareOnlineMeeting"

    /// A call app has the microphone open: offers to record it. Asks for the notification
    /// permission the first time, since it is only needed now.
    static func suggestRecording(app: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { postSuggestion(app: app) }
                }
            case .authorized, .provisional:
                postSuggestion(app: app)
            default:
                break
            }
        }
    }

    private static func postSuggestion(app: String) {
        let content = UNMutableNotificationContent()
        content.title = app == "Browser" ? String(localized: "Ein Anruf im Browser l\u{00E4}uft") : String(localized: "\(app) l\u{00E4}uft")
        content.body = String(localized: "Soll Diktat das Meeting aufnehmen? Ein Klick \u{00F6}ffnet die Meeting-Seite. Bitte vorher alle um Einverst\u{00E4}ndnis bitten.")
        content.userInfo = ["diktatAction": prepareAction]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "call-\(app)", content: content, trigger: nil))
    }

    static func failed(_ message: String) {
        post(title: String(localized: "Meeting-Auswertung fehlgeschlagen"), body: message)
    }

    /// "2 Std. 3 Min." or "45 Min."
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes >= 60 ? String(localized: "\(minutes / 60) Std. \(minutes % 60) Min.") : String(localized: "\(minutes) Min.")
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
