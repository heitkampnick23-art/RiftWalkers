import SwiftUI

struct PvPMatchmakingView: View {
    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var battle = BattleManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var matchState: MatchState = .selectParty
    @State private var selectedCreatures: [Creature] = []
    @State private var opponent: PvPOpponent?
    @State private var searchProgress: Double = 0
    @State private var searchTimer: Timer?
    @State private var showBattle = false

    enum MatchState {
        case selectParty
        case searching
        case found
        case ready
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch matchState {
                case .selectParty: partySelectionView
                case .searching: searchingView
                case .found: opponentFoundView
                case .ready: readyView
                }
            }
            .navigationTitle("PvP Arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        searchTimer?.invalidate()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showBattle) {
                if let opp = opponent {
                    BattleView()
                        .onAppear {
                            battle.startPvPBattle(
                                playerParty: selectedCreatures,
                                opponentParty: opp.creatures
                            )
                        }
                }
            }
        }
    }

    // MARK: - Party Selection

    private var partySelectionView: some View {
        VStack(spacing: 16) {
            // Rating display
            HStack {
                VStack(alignment: .leading) {
                    Text("Your Rating")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(progression.player.pvpRating)")
                        .font(.title.weight(.black))
                        .foregroundStyle(.orange)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("W/L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(progression.player.pvpWins)/\(progression.player.pvpLosses)")
                        .font(.title3.weight(.bold))
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Instructions
            VStack(spacing: 4) {
                Text("Select Your Team")
                    .font(.headline.weight(.bold))
                Text("Choose up to 3 creatures for battle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Selected party preview
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { idx in
                    if idx < selectedCreatures.count {
                        let creature = selectedCreatures[idx]
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(creature.element.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(creature.element.color, lineWidth: 2)
                                    )
                                VStack(spacing: 2) {
                                    Image(systemName: creature.mythology.icon)
                                        .font(.title2)
                                        .foregroundStyle(creature.element.color)
                                    Text("CP \(creature.combatPower)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                selectedCreatures.removeAll { $0.id == creature.id }
                            }

                            Text(creature.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
            }

            // Creature list
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(progression.ownedCreatures) { creature in
                        let isSelected = selectedCreatures.contains { $0.id == creature.id }
                        Button(action: { toggleCreature(creature) }) {
                            HStack(spacing: 8) {
                                Image(systemName: creature.mythology.icon)
                                    .foregroundStyle(creature.element.color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(creature.displayName)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text("CP \(creature.combatPower) · Lv.\(creature.level)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(10)
                            .background(
                                isSelected ? creature.element.color.opacity(0.15) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Find match button
            Button(action: startSearch) {
                HStack {
                    Image(systemName: "figure.fencing")
                    Text("Find Opponent")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    selectedCreatures.isEmpty ? Color.gray : Color.red,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(selectedCreatures.isEmpty)
        }
        .padding()
    }

    // MARK: - Searching

    private var searchingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(.red.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                        .scaleEffect(1 + searchProgress * 0.15)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: searchProgress)
                }

                Image(systemName: "figure.fencing")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
            }

            Text("Searching for opponent...")
                .font(.title3.weight(.bold))

            Text("Rating range: \(max(0, progression.player.pvpRating - 200)) - \(progression.player.pvpRating + 200)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: searchProgress)
                .tint(.red)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Opponent Found

    private var opponentFoundView: some View {
        VStack(spacing: 20) {
            Spacer()

            if let opp = opponent {
                Text("Opponent Found!")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.red)

                // VS display
                HStack(spacing: 30) {
                    // Player side
                    VStack(spacing: 8) {
                        Circle()
                            .fill(.blue.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            )
                        Text(progression.player.displayName)
                            .font(.caption.weight(.bold))
                        Text("\(progression.player.pvpRating)")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.orange)
                    }

                    Text("VS")
                        .font(.title.weight(.black))
                        .foregroundStyle(.red)

                    // Opponent side
                    VStack(spacing: 8) {
                        Circle()
                            .fill(.red.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: opp.faction.icon)
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            )
                        Text(opp.name)
                            .font(.caption.weight(.bold))
                        Text("\(opp.rating)")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.orange)
                    }
                }

                // Opponent team preview
                HStack(spacing: 8) {
                    ForEach(opp.creatures) { c in
                        VStack(spacing: 2) {
                            Image(systemName: c.mythology.icon)
                                .font(.title3)
                                .foregroundStyle(c.element.color)
                            Text("CP \(c.combatPower)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Spacer()

            Button(action: {
                matchState = .ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showBattle = true
                }
            }) {
                Text("BATTLE!")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack {
            Spacer()
            Text("3")
                .font(.system(size: 80, weight: .black))
                .foregroundStyle(.red)
            Text("Get Ready!")
                .font(.title3.weight(.bold))
            Spacer()
        }
    }

    // MARK: - Logic

    private func toggleCreature(_ creature: Creature) {
        if let idx = selectedCreatures.firstIndex(where: { $0.id == creature.id }) {
            selectedCreatures.remove(at: idx)
        } else if selectedCreatures.count < 3 {
            selectedCreatures.append(creature)
            HapticsService.shared.impact(.light)
        }
    }

    private func startSearch() {
        matchState = .searching
        searchProgress = 0
        HapticsService.shared.impact(.medium)
        AudioService.shared.playSFX(.menuTap)

        // Simulate matchmaking
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            searchProgress += 0.033
            if searchProgress >= 1 {
                timer.invalidate()
                opponent = generateOpponent()
                withAnimation(.spring(response: 0.5)) {
                    matchState = .found
                }
                HapticsService.shared.notification(.success)
                AudioService.shared.playSFX(.creatureAppear)
            }
        }
    }

    private func generateOpponent() -> PvPOpponent {
        let rating = progression.player.pvpRating + Int.random(in: -150...150)
        let names = ["DarkWalker", "MythBreaker", "RiftLord", "PhantomKing",
                     "StormChaser", "NorseViper", "GreekHero", "ShadowMage"]
        let factions = Faction.allCases

        // Generate opponent creatures from SpeciesDatabase
        let speciesList = Array(SpeciesDatabase.shared.species.values)
        var oppCreatures: [Creature] = []
        let count = min(3, max(1, selectedCreatures.count))
        for _ in 0..<count {
            if let sp = speciesList.randomElement() {
                let level = max(1, progression.player.level + Int.random(in: -3...3))
                let creature = Creature(
                    id: UUID(), speciesID: sp.id, name: sp.name,
                    nickname: nil, mythology: sp.mythology, element: sp.element,
                    rarity: sp.rarity, level: level, experience: 0,
                    baseHP: sp.baseHP, baseAttack: sp.baseAttack,
                    baseDefense: sp.baseDefense, baseSpeed: sp.baseSpeed,
                    baseSpecial: sp.baseSpecial,
                    ivHP: Int.random(in: 0...15), ivAttack: Int.random(in: 0...15),
                    ivDefense: Int.random(in: 0...15), ivSpeed: Int.random(in: 0...15),
                    ivSpecial: Int.random(in: 0...15),
                    abilities: [], passiveAbility: nil,
                    currentHP: sp.baseHP + level * 3,
                    statusEffects: [], isShiny: false,
                    captureDate: Date(), captureLocation: GeoPoint(latitude: 0, longitude: 0),
                    evolutionStage: 1, evolutionChainID: sp.evolutionChainID,
                    canEvolve: false, evolutionCost: nil,
                    affection: 0, lastFedDate: nil, lastPlayedDate: nil
                )
                oppCreatures.append(creature)
            }
        }

        return PvPOpponent(
            id: UUID().uuidString,
            name: names.randomElement()!,
            rating: max(100, rating),
            level: max(1, progression.player.level + Int.random(in: -2...2)),
            faction: factions.randomElement()!,
            creatures: oppCreatures
        )
    }
}

// MARK: - PvP Opponent Model

struct PvPOpponent {
    let id: String
    let name: String
    let rating: Int
    let level: Int
    let faction: Faction
    let creatures: [Creature]
}

// MARK: - PvP Rankings View

struct PvPRankingsView: View {
    let player: Player

    var body: some View {
        VStack(spacing: 16) {
            // Rank badge
            VStack(spacing: 8) {
                Image(systemName: rankIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(rankColor)

                Text(rankName)
                    .font(.title2.weight(.black))
                    .foregroundStyle(rankColor)

                Text("\(player.pvpRating) Rating Points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(rankColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            // Season stats
            HStack(spacing: 0) {
                pvpStat(value: "\(player.pvpWins)", label: "Wins", color: .green)
                pvpStat(value: "\(player.pvpLosses)", label: "Losses", color: .red)
                pvpStat(value: winRate, label: "Win Rate", color: .cyan)
                pvpStat(value: "\(player.pvpWins + player.pvpLosses)", label: "Total", color: .orange)
            }

            // Rank tiers
            VStack(alignment: .leading, spacing: 8) {
                Text("Rank Tiers")
                    .font(.subheadline.weight(.bold))

                ForEach(rankTiers, id: \.name) { tier in
                    HStack {
                        Image(systemName: tier.icon)
                            .foregroundStyle(tier.color)
                            .frame(width: 24)
                        Text(tier.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tier.isCurrent ? .white : .secondary)
                        Spacer()
                        Text("\(tier.minRating)+")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        if tier.isCurrent {
                            Image(systemName: "chevron.left")
                                .font(.caption2)
                                .foregroundStyle(tier.color)
                        }
                    }
                    .padding(8)
                    .background(
                        tier.isCurrent ? tier.color.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding()
    }

    private func pvpStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var winRate: String {
        let total = player.pvpWins + player.pvpLosses
        guard total > 0 else { return "—" }
        return "\(Int(Double(player.pvpWins) / Double(total) * 100))%"
    }

    private var rankName: String {
        switch player.pvpRating {
        case 0..<500: return "Bronze"
        case 500..<1000: return "Silver"
        case 1000..<1500: return "Gold"
        case 1500..<2000: return "Platinum"
        case 2000..<2500: return "Diamond"
        default: return "Mythic"
        }
    }

    private var rankIcon: String {
        switch player.pvpRating {
        case 0..<500: return "shield.fill"
        case 500..<1000: return "shield.lefthalf.filled"
        case 1000..<1500: return "crown.fill"
        case 1500..<2000: return "star.circle.fill"
        case 2000..<2500: return "diamond.fill"
        default: return "bolt.shield.fill"
        }
    }

    private var rankColor: Color {
        switch player.pvpRating {
        case 0..<500: return .brown
        case 500..<1000: return .gray
        case 1000..<1500: return .yellow
        case 1500..<2000: return .cyan
        case 2000..<2500: return .purple
        default: return .red
        }
    }

    private var rankTiers: [(name: String, icon: String, color: Color, minRating: Int, isCurrent: Bool)] {
        let rating = player.pvpRating
        return [
            ("Mythic", "bolt.shield.fill", .red, 2500, rating >= 2500),
            ("Diamond", "diamond.fill", .purple, 2000, rating >= 2000 && rating < 2500),
            ("Platinum", "star.circle.fill", .cyan, 1500, rating >= 1500 && rating < 2000),
            ("Gold", "crown.fill", .yellow, 1000, rating >= 1000 && rating < 1500),
            ("Silver", "shield.lefthalf.filled", .gray, 500, rating >= 500 && rating < 1000),
            ("Bronze", "shield.fill", .brown, 0, rating < 500),
        ]
    }
}
