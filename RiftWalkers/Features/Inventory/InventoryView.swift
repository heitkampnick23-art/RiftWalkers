import SwiftUI

// MARK: - Inventory View
// Researched: Diablo's inventory feel + Pokemon's creature box.
// Two tabs: Items and Creatures. Quick access is critical for mid-gameplay.

struct InventoryView: View {
    @StateObject private var progression = ProgressionManager.shared

    @State private var selectedTab: InventoryTab = .creatures
    @State private var selectedCreature: Creature?
    @State private var sortOption: SortOption = .combatPower
    @State private var filterMythology: Mythology?
    @State private var searchText = ""

    enum InventoryTab: String, CaseIterable {
        case creatures = "Creatures"
        case items = "Items"
    }

    enum SortOption: String, CaseIterable {
        case combatPower = "CP"
        case level = "Level"
        case rarity = "Rarity"
        case recent = "Recent"
        case name = "Name"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(InventoryTab.allCases, id: \.self) { tab in
                        Button(action: { withAnimation { selectedTab = tab } }) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? .blue.opacity(0.3) : .clear)
                        }
                    }
                }
                .background(.ultraThinMaterial)

                switch selectedTab {
                case .creatures:
                    creaturesTab
                case .items:
                    itemsTab
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search...")
        }
    }

    // MARK: - Creatures Tab

    private var creaturesTab: some View {
        VStack(spacing: 0) {
            // Sort & Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Sort picker
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { sortOption = option }
                        }
                    } label: {
                        Label("Sort: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    // Mythology filters
                    ForEach(Mythology.allCases) { myth in
                        Button(action: {
                            filterMythology = filterMythology == myth ? nil : myth
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: myth.icon)
                                Text(myth.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                filterMythology == myth ? myth.color.opacity(0.3) : .clear,
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(myth.color.opacity(0.5), lineWidth: 1))
                        }
                        .foregroundStyle(filterMythology == myth ? .white : .secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Creature collection count
            HStack {
                Text("\(progression.player.creaturesCaught) / \(SpeciesDatabase.shared.species.count) Species")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("CP Range: —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Creature grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ], spacing: 8) {
                    // Demo creatures for layout
                    ForEach(0..<12, id: \.self) { i in
                        CreatureGridCard(index: i)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Items Tab

    private var itemsTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(ItemType.allCases, id: \.self) { category in
                    let items = progression.player.items.filter { $0.type == category }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue.capitalized)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)

                            ForEach(items) { item in
                                ItemRow(item: item)
                            }
                        }
                    }
                }

                if progression.player.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No items yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Explore the world and complete quests to find items!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }
}

// MARK: - Creature Grid Card

struct CreatureGridCard: View {
    let index: Int

    private var demoSpecies: CreatureSpecies? {
        let all = Array(SpeciesDatabase.shared.species.values)
        guard index < all.count else { return nil }
        return all[index]
    }

    var body: some View {
        if let species = demoSpecies {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [species.rarity.color.opacity(0.3), .black.opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 4) {
                        Image(systemName: species.element.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(species.element.color)

                        // Rarity stars
                        HStack(spacing: 1) {
                            ForEach(0..<min(species.rarity.stars, 5), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(species.rarity.color)
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    // Mythology badge
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: species.mythology.icon)
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(species.mythology.color.opacity(0.6), in: Circle())
                        }
                        Spacer()
                    }
                    .padding(4)
                }
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(species.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)

                Text("CP —")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconAsset)
                .font(.title3)
                .foregroundStyle(item.rarity.color)
                .frame(width: 36, height: 36)
                .background(item.rarity.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("x\(item.quantity)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// Make ItemType conform to CaseIterable for filtering
extension ItemType: CaseIterable {
    static var allCases: [ItemType] {
        [.captureSphere, .potion, .revive, .booster, .lure, .incense,
         .evolutionStone, .craftingMaterial, .equipment, .key, .food, .cosmetic]
    }
}
