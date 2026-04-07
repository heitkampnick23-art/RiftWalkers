import Foundation
import CoreLocation
import Combine

// MARK: - Spawn Manager
// Researched: Pokemon GO's spawn system uses S2 cell geometry for world partitioning.
// We use a hex grid system. Spawns are deterministic per-cell but rotate on timers.
// Key retention metric: "Something is always spawning nearby" - never let the map feel empty.

final class SpawnManager: ObservableObject {
    static let shared = SpawnManager()

    @Published var activeSpawns: [SpawnEvent] = []
    @Published var nearbyCreatures: [SpawnEvent] = []
    @Published var isLoading = false

    private let locationService = LocationService.shared
    private let network = NetworkService.shared
    private let speciesDB = SpeciesDatabase.shared
    private let sceneAnalysis = SceneAnalysisService.shared
    private let weatherService = WeatherService.shared

    private var spawnTimer: Timer?
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Spawn configuration
    private let maxActiveSpawns = 30
    private let spawnRadius: Double = 500       // meters
    private let interactionRadius: Double = 50  // meters to interact
    private let spawnInterval: TimeInterval = 30
    private let spawnDuration: TimeInterval = 900  // 15 minutes

    private init() {
        setupLocationSubscription()
        startSpawnCycle()
    }

    // MARK: - Setup

