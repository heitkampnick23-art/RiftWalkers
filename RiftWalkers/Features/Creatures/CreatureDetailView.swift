import SwiftUI

// MARK: - Creature Detail View
// Full creature profile: card art, stats, abilities, lore, and evolution.
// Tapping a creature in the inventory navigates here.

struct CreatureDetailView: View {
    let creature: Creature
    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var economy = EconomyManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showEvolution = false
    @State private var evolvedCreature: Creature?
    @State private var selectedAbility: Ability?
    @State private var showAbilityDetail = false

    private var species: CreatureSpecies? {
        SpeciesDatabase.shared.getSpecies(creature.speciesID)
    }

    private var currentCreature: Creature {
        progression.getCreature(by: creature.id) ?? creature
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero card art
                heroSection

                // Quick stats bar
                quickStatsBar
                    .padding(.top, -20)

                VStack(spacing: 20) {
                    // Stat breakdown
                    statsSection

                    // Abilities
                    abilitiesSection

                    // Evolution
                    evolutionSection

                    // Lore
                    loreSection

                    // Catch info
                    catchInfoSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(currentCreature.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .fullScreenCover(isPresented: $showEvolution) {
            if let species = species {
                EvolutionView(
                    creature: currentCreature,
                    species: species,
                    onComplete: { evolved in
                        evolvedCreature = evolved
                        showEvolution = false
                    },
                    onCancel: {
                        showEvolution = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAbilityDetail) {
            if let ability = selectedAbility {
                AbilityDetailSheet(ability: ability)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [
                    species?.mythology.color.opacity(0.6) ?? .blue.opacity(0.6),
                    species?.element.color.opacity(0.3) ?? .purple.opacity(0.3),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 400)

            VStack {
                // Large creature card
                if let species = species {
                    CreatureCardView(
                        species: species,
                        creature: currentCreature,
                        isShiny: currentCreature.isShiny,
                        showStats: false,
                        size: .large
                    )
                    .shadow(color: species.rarity.color.opacity(0.6), radius: 20)
                }
            }
            .padding(.bottom, 30)

            // Shiny badge
            if currentCreature.isShiny {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("SHINY")
                    Image(systemName: "sparkles")
                }
                .font(.caption.bold())
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.yellow.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(.yellow.opacity(0.5), lineWidth: 1))
                .offset(y: -10)
            }
        }
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            quickStat(label: "CP", value: "\(currentCreature.combatPower)", color: .yellow)
            quickStat(label: "LV", value: "\(currentCreature.level)", color: .cyan)
            quickStat(label: "HP", value: "\(currentCreature.maxHP)", color: .green)
            quickStat(label: "IV", value: "\(Int(ivPercentage))%", color: ivColor)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func quickStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var ivPercentage: Double {
        let total = Double(currentCreature.ivHP + currentCreature.ivAttack + currentCreature.ivDefense + currentCreature.ivSpeed + currentCreature.ivSpecial)
        return total / 155.0 * 100.0 // 5 stats * 31 max = 155
    }

    private var ivColor: Color {
        switch ivPercentage {
        case 90...100: return .yellow
        case 75..<90: return .green
        case 50..<75: return .cyan
        default: return .gray
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Stats", icon: "chart.bar.fill")

            VStack(spacing: 8) {
                statBar(name: "HP", value: currentCreature.maxHP, base: currentCreature.baseHP, iv: currentCreature.ivHP, color: .green, maxValue: 300)
                statBar(name: "ATK", value: currentCreature.attack, base: currentCreature.baseAttack, iv: currentCreature.ivAttack, color: .red, maxValue: 250)
                statBar(name: "DEF", value: currentCreature.defense, base: currentCreature.baseDefense, iv: currentCreature.ivDefense, color: .blue, maxValue: 250)
                statBar(name: "SPD", value: currentCreature.speed, base: currentCreature.baseSpeed, iv: currentCreature.ivSpeed, color: .orange, maxValue: 250)
                statBar(name: "SPC", value: currentCreature.special, base: currentCreature.baseSpecial, iv: currentCreature.ivSpecial, color: .purple, maxValue: 250)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statBar(name: String, value: Int, base: Int, iv: Int, color: Color, maxValue: Int) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .leading)

            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * CGFloat(value) / CGFloat(maxValue)))
                }
            }
            .frame(height: 8)

            Text("IV:\(iv)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Abilities Section

    private var abilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Abilities", icon: "bolt.fill")

            VStack(spacing: 8) {
                ForEach(currentCreature.abilities) { ability in
                    Button {
                        selectedAbility = ability
                        showAbilityDetail = true
                    } label: {
                        abilityRow(ability: ability, isUltimate: ability.isUltimate)
                    }
                }

                if let passive = currentCreature.passiveAbility {
                    abilityRow(ability: passive, isPassive: true)
                }
            }
        }
    }

    private func abilityRow(ability: Ability, isUltimate: Bool = false, isPassive: Bool = false) -> some View {
        HStack(spacing: 12) {
            // Element icon
            Image(systemName: ability.element.icon)
                .font(.title3)
                .foregroundStyle(ability.element.color)
                .frame(width: 36, height: 36)
                .background(ability.element.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ability.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if isUltimate {
                        Text("ULT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.yellow.opacity(0.2), in: Capsule())
                    }
                    if isPassive {
                        Text("PASSIVE")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.cyan.opacity(0.2), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if ability.power > 0 {
                        Label("\(ability.power)", systemImage: "flame")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Label("\(Int(ability.accuracy * 100))%", systemImage: "target")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Label(String(format: "%.1fs", ability.cooldown), systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isPassive {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Evolution Section

    private var evolutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Evolution", icon: "arrow.triangle.2.circlepath")

            if let species = species, let evolvedID = species.evolvesInto,
               let evolvedSpecies = SpeciesDatabase.shared.getSpecies(evolvedID) {

                VStack(spacing: 16) {
                    // Evolution chain visual
                    HStack(spacing: 16) {
                        // Current form
                        VStack(spacing: 4) {
                            Image(systemName: species.element.icon)
                                .font(.title)
                                .foregroundStyle(species.element.color)
                                .frame(width: 60, height: 60)
                                .background(species.element.color.opacity(0.15), in: Circle())
                            Text(species.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Stage \(species.evolutionStage)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        // Arrow
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(species.mythology.color)
                            if let cost = currentCreature.evolutionCost {
                                Text("Lv.\(cost.requiredLevel)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.cyan)
                            }
                        }

                        // Evolved form
                        VStack(spacing: 4) {
                            Image(systemName: evolvedSpecies.element.icon)
                                .font(.title)
                                .foregroundStyle(evolvedSpecies.element.color)
                                .frame(width: 60, height: 60)
                                .background(evolvedSpecies.element.color.opacity(0.15), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(evolvedSpecies.rarity.color.opacity(0.5), lineWidth: 2)
                                )
                            Text(evolvedSpecies.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            HStack(spacing: 2) {
                                ForEach(0..<evolvedSpecies.rarity.starCount, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(evolvedSpecies.rarity.color)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Cost breakdown
                    if let cost = currentCreature.evolutionCost {
                        VStack(spacing: 6) {
                            costRow(
                                icon: "arrow.up.circle.fill",
                                label: "Level Required",
                                value: "\(cost.requiredLevel)",
                                met: currentCreature.level >= cost.requiredLevel,
                                current: "\(currentCreature.level)"
                            )
                            costRow(
                                icon: "dollarsign.circle.fill",
                                label: "Gold",
                                value: "\(cost.goldCost)",
                                met: economy.gold >= cost.goldCost,
                                current: "\(economy.gold)"
                            )
                            costRow(
                                icon: species.mythology.icon,
                                label: "\(species.mythology.rawValue) Essence",
                                value: "\(cost.essenceCost)",
                                met: (economy.essences[species.mythology] ?? 0) >= cost.essenceCost,
                                current: "\(economy.essences[species.mythology] ?? 0)"
                            )
                        }
                    }

                    // Evolve button
                    let check = progression.canEvolveCreature(currentCreature)
                    Button {
                        showEvolution = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("EVOLVE")
                                .font(.headline.weight(.black))
                            Image(systemName: "sparkles")
                        }
                        .foregroundStyle(check.canEvolve ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            check.canEvolve
                                ? LinearGradient(colors: [species.mythology.color, species.element.color], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .disabled(!check.canEvolve)

                    if let reason = check.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            } else {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Final Form")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("This creature has reached its ultimate form.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func costRow(icon: String, label: String, value: String, met: Bool, current: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(met ? .green : .red)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(current) / \(value)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(met ? .green : .red)

            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(met ? .green : .red)
        }
    }

    // MARK: - Lore Section

    private var loreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Lore", icon: "book.fill")

            VStack(alignment: .leading, spacing: 8) {
                if let species = species {
                    Text(species.lore)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)

                    HStack(spacing: 12) {
                        Label(species.mythology.rawValue, systemImage: species.mythology.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(species.mythology.color)

                        Label(species.element.rawValue.capitalized, systemImage: species.element.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(species.element.color)

                        Label(species.rarity.rawValue.capitalized, systemImage: "star.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(species.rarity.color)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Catch Info Section

    private var catchInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Catch Info", icon: "mappin.and.ellipse")

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Caught", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentCreature.captureDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label("Affection", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Text("\(currentCreature.affection) / 255")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.7))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Ability Detail Sheet

struct AbilityDetailSheet: View {
    let ability: Ability
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: ability.element.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(ability.element.color)
                    .frame(width: 100, height: 100)
                    .background(ability.element.color.opacity(0.15), in: Circle())
                    .shadow(color: ability.element.color.opacity(0.5), radius: 15)

                // Name
                VStack(spacing: 4) {
                    Text(ability.name)
                        .font(.title2.weight(.black))
                    HStack(spacing: 6) {
                        Text(ability.element.rawValue.capitalized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ability.element.color)
                        if ability.isUltimate {
                            Text("ULTIMATE")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow.opacity(0.2), in: Capsule())
                        }
                    }
                }

                // Description
                Text(ability.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Stats grid
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Power")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(ability.power > 0 ? "\(ability.power)" : "—")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.orange)
                    }

                    VStack(spacing: 4) {
                        Text("Accuracy")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("\(Int(ability.accuracy * 100))%")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 4) {
                        Text("Cooldown")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fs", ability.cooldown))
                            .font(.title3.weight(.black))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(.top, 30)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
