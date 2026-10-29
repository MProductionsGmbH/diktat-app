import SwiftUI

/// "Mikrofon": which microphone dictation records. The first entry follows the Mac's default
/// input, so nothing changes for anyone who never opens this.
struct MicrophonePickerRow: View {
    @Bindable var appState: AppState
    @State private var inputs = AudioInputDeviceList()

    private static let systemTag = ""

    private var resolution: MicrophoneSelection.Resolution {
        MicrophoneSelection.resolve(preferredUID: appState.appSettings.microphoneUID, available: inputs.devices)
    }

    private var selection: Binding<String> {
        Binding(
            get: { appState.appSettings.microphoneUID ?? Self.systemTag },
            set: { appState.appSettings.microphoneUID = $0 == Self.systemTag ? nil : $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Mikrofon")
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 62, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)

                Picker("", selection: selection) {
                    Text(systemLabel).tag(Self.systemTag)
                    ForEach(inputs.devices) { device in
                        Text(device.name).tag(device.uid)
                    }
                    if case .missing(let uid) = resolution {
                        Text("Nicht angeschlossen").tag(uid)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .controlSize(.small)
            }

            if case .missing = resolution {
                Text("Das gew\u{00E4}hlte Mikrofon ist nicht angeschlossen. Diktat nimmt so lange das Mikrofon des Systems.")
                    .font(.ui(11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var systemLabel: String {
        if let name = inputs.defaultName {
            return String(localized: "Systemstandard (\(name))")
        }
        return String(localized: "Systemstandard")
    }
}
