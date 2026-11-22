import SwiftUI

struct ContentView: View {
    @Environment(LightStore.self) private var store
    @Environment(VoiceAssistant.self) private var assistant
    @State private var showSettings = false
    @State private var showKeyboard = false
    @State private var typedCommand = ""
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                if let status = store.statusMessage {
                    Section {
                        Label(status, systemImage: store.source == .demo ? "info.circle" : "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    VoiceStatusCard()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !store.lights.isEmpty {
                    Section {
                        HStack(spacing: 12) {
                            QuickButton(title: "Įjungti visas", systemImage: "lightbulb.fill", tint: .yellow) {
                                Task { await store.setAll(true) }
                            }
                            QuickButton(title: "Išjungti visas", systemImage: "lightbulb.slash", tint: .gray) {
                                Task { await store.setAll(false) }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                ForEach(store.rooms, id: \.self) { room in
                    Section(room) {
                        ForEach(store.lights(in: room)) { light in
                            LightRow(light: light)
                        }
                    }
                }

                if store.isLoading && store.lights.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Ieškoma šviestuvų…")
                            Spacer()
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Šviesos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Nustatymai")
                }
            }
            .refreshable { await store.reload() }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { await store.ensureLoaded() }
            .sensoryFeedback(trigger: assistant.feedbackCount) { _, _ in
                (assistant.lastOutcome?.success ?? true) ? .success : .error
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if showKeyboard {
                HStack {
                    TextField("Įveskite komandą…", text: $typedCommand)
                        .textFieldStyle(.roundedBorder)
                        .focused($keyboardFocused)
                        .submitLabel(.send)
                        .onSubmit(sendTypedCommand)
                    Button("Siųsti", action: sendTypedCommand)
                        .disabled(typedCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
            }

            HStack(alignment: .center) {
                Button {
                    withAnimation { showKeyboard.toggle() }
                    keyboardFocused = showKeyboard
                } label: {
                    Image(systemName: showKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                }
                .accessibilityLabel("Įvesti tekstu")

                Spacer()
                MicButton()
                Spacer()

                Color.clear.frame(width: 56, height: 56)
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(.bar)
    }

    private func sendTypedCommand() {
        let text = typedCommand
        typedCommand = ""
        Task { await assistant.handle(text) }
    }
}

/// Rodo, ką girdime ir kaip įvykdyta paskutinė komanda.
struct VoiceStatusCard: View {
    @Environment(VoiceAssistant.self) private var assistant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if assistant.speech.isListening {
                Label("Klausausi…", systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative, isActive: true)
                Text(assistant.speech.transcript.isEmpty ? "Sakykite komandą" : "„\(assistant.speech.transcript)“")
                    .font(.title3)
                    .foregroundStyle(assistant.speech.transcript.isEmpty ? .secondary : .primary)
            } else if assistant.isProcessing {
                ProgressView("Vykdoma…")
            } else if let error = assistant.speech.errorMessage {
                Label(error, systemImage: "mic.slash")
                    .foregroundStyle(.orange)
            } else if let outcome = assistant.lastOutcome {
                if let command = assistant.history.first?.command {
                    Text("„\(command)“")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(outcome.message, systemImage: outcome.success ? "checkmark.circle.fill" : "questionmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(outcome.success ? .green : .orange)
            } else {
                Text("Paspauskite mikrofoną ir pasakykite:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("„Įjunk šviesą svetainėje“")
                    .font(.title3.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.default, value: assistant.speech.isListening)
    }
}

struct QuickButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}

#Preview {
    ContentView()
        .environment(LightStore.shared)
        .environment(VoiceAssistant.shared)
}
