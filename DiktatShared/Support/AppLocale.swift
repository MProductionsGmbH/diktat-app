import Foundation

/// The language the texts of the app are shown in: the one the bundle was localized into,
/// which follows the system language. Dates and times use it too, so a German app does not
/// show "10 minutes ago" and an English one does not show "vor 10 Minuten".
enum AppLocale {
    static var current: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
    }
}
