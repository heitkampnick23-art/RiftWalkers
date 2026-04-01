import SwiftUI

// MARK: - Territory Detail View
// Researched: Ingress portal mechanic + Clash of Clans base view.
// Territories are the competitive endgame. Guilds fight for control.

struct TerritoryDetailView: View {
    let territory: Territory

    @StateObject private var economy = EconomyManager.shared
    @State private var showClaimConfirm = false
    @State private var selectedDefenders: [UUID] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [territory.ownerFaction?.color ?? .gray, .black],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 160)

                        VStack(spacing: 8) {
                            Image(systemName: territoryIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(.white)

                            Text(territory.name)
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)

                            HStack(spacing: 12) {
                                Label(territory.type.rawValue.capitalized, systemImage: "mappin")
                                Label("Level \(territory.defenseLevel)", systemImage: "shield.fill")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)

                    // Ownership
                    VStack(spacing: 12) {
                        SectionHeader(title: "Control", icon: "flag.fill")

                        if let faction = territory.ownerFaction {
                            HStack {
                                Image(systemName: faction.icon)
                                    .foregroundStyle(faction.color)
                                Text(faction.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("Captured \(territory.captureCount) times")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.gray)
                                Text("Unclaimed Territory")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    // Resources
                    VStack(spacing: 12) {
                        SectionHeader(title: "Resources", icon: "cube.fill")

                        HStack(spacing: 16) {
                            ResourceCard(
                                icon: "dollarsign.circle.fill",
                                label: "Gold",
                                value: "\(territory.resources.goldPerHour)/hr",
                                color: .yellow
                            )
                            ResourceCard(
                                icon: "sparkle",
                                label: territory.resources.essenceType.rawValue,
                                value: "\(territory.resources.essencePerHour)/hr",
                                color: territory.resources.essenceType.color
                            )
                            ResourceCard(
                                icon: "diamond.fill",
                                label: "Rift Dust",
                                value: "\(territory.resources.riftDustPerHour)/hr",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Structures
                    if !territory.structures.isEmpty {
                        VStack(spacing: 12) {
                            SectionHeader(title: "Structures", icon: "building.2.fill")

                            ForEach(territory.structures) { structure in
                                HStack {
                                    Image(systemName: structureIcon(structure.type))
                                        .foregroundStyle(.cyan)
                                        .frame(width: 30)
                                    VStack(alignment: .leading) {
                                        Text(structure.type.rawValue.capitalized)
                                            .font(.subheadline.weight(.semibold))
                                        Text("Level \(structure.level)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    // Health bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(.gray.opacity(0.3))
                                            Capsule()
                                                .fill(.green)
                                                .frame(width: geo.size.width * Double(structure.health) / Double(structure.maxHealth))
                                        }
                                    }
                                    .frame(width: 60, height: 6)
                                }
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Action button
                    if territory.ownerID == nil {
                        Button(action: { showClaimConfirm = true }) {
                            Label("Claim Territory", systemImage: "flag.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: { showClaimConfirm = true }) {
                            Label("Attack Territory", systemImage: "figure.fencing")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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

    private func structureIcon(_ type: StructureType) -> String {
        switch type {
        case .wall: return "rectangle.3.group.fill"
        case .turret: return "scope"
        case .healingWell: return "cross.circle.fill"
        case .essenceExtractor: return "diamond.fill"
        case .wardStone: return "bell.fill"
        case .portalGate: return "door.left.hand.open"
        }
    }
}

struct NearbyListView: View {
    let creatures: [SpawnEvent]

    var body: some View {
        NavigationStack {
            List {
                ForEach(creatures.filter { !$0.isExpired }) { spawn in
                    if let species = SpeciesDatabase.shared.getSpecies(spawn.speciesID) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(species.rarity.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: species.mythology.icon)
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(species.name)
                                        .font(.subheadline.weight(.semibold))
                                    if spawn.isShiny {
                                        Image(systemName: "sparkles")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                HStack(spacing: 8) {
                                    Label(species.rarity.rawValue, systemImage: "star.fill")
                                        .foregroundStyle(species.rarity.color)
                                    Label(species.element.rawValue, systemImage: species.element.icon)
                                        .foregroundStyle(species.element.color)
                                }
                                .font(.caption)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(timeRemaining(spawn))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange)
                                Text(species.mythology.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nearby Creatures")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func timeRemaining(_ spawn: SpawnEvent) -> String {
        let remaining = spawn.timeRemaining
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
        }
    }
}

struct ResourceCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.weight(.bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
