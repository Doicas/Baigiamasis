import Foundation

/// Šviesų šaltinis: tikri HomeKit įrenginiai arba demonstraciniai šviestuvai.
@MainActor
protocol LightBackend: AnyObject {
    /// Iškviečiama, kai pasikeičia šviestuvų būsena (`needsReload == true` – pasikeitė pati namų struktūra).
    var onChange: ((_ needsReload: Bool) -> Void)? { get set }
    /// Paaiškinimas vartotojui, jei kažkas negerai (nėra leidimo, nėra namų ir pan.).
    var statusMessage: String? { get }

    /// Įkelia įrenginius ir nuskaito jų būsenas.
    func load() async
    /// Dabartinė būsena iš talpyklos (be tinklo užklausų).
    func snapshot() -> [Light]

    func setPower(_ isOn: Bool, for id: UUID) async throws
    func setBrightness(_ value: Int, for id: UUID) async throws
    func setColor(hue: Double, saturation: Double, for id: UUID) async throws
}

enum LightBackendError: LocalizedError {
    case notFound
    case unsupported
    case unreachable(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Šviestuvas nerastas."
        case .unsupported: return "Šviestuvas šios funkcijos nepalaiko."
        case .unreachable(let name): return "„\(name)“ nepasiekiamas."
        }
    }
}

/// Demonstraciniai šviestuvai – kad programėlę būtų galima išbandyti be HomeKit įrenginių
/// (pvz., simuliatoriuje).
@MainActor
final class DemoLightBackend: LightBackend {
    var onChange: ((Bool) -> Void)?
    var statusMessage: String? { "Demonstracinis režimas – šviestuvai netikri." }

    private var lights: [Light] = [
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Lubų šviestuvas",
              room: "Svetainė", isOn: true, brightness: 80, hue: 35, saturation: 45),
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Toršeras",
              room: "Svetainė", isOn: false, brightness: 60),
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Virtuvės šviesa",
              room: "Virtuvė", isOn: false, brightness: 100),
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Juosta po spintelėmis",
              room: "Virtuvė", isOn: false, brightness: 50, hue: 230, saturation: 100),
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: "Naktinė lempa",
              room: "Miegamasis", isOn: false, brightness: 30, hue: 30, saturation: 60),
        Light(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!, name: "Veidrodžio šviesa",
              room: "Vonia", isOn: false, brightness: nil),
    ]

    func load() async {}

    func snapshot() -> [Light] { lights }

    func setPower(_ isOn: Bool, for id: UUID) async throws {
        try update(id) { $0.isOn = isOn }
    }

    func setBrightness(_ value: Int, for id: UUID) async throws {
        try update(id) { light in
            guard light.supportsBrightness else { throw LightBackendError.unsupported }
            light.brightness = value
        }
    }

    func setColor(hue: Double, saturation: Double, for id: UUID) async throws {
        try update(id) { light in
            guard light.supportsColor else { throw LightBackendError.unsupported }
            light.hue = hue
            light.saturation = saturation
        }
    }

    private func update(_ id: UUID, _ change: (inout Light) throws -> Void) throws {
        guard let index = lights.firstIndex(where: { $0.id == id }) else { throw LightBackendError.notFound }
        try change(&lights[index])
        onChange?(false)
    }
}
