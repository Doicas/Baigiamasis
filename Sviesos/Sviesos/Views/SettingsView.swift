import SwiftUI

struct SettingsView: View {
    @Environment(LightStore.self) private var store
    @Environment(VoiceAssistant.self) private var assistant
    @Environment(\.dismiss) private var dismiss

    private let examples = [
        "Įjunk šviesą svetainėje",
        "Išjunk visas šviesas",
        "Uždek naktinę lempą",
        "Pritemdyk miegamąjį iki 20 procentų",
        "Pašviesink virtuvėje",
        "Nustatyk raudoną spalvą svetainėje",
        "Šilta šviesa miegamajame",
        "Turn off all lights",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Šaltinis", selection: Binding(
                        get: { store.source },
                        set: { store.setSource($0) }
                    )) {
                        ForEach(LightStore.Source.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                } header: {
                    Text("Šviestuvai")
                } footer: {
                    Text("HomeKit režimu valdomi šviestuvai, pridėti Apple programėlėje „Namai“ (Home): Philips Hue, IKEA, Nanoleaf, Aqara ir kiti HomeKit / Matter įrenginiai.")
                }

                Section {
                    Picker("Atpažinimo kalba", selection: Binding(
                        get: { assistant.speech.localeIdentifier },
                        set: { assistant.speech.setLocale($0) }
                    )) {
                        ForEach(SpeechRecognizer.availableLocales, id: \.self) { identifier in
                            Text(SpeechRecognizer.displayName(for: identifier)).tag(identifier)
                        }
                    }
                    Toggle("Atsakyti balsu", isOn: Binding(
                        get: { assistant.speaksResponses },
                        set: { assistant.setSpeaksResponses($0) }
                    ))
                } header: {
                    Text("Balsas")
                } footer: {
                    if !assistant.speech.isLithuanianSupported {
                        Text("Šis įrenginys nepalaiko lietuvių kalbos atpažinimo – naudokite anglų kalbą (pvz., „turn on the lights“) arba įveskite komandą klaviatūra.")
                    } else {
                        Text("Atsakymui balsu reikalingas lietuviškas balsas (Nustatymai → Pritaikymas neįgaliesiems → Įgarsintas turinys → Balsai).")
                    }
                }

                Section("Komandų pavyzdžiai") {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            dismiss()
                            Task { await assistant.handle(example) }
                        } label: {
                            Label("„\(example)“", systemImage: "text.bubble")
                        }
                    }
                }

                Section {
                    Label("Pasakykite Siri: „Listen with Šviesos“ arba „Turn off lights with Šviesos“.",
                          systemImage: "mic.badge.plus")
                    Label("iPhone 16 Pro Max veiksmo mygtukas (Action Button): Nustatymai → Veiksmo mygtukas → Spartusis veiksmas → Šviesos → „Klausytis“.",
                          systemImage: "button.programmable")
                } header: {
                    Text("Siri ir veiksmo mygtukas")
                }

                if !assistant.history.isEmpty {
                    Section("Istorija") {
                        ForEach(assistant.history) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("„\(entry.command)“")
                                Text(entry.outcome.message)
                                    .font(.caption)
                                    .foregroundStyle(entry.outcome.success ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nustatymai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gerai") { dismiss() }
                }
            }
        }
    }
}
