import SwiftUI

struct LightRow: View {
    @Environment(LightStore.self) private var store
    let light: Light

    @State private var brightness: Double = 0
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                    .font(.title2)
                    .foregroundStyle(light.isOn ? bulbColor : .secondary)
                    .frame(width: 32)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(light.name)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(light.name, isOn: Binding(
                    get: { light.isOn },
                    set: { newValue in Task { await store.setPower(newValue, for: light) } }
                ))
                .labelsHidden()
                .disabled(!light.isReachable)
            }

            if light.supportsBrightness && light.isOn {
                HStack(spacing: 10) {
                    Image(systemName: "sun.min")
                        .foregroundStyle(.secondary)
                    Slider(value: $brightness, in: 1...100, step: 1) { editing in
                        isEditing = editing
                        if !editing {
                            Task { await store.setBrightness(Int(brightness), for: light) }
                        }
                    }
                    .tint(bulbColor)
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .opacity(light.isReachable ? 1 : 0.5)
        .animation(.default, value: light.isOn)
        .onAppear { brightness = Double(light.brightness ?? 100) }
        .onChange(of: light.brightness) { _, newValue in
            if !isEditing { brightness = Double(newValue ?? 100) }
        }
    }

    private var subtitle: String {
        guard light.isReachable else { return "Nepasiekiamas" }
        guard light.isOn else { return "Išjungta" }
        if isEditing { return "\(Int(brightness)) %" }
        if let value = light.brightness { return "Įjungta · \(value) %" }
        return "Įjungta"
    }

    private var bulbColor: Color {
        guard let hue = light.hue else { return .yellow }
        let saturation = (light.saturation ?? 100) / 100
        // Balta / beveik balta šviesa – rodome šiltai geltoną.
        if saturation < 0.1 { return .yellow }
        return Color(hue: hue / 360, saturation: saturation, brightness: 1)
    }
}
