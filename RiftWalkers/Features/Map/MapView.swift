import SwiftUI
import MapKit

// MARK: - Main Map View
// The core game screen. Researched: Pokemon GO's map is the ENTIRE experience.
// The map must feel alive: creatures moving, territories pulsing, rifts glowing.
// Key UX: Never more than 2 taps from any action.

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var spawnManager = SpawnManager.shared
    @StateObject private var locationService = LocationService.shared

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedSpawn: SpawnEvent?
    @State private var selectedTerritory: Territory?
    @State private var showCreatureEncounter = false
    @State private var showTerritoryDetail = false
    @State private var showNearbyList = false
    @State private var showRadar = true
    @State private var mapStyle: MapStyleOption = .mythic

    enum MapStyleOption {
        case mythic, satellite, standard
    }

    var body: some View {
        ZStack {
            // MARK: - Map Layer
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
                // Player location
                UserAnnotation()

                // Creature spawns
                ForEach(spawnManager.activeSpawns.filter { !$0.isExpired }) { spawn in
                    Annotation("", coordinate: spawn.location.coordinate) {
                        CreatureMapPin(spawn: spawn)
                            .onTapGesture {
                                selectedSpawn = spawn
                                if spawnManager.canInteract(with: spawn) {
                                    showCreatureEncounter = true
                                }
                            }
                    }
                }

                // Territories
                ForEach(viewModel.nearbyTerritories) { territory in
                    // Territory zone circle
                    MapCircle(center: territory.location.coordinate, radius: territory.radius)
                        .foregroundStyle((territory.ownerFaction?.color ?? .gray).opacity(0.15))
                        .stroke(territory.ownerFaction?.color ?? .gray, lineWidth: 2)

                    // Territory pin
                    Annotation(territory.name, coordinate: territory.location.coordinate) {
                        TerritoryMapPin(territory: territory)
                            .onTapGesture {
                                selectedTerritory = territory
                                showTerritoryDetail = true
                            }
                    }
                }

                // Rift Dungeons
                ForEach(viewModel.nearbyDungeons) { dungeon in
                    Annotation(dungeon.name, coordinate: dungeon.location.coordinate) {
                        RiftDungeonMapPin(dungeon: dungeon)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls { }
            .ignoresSafeArea()

            // MARK: - UI Overlay
            VStack {
                // Top bar
                MapTopBar(
                    playerLevel: viewModel.playerLevel,
                    playerXP: viewModel.playerXPProgress,
                    dailyStreak: viewModel.dailyStreak,
                    nearbyCount: spawnManager.nearbyCreatures.count
                )

                Spacer()

                // Bottom controls
                HStack(alignment: .bottom, spacing: 16) {
                    // Radar / Nearby tracker
                    if showRadar {
                        NearbyRadar(
                            creatures: spawnManager.nearbyCreatures,
                            onTap: { showNearbyList = true }
                        )
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 12) {
                        MapActionButton(icon: "location.fill", label: "Center") {
                            withAnimation {
                                cameraPosition = .userLocation(fallback: .automatic)
                            }
                        }

                        MapActionButton(icon: "scope", label: "Radar") {
                            withAnimation { showRadar.toggle() }
                        }

                        MapActionButton(icon: "map.fill", label: "Style") {
                            cycleMapStyle()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // MARK: - Distance ring (interaction radius indicator)
            if let location = locationService.currentLocation {
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    .frame(width: 100, height: 100) // Visual only
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showCreatureEncounter) {
            if let spawn = selectedSpawn {
                CreatureEncounterView(spawn: spawn)
            }
        }
        .sheet(isPresented: $showTerritoryDetail) {
            if let territory = selectedTerritory {
                TerritoryDetailView(territory: territory)
            }
        }
        .sheet(isPresented: $showNearbyList) {
            NearbyListView(creatures: spawnManager.activeSpawns)
        }
        .onAppear {
            locationService.requestAuthorization()
            locationService.startTracking()
        }
    }

    private func cycleMapStyle() {
        switch mapStyle {
        case .mythic: mapStyle = .satellite
        case .satellite: mapStyle = .standard
        case .standard: mapStyle = .mythic
        }
    }
}

// MARK: - Map View Model

@MainActor
final class MapViewModel: ObservableObject {
    @Published var nearbyTerritories: [Territory] = []
    @Published var nearbyDungeons: [RiftDungeon] = []
    @Published var playerLevel: Int = 1
    @Published var playerXPProgress: Double = 0
    @Published var dailyStreak: Int = 0

    private let network = NetworkService.shared
    private let progression = ProgressionManager.shared

    init() {
        playerLevel = progression.player.level
        playerXPProgress = progression.player.levelProgress
        dailyStreak = progression.player.dailyStreak

        loadNearbyContent()
    }

    func loadNearbyContent() {
        guard let location = LocationService.shared.currentLocation else { return }

        Task {
            do {
                nearbyTerritories = try await network.fetchNearbyTerritories(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: 1000
                )
            } catch {
                // Generate demo territories
                nearbyTerritories = generateDemoTerritories(near: location)
            }

            do {
                nearbyDungeons = try await network.fetchNearbyDungeons(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radius: 2000
                )
            } catch {
                nearbyDungeons = []
            }
        }
    }

    private func generateDemoTerritories(near location: CLLocation) -> [Territory] {
        let offsets: [(Double, Double, String, TerritoryType)] = [
            (0.002, 0.001, "Aegis Outpost", .riftNode),
            (-0.001, 0.003, "Healer's Grove", .sanctuary),
            (0.003, -0.002, "Dragon's Forge", .forge),
            (-0.002, -0.001, "Battle Arena", .arena),
        ]

        return offsets.map { (latOff, lonOff, name, type) in
            Territory(
                id: UUID(),
                name: name,
                location: GeoPoint(
                    latitude: location.coordinate.latitude + latOff,
                    longitude: location.coordinate.longitude + lonOff
                ),
                radius: 75,
                type: type,
                ownerID: nil,
                ownerFaction: [Faction.aether, .umbra, .nexus, nil].randomElement()!,
                guildID: nil,
                defenseLevel: Int.random(in: 1...5),
                defenders: [],
                resources: TerritoryResources(goldPerHour: 50, essencePerHour: 10, essenceType: .norse, riftDustPerHour: 5),
                lastCaptured: nil,
                captureCount: 0,
                structures: []
            )
        }
    }
}

// MARK: - Map Components

struct CreatureMapPin: View {
    let spawn: SpawnEvent
    @State private var pulse = false

    var species: CreatureSpecies? {
        SpeciesDatabase.shared.getSpecies(spawn.speciesID)
    }

    var body: some View {
        ZStack {
            // Glow pulse
            Circle()
                .fill(rarityColor.opacity(0.3))
                .frame(width: pulse ? 55 : 45, height: pulse ? 55 : 45)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            // Pin body
            Circle()
                .fill(
                    LinearGradient(
                        colors: [rarityColor, rarityColor.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(color: rarityColor.opacity(0.5), radius: 5)

            // Creature icon
            Image(systemName: species?.mythology.icon ?? "questionmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            // Shiny indicator
            if spawn.isShiny {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .offset(x: 15, y: -15)
            }

            // Weather boost indicator
            if spawn.weatherBoosted {
                Image(systemName: "cloud.bolt.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.cyan)
                    .offset(x: -15, y: -15)
            }
        }
        .onAppear { pulse = true }
    }

    private var rarityColor: Color {
        species?.rarity.color ?? .gray
    }
}

struct TerritoryMapPin: View {
    let territory: Territory

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(territory.ownerFaction?.color ?? Color.gray.opacity(0.5))
                    .frame(width: 36, height: 36)

                Image(systemName: territoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: (territory.ownerFaction?.color ?? .gray).opacity(0.5), radius: 4)

            // Defense level indicators
            HStack(spacing: 1) {
                ForEach(0..<min(territory.defenseLevel, 5), id: \.self) { _ in
                    Circle()
                        .fill(.white)
                        .frame(width: 3, height: 3)
                }
            }
        }
    }

    private var territoryIcon: String {
        switch territory.type {
        case .riftNode: return "bolt.circle.fill"
        case .sanctuary: return "heart.circle.fill"
        case .forge: return "hammer.circle.fill"
        case .arena: return "figure.fencing"
        case .library: return "book.circle.fill"
        case .market: return "bag.circle.fill"
        case .watchtower: return "eye.circle.fill"
        }
    }
}

struct RiftDungeonMapPin: View {
    let dungeon: RiftDungeon
    @State private var rotate = false

    var body: some View {
        ZStack {
            // Rift swirl effect
            Image(systemName: "hurricane")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [dungeon.mythology.color, .purple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotate)

            // Difficulty indicator
            Text("T\(dungeon.tier)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
        }
        .onAppear { rotate = true }
    }
}

// MARK: - Top Bar

struct MapTopBar: View {
    let playerLevel: Int
    let playerXP: Double
    let dailyStreak: Int
    let nearbyCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Level badge
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                Text("\(playerLevel)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
            }

            // XP bar
            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(playerLevel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.2))
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * playerXP)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: 120)

            Spacer()

            // Streak
            if dailyStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(dailyStreak)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Nearby counter
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(.green)
                Text("\(nearbyCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

// MARK: - Nearby Radar

struct NearbyRadar: View {
    let creatures: [SpawnEvent]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(creatures.prefix(3)) { spawn in
                        let species = SpeciesDatabase.shared.getSpecies(spawn.speciesID)
                        Circle()
                            .fill(species?.rarity.color ?? .gray)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: species?.mythology.icon ?? "questionmark")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                            )
                    }
                    if creatures.count > 3 {
                        Text("+\(creatures.count - 3)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Text("Nearby")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Action Button

struct MapActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
        }
    }
}
