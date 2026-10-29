// Target: the iOS app ("MirrorLink"). Stores the server address and pairing code in the App Group,
// then shows Apple's broadcast picker. iOS itself asks for permission before any capture starts.
import SwiftUI
import ReplayKit

private let appGroup = "group.com.example.mirrorlink"                 // same ID as in SampleHandler.swift
private let extensionID = "com.example.mirrorlink.MirrorLinkBroadcast" // your extension's bundle ID

@main
struct MirrorLinkApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @AppStorage("host", store: UserDefaults(suiteName: appGroup)) private var host = "ws://192.168.1.10:3000"
    @AppStorage("code", store: UserDefaults(suiteName: appGroup)) private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("From the MirrorLink page on your computer") {
                    TextField("Server address", text: $host)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField("8-character code", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                }
                Section {
                    HStack {
                        Text("Start Broadcast")
                        Spacer()
                        BroadcastPicker().frame(width: 44, height: 44)
                    }
                } footer: {
                    Text("Tap the icon, choose MirrorLink, then Start Broadcast. Only your screen is sent, to the server you entered. Nothing is recorded.")
                }
            }
            .navigationTitle("MirrorLink")
        }
    }
}

struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        v.preferredExtension = extensionID
        v.showsMicrophoneButton = false
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
