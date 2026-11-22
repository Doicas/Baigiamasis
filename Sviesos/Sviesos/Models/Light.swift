import Foundation

/// Vienas šviestuvas (HomeKit „Lightbulb“ paslauga arba demonstracinė lemputė).
struct Light: Identifiable, Hashable {
    let id: UUID
    var name: String
    var room: String
    var isOn: Bool
    /// Ryškumas 0–100. `nil`, jei šviestuvas nepalaiko ryškumo keitimo.
    var brightness: Int?
    /// Atspalvis 0–360. `nil`, jei šviestuvas nepalaiko spalvų.
    var hue: Double?
    var saturation: Double?
    var isReachable: Bool = true

    var supportsBrightness: Bool { brightness != nil }
    var supportsColor: Bool { hue != nil }
}

/// Spalva, kurią galima nurodyti balsu.
struct LightColor: Equatable {
    /// Pavadinimas lietuviškai (naudojamas atsakymuose).
    let name: String
    let hue: Double
    let saturation: Double
}

/// Komandos vykdymo rezultatas, rodomas ekrane ir (jei įjungta) perskaitomas balsu.
struct CommandOutcome: Equatable {
    let message: String
    let success: Bool
}
