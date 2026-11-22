import AppIntents

/// Atidaro programėlę ir iš karto pradeda klausytis.
/// Tinka iPhone 16 Pro Max veiksmo mygtukui (Action Button) ir valdymo centrui.
struct StartListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Klausytis komandos"
    static let description = IntentDescription("Atidaro Šviesos ir pradeda klausytis balso komandos.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Leidžiame programėlei atsidaryti prieš įjungiant mikrofoną.
        try? await Task.sleep(for: .milliseconds(400))
        VoiceAssistant.shared.startListening()
        return .result()
    }
}

/// Įvykdo tekstinę komandą – patogu kurti savo „Shortcuts“.
struct RunLightCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "Vykdyti šviesų komandą"
    static let description = IntentDescription("Įvykdo komandą, pvz., „įjunk šviesą svetainėje“ arba „pritemdyk miegamąjį iki 30 %“.")

    @Parameter(title: "Komanda", requestValueDialog: "Ką padaryti su šviesomis?")
    var command: String

    static var parameterSummary: some ParameterSummary {
        Summary("Vykdyti \(\.$command)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await LightStore.shared.run(command)
        return .result(dialog: "\(outcome.message)")
    }
}

struct TurnOnAllLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Įjungti visas šviesas"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await LightStore.shared.setAll(true)
        return .result(dialog: "\(outcome.message)")
    }
}

struct TurnOffAllLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Išjungti visas šviesas"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await LightStore.shared.setAll(false)
        return .result(dialog: "\(outcome.message)")
    }
}

/// Siri frazės. Siri lietuviškai nekalba, todėl frazės angliškos;
/// pačioje programėlėje komandas galima sakyti lietuviškai.
struct SviesosShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Listen with \(.applicationName)",
                "Start \(.applicationName)",
                "Control lights with \(.applicationName)",
            ],
            shortTitle: "Klausytis",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: TurnOnAllLightsIntent(),
            phrases: [
                "Turn on lights with \(.applicationName)",
                "Turn on all lights in \(.applicationName)",
            ],
            shortTitle: "Įjungti visas",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnOffAllLightsIntent(),
            phrases: [
                "Turn off lights with \(.applicationName)",
                "Turn off all lights in \(.applicationName)",
            ],
            shortTitle: "Išjungti visas",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: RunLightCommandIntent(),
            phrases: ["Run a light command in \(.applicationName)"],
            shortTitle: "Komanda",
            systemImageName: "text.bubble"
        )
    }
}