    private func setupLocationSubscription() {
        locationService.$currentLocation
            .compactMap { $0 }
            .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] location in
                self?.updateNearbyCreatures(for: location)
                self?.fetchServerSpawns(for: location)
            }
            .store(in: &cancellables)
    }

    // MARK: - Spawn Cycle

    private func startSpawnCycle() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            self?.generateLocalSpawns()
        }

        // Clean expired spawns every 60 seconds
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupExpiredSpawns()
        }
    }

    func stopSpawnCycle() {
        spawnTimer?.invalidate()
        cleanupTimer?.invalidate()
    }

    // MARK: - Local Spawn Generation
    // Client-side spawning for responsiveness + server validation on capture

    private func generateLocalSpawns() {
        guard let location = locationService.currentLocation else { return }
        guard activeSpawns.count < maxActiveSpawns else { return }

        let biome = locationService.currentBiome
        let timeOfDay = currentTimeOfDay()
        let weather = currentWeather()

        // Get eligible species for current conditions
        let eligibleSpecies = speciesDB.speciesForBiome(biome).filter { species in
            (species.timePreference == .any || species.timePreference == timeOfDay) &&
            (species.weatherPreference.isEmpty || species.weatherPreference.contains(weather))
        }

        guard !eligibleSpecies.isEmpty else { return }

        // Weighted random selection — rarity + scene analysis from camera
        let weights = eligibleSpecies.map { species -> (CreatureSpecies, Double) in
            let baseWeight = species.rarity.spawnWeight
            let sceneBoost = sceneAnalysis.spawnWeight(for: species)
            let weatherBoost = weatherService.spawnMultiplier(for: species)
            return (species, baseWeight * sceneBoost * weatherBoost)
        }
        let totalWeight = weights.reduce(0.0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<totalWeight)

        var selectedSpecies: CreatureSpecies?
        for (species, weight) in weights {
            roll -= weight
            if roll <= 0 {
                selectedSpecies = species
                break
            }
        }

        guard let species = selectedSpecies else { return }

        // Generate spawn position within radius (random offset from player)
        let angle = Double.random(in: 0..<360)
        let distance = Double.random(in: 20...spawnRadius)
        let spawnLocation = offsetLocation(from: location.coordinate, distance: distance, bearing: angle)

        let isShiny = Double.random(in: 0..<1) < species.shinyRate
        let isWeatherBoosted = species.weatherPreference.contains(weather)

        let spawn = SpawnEvent(
            id: UUID(),
            speciesID: species.id,
            location: GeoPoint(coordinate: spawnLocation),
            spawnedAt: Date(),
            expiresAt: Date().addingTimeInterval(spawnDuration),
            isShiny: isShiny,
            isEvent: false,
            weatherBoosted: isWeatherBoosted,
            isCaptures: false
        )

        DispatchQueue.main.async {
            self.activeSpawns.append(spawn)
        }
    }

    // MARK: - Server Spawns

    private func fetchServerSpawns(for location: CLLocation) {
        Task {
            do {
                let serverSpawns = try await network.fetchNearbySpawns(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: spawnRadius
                )

                await MainActor.run {
                    // Merge server spawns with local, avoiding duplicates
                    for spawn in serverSpawns {
                        if !self.activeSpawns.contains(where: { $0.id == spawn.id }) {
                            self.activeSpawns.append(spawn)
                        }
                    }
                }
            } catch {
                // Silently fail - local spawns keep the map populated
                print("Server spawn fetch failed: \(error)")
            }
        }
    }

    // MARK: - Creature Interaction

    func canInteract(with spawn: SpawnEvent) -> Bool {
        locationService.isWithinRange(of: spawn.location, radius: interactionRadius)
    }

    func getCreatureForSpawn(_ spawn: SpawnEvent) -> Creature? {
        guard let species = speciesDB.getSpecies(spawn.speciesID) else { return nil }

        let level = max(1, min(40, (Int.random(in: 1...5) + playerAreaLevel())))

        return Creature(
            id: UUID(),
            speciesID: species.id,
            name: species.name,
            nickname: nil,
            mythology: species.mythology,
            element: species.element,
            rarity: species.rarity,
            level: level,
            experience: 0,
            baseHP: species.baseHP,
            baseAttack: species.baseAttack,
            baseDefense: species.baseDefense,
            baseSpeed: species.baseSpeed,
            baseSpecial: species.baseSpecial,
            ivHP: Int.random(in: 0...31),
            ivAttack: Int.random(in: 0...31),
            ivDefense: Int.random(in: 0...31),
            ivSpeed: Int.random(in: 0...31),
            ivSpecial: Int.random(in: 0...31),
            abilities: species.abilities.compactMap { speciesDB.abilityDatabase[$0] },
            passiveAbility: nil,
            currentHP: species.baseHP + level * 3,
            statusEffects: [],
            isShiny: spawn.isShiny,
            captureDate: Date(),
            captureLocation: spawn.location,
            evolutionStage: species.evolutionStage,
            evolutionChainID: species.evolutionChainID,
            canEvolve: species.evolvesInto != nil,
            evolutionCost: species.evolvesInto != nil ? EvolutionCost(
                essenceCost: species.rarity.stars * 25,
                goldCost: species.rarity.stars * 500,
                requiredLevel: species.evolutionStage * 15 + 5,
                requiredItem: nil
            ) : nil,
            affection: 0,
            lastFedDate: nil,
            lastPlayedDate: nil
        )
    }

    func markCaptured(_ spawnID: UUID) {
        if let index = activeSpawns.firstIndex(where: { $0.id == spawnID }) {
            activeSpawns[index].isCaptures = true
            activeSpawns.remove(at: index)
        }
    }

    // MARK: - Nearby Tracking

    private func updateNearbyCreatures(for location: CLLocation) {
        nearbyCreatures = activeSpawns.filter { spawn in
            let spawnLoc = CLLocation(latitude: spawn.location.latitude, longitude: spawn.location.longitude)
            return location.distance(from: spawnLoc) <= interactionRadius
        }
    }

    // MARK: - Cleanup

    private func cleanupExpiredSpawns() {
        activeSpawns.removeAll { $0.isExpired }
    }

    // MARK: - Helpers

    private func currentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return .dawn
        case 7..<18: return .day
        case 18..<20: return .dusk
        default: return .night
        }
    }

    private func currentWeather() -> WeatherCondition {
        // In production, integrate with WeatherKit API
        return .clear
    }

    private func playerAreaLevel() -> Int {
        // Based on player's level and area difficulty
        return 10
    }

    private func offsetLocation(from coordinate: CLLocationCoordinate2D, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0
        let angularDistance = distance / earthRadius
        let bearingRad = bearing * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
