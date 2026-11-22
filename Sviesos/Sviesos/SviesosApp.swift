import SwiftUI

@main
struct SviesosApp: App {
    @State private var store = LightStore.shared
    @State private var assistant = VoiceAssistant.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(assistant)
                .tint(.orange)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Grįžus į programėlę atnaujiname būsenas (šviesas galėjo keisti kiti).
                if store.hasLoaded { Task { await store.reload() } }
            case .background:
                assistant.speech.cancel()
            default:
                break
            }
        }
    }
}
