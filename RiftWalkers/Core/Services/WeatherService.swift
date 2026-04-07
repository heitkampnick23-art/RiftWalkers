import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

// MARK: - Weather Service (WeatherKit Integration)
// Real-world weather drives gameplay mechanics:
// - Rain → water/lightning spawns boosted, fire weakened
// - Snow → ice/frost creatures appear, nature weakened
// - Night + clear → void/arcane creatures, rare mythic spawns
// - Thunderstorm → legendary lightning creatures, 2x catch rate
// - Seasonal mythology cycles: Norse=winter, Egyptian=summer, Celtic=equinox

final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var currentCondition: GameWeather = .clear
    @Published var temperature: Double = 20
    @Published var isNight: Bool = false
    @Published var season: Season = .spring
    @Published var weatherSpawnBoosts: [Element: Double] = [:]
    @Published var activeMythologyCycle: Mythology = .norse
    @Published var weatherEventActive: Bool = false
    @Published var weatherEventName: String?

    private let weatherService = WeatherKit.WeatherService.shared
    private var refreshTimer: Timer?

    // MARK: - Game Weather Types

    enum GameWeather: String, CaseIterable {
        case clear = "Clear"
        case cloudy = "Cloudy"
        case rain = "Rain"
        case heavyRain = "Heavy Rain"
        case thunderstorm = "Thunderstorm"
        case snow = "Snow"
        case fog = "Fog"
        case wind = "Windy"
        case heatwave = "Heatwave"
        case blizzard = "Blizzard"

        var icon: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .rain: return "cloud.rain.fill"
            case .heavyRain: return "cloud.heavyrain.fill"
            case .thunderstorm: return "cloud.bolt.fill"
            case .snow: return "cloud.snow.fill"
            case .fog: return "cloud.fog.fill"
            case .wind: return "wind"
            case .heatwave: return "thermometer.sun.fill"
            case .blizzard: return "snowflake"
            }
        }

        var color: Color {
            switch self {
            case .clear: return .yellow
            case .cloudy: return .gray
            case .rain, .heavyRain: return .blue
            case .thunderstorm: return .purple
            case .snow, .blizzard: return .cyan
            case .fog: return .gray.opacity(0.6)
            case .wind: return .teal
            case .heatwave: return .orange
            }
        }

        var elementBoosts: [Element: Double] {
            switch self {
            case .clear:        return [.fire: 1.3, .light: 1.5, .nature: 1.2]
            case .cloudy:       return [.air: 1.3, .shadow: 1.2]
            case .rain:         return [.water: 2.0, .lightning: 1.5, .nature: 1.3, .fire: 0.5]
            case .heavyRain:    return [.water: 2.5, .lightning: 2.0, .fire: 0.3]
            case .thunderstorm: return [.lightning: 3.0, .water: 2.0, .void: 1.5, .fire: 0.2]
            case .snow:         return [.ice: 2.5, .frost: 2.0, .wind: 1.5, .fire: 0.3, .nature: 0.5]
            case .fog:          return [.shadow: 2.0, .void: 1.8, .arcane: 1.5]
            case .wind:         return [.wind: 2.5, .air: 2.0, .earth: 0.7]
            case .heatwave:     return [.fire: 3.0, .earth: 1.5, .water: 0.5, .ice: 0.2]
            case .blizzard:     return [.ice: 3.0, .frost: 2.5, .shadow: 1.5, .fire: 0.1]
            }
        }

        var rarityMultiplier: Double {
            switch self {
            case .thunderstorm: return 2.0  // Legendary weather
            case .blizzard: return 1.8
            case .heavyRain: return 1.5
            case .fog: return 1.4
            case .heatwave: return 1.3
            default: return 1.0
            }
        }

        var specialEvent: String? {
            switch self {
            case .thunderstorm: return "Rift Storm — Legendary spawns active!"
            case .blizzard: return "Norse Convergence — Frost creatures everywhere!"
            case .fog: return "Veil Thinning — Shadow & Void creatures emerge"
            case .heatwave: return "Solar Flare — Fire mythology dominates"
            default: return nil
            }
        }
    }

    enum Season: String, CaseIterable {
        case spring, summer, autumn, winter

        var dominantMythologies: [Mythology] {
            switch self {
            case .spring: return [.japanese, .celtic, .greek]   // Rebirth, growth
            case .summer: return [.egyptian, .hindu, .aztec]     // Sun, heat
            case .autumn: return [.chinese, .slavic, .african]   // Harvest, spirits
            case .winter: return [.norse, .slavic, .japanese]    // Frost, darkness
            }
        }

        var elementBoosts: [Element: Double] {
            switch self {
            case .spring: return [.nature: 1.5, .water: 1.3, .light: 1.2]
            case .summer: return [.fire: 1.5, .light: 1.3, .earth: 1.2]
            case .autumn: return [.wind: 1.5, .shadow: 1.3, .arcane: 1.2]
            case .winter: return [.ice: 1.5, .frost: 1.3, .shadow: 1.2]
            }
        }
    }

    private init() {
        updateSeason()
        updateTimeOfDay()
        startRefreshCycle()
    }

    // MARK: - Fetch Weather

    func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            await MainActor.run {
                self.temperature = current.temperature.converted(to: .fahrenheit).value
                self.currentCondition = mapCondition(current.condition)
                self.weatherSpawnBoosts = self.currentCondition.elementBoosts
                self.weatherEventActive = self.currentCondition.specialEvent != nil
                self.weatherEventName = self.currentCondition.specialEvent

                // Merge season boosts
                for (element, boost) in self.season.elementBoosts {
                    self.weatherSpawnBoosts[element, default: 1.0] *= boost
                }
            }
        } catch {
            print("[Weather] Fetch failed: \(error) — using defaults")
            await MainActor.run {
                self.currentCondition = estimateFromTimeAndSeason()
            }
        }
    }

    // MARK: - Spawn Integration

    /// Get combined weather+season spawn weight for a species
    func spawnMultiplier(for species: CreatureSpecies) -> Double {
        var multiplier = 1.0

        // Element weather boost
        if let boost = weatherSpawnBoosts[species.element] {
            multiplier *= boost
        }

        // Mythology season boost
        if season.dominantMythologies.contains(species.mythology) {
            multiplier *= 1.5
        }

        // Night boost for dark creatures
        if isNight && [.shadow, .void, .arcane].contains(species.element) {
            multiplier *= 1.8
        }

        // Rarity multiplier from extreme weather
        multiplier *= currentCondition.rarityMultiplier

        return multiplier
    }

    // MARK: - Helpers

    private func mapCondition(_ condition: WeatherKit.WeatherCondition) -> GameWeather {
        switch condition {
        case .clear, .mostlyClear:                                 return .clear
        case .partlyCloudy, .mostlyCloudy, .cloudy:                return .cloudy
        case .rain, .drizzle:                                      return .rain
        case .heavyRain:                                           return .heavyRain
        case .thunderstorms, .tropicalStorm:                       return .thunderstorm
        case .snow, .flurries:                                     return .snow
        case .blizzard, .heavySnow:                                return .blizzard
        case .foggy, .haze, .smoky:                                return .fog
        case .windy, .breezy:                                      return .wind
        case .hot:                                                 return .heatwave
        default:                                                   return .clear
        }
    }

    private func estimateFromTimeAndSeason() -> GameWeather {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 5 { return .fog }
        switch season {
        case .winter: return .snow
        case .summer: return temperature > 90 ? .heatwave : .clear
        default: return .clear
        }
    }

    private func updateSeason() {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: season = .spring
        case 6...8: season = .summer
        case 9...11: season = .autumn
        default: season = .winter
        }
        activeMythologyCycle = season.dominantMythologies.first ?? .norse
    }

    private func updateTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        isNight = hour >= 20 || hour < 6
    }

    private func startRefreshCycle() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.updateTimeOfDay()
            if let location = LocationService.shared.currentLocation {
                Task { await self?.fetchWeather(for: location) }
            }
        }
    }
}
