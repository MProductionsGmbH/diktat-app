import Foundation

/// Notices that a call app has the microphone open, so Diktat can suggest recording the
/// meeting with the Mac's sound. It reads only which apps use audio right now (the same list
/// the system shows), never what they play or record.
enum CallDetection {
    struct Candidate: Equatable {
        let bundleID: String
        let isRunningInput: Bool
        let isRunningOutput: Bool
    }

    /// Apps made for calls: an open microphone is enough.
    static let callApps: [(prefix: String, name: String)] = [
        ("us.zoom.xos", "Zoom"),
        ("com.microsoft.teams", "Teams"),
        ("com.cisco.webexmeetingsapp", "Webex"),
        ("Cisco-Systems.Spark", "Webex"),
        ("com.apple.FaceTime", "FaceTime"),
        ("com.skype.skype", "Skype"),
        ("com.hnc.Discord", "Discord"),
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.ringcentral", "RingCentral"),
        ("com.gotomeeting", "GoTo"),
        ("com.bluejeans", "BlueJeans"),
    ]

    /// Browsers run Meet, Teams and others, but also play videos and take dictation, so only
    /// sound in and out together counts as a call.
    static let browsers = [
        "com.google.Chrome", "com.apple.Safari", "com.apple.WebKit", "org.mozilla.firefox",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "com.brave.Browser", "com.operasoftware.Opera",
    ]

    /// The names of the apps that look like a call, without repeats and in a steady order.
    static func calls(in candidates: [Candidate]) -> [String] {
        var names: [String] = []
        func add(_ name: String) {
            if !names.contains(name) { names.append(name) }
        }
        for candidate in candidates where candidate.isRunningInput {
            if let app = callApps.first(where: { candidate.bundleID.hasPrefix($0.prefix) }) {
                add(app.name)
            } else if candidate.isRunningOutput, browsers.contains(where: { candidate.bundleID.hasPrefix($0) }) {
                add("Browser")
            }
        }
        return names
    }
}
