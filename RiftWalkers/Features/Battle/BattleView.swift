import SwiftUI

// MARK: - Battle View
// Researched: Pokemon's turn-based + Genshin's elemental combos.
// UI must show: HP bars, ability cooldowns, elemental reactions, combo counter.
// 60fps animations are critical - battle must FEEL impactful.

struct BattleView: View {
    @StateObject private var battleManager = BattleManager.shared

    @State private var showAbilities = true
    @State private var showItems = false
    @State private var showSwap = false
    @State private var damageFlash = false
    @State private var screenShake: CGFloat = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Battle background
            LinearGradient(
                colors: [.indigo.opacity(0.8), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Enemy Section
                VStack(spacing: 8) {
                    if let enemy = battleManager.activeEnemyCreature {
                        // Enemy info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(enemy.creature.displayName)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)

                                    Image(systemName: enemy.creature.element.icon)
                                        .font(.caption)
                                        .foregroundStyle(enemy.creature.element.color)
                                }

                                Text("Lv.\(enemy.creature.level)  CP \(enemy.creature.combatPower)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            // Status effects
                            HStack(spacing: 4) {
                                ForEach(enemy.statusEffects, id: \.type) { status in
                                    StatusEffectBadge(status: status)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Enemy HP bar
                        HPBar(current: enemy.currentHP, max: enemy.maxHP, color: .red)
                            .padding(.horizontal)

                        // Enemy creature display
                        ZStack {
                            // Element aura
                            Circle()
                                .fill(enemy.creature.element.color.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(systemName: enemy.creature.element.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [enemy.creature.element.color, enemy.creature.mythology.color],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .opacity(damageFlash ? 0.3 : 1.0)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxHeight: .infinity)

                // MARK: - Combo & Reaction Display
                if battleManager.comboCounter > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(battleManager.comboCounter)x COMBO")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .transition(.scale)
                }

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // MARK: - Player Section
                VStack(spacing: 8) {
                    if let player = battleManager.activePlayerCreature {
                        // Player creature display
                        HStack(spacing: 16) {
                            Image(systemName: player.creature.element.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(player.creature.element.color)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(player.creature.displayName)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)

                                    Image(systemName: player.creature.element.icon)
                                        .font(.caption)
                                        .foregroundStyle(player.creature.element.color)
                                }

                                Text("Lv.\(player.creature.level)  CP \(player.creature.combatPower)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))

                                HPBar(current: player.currentHP, max: player.maxHP, color: .green)

                                // Status effects
                                HStack(spacing: 4) {
                                    ForEach(player.statusEffects, id: \.type) { status in
                                        StatusEffectBadge(status: status)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Action Panel
                    if battleManager.battleState == .playerTurn {
                        VStack(spacing: 8) {
                            // Action tabs
                            HStack(spacing: 0) {
                                ActionTab(title: "Abilities", isSelected: showAbilities) {
                                    showAbilities = true; showItems = false; showSwap = false
                                }
                                ActionTab(title: "Items", isSelected: showItems) {
                                    showAbilities = false; showItems = true; showSwap = false
                                }
                                ActionTab(title: "Swap", isSelected: showSwap) {
                                    showAbilities = false; showItems = false; showSwap = true
                                }
                            }

                            if showAbilities, let player = battleManager.activePlayerCreature {
                                // Ability buttons
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(player.creature.abilities) { ability in
                                        AbilityButton(
                                            ability: ability,
                                            cooldown: player.abilityCooldowns[ability.id] ?? 0
                                        ) {
                                            battleManager.useAbility(ability)
                                            triggerDamageFlash()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            if showSwap {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(battleManager.playerCreatures.enumerated()), id: \.element.id) { index, creature in
                                            SwapCreatureCard(creature: creature, isActive: creature.isActive) {
                                                battleManager.swapCreature(to: index)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // Bottom actions
                            HStack(spacing: 12) {
                                Button(action: { battleManager.attemptFlee() }) {
                                    Label("Flee", systemImage: "figure.run")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.white.opacity(0.1), in: Capsule())
                                }

                                Spacer()

                                Button(action: { battleManager.attemptCapture(sphereType: "basic") }) {
                                    Label("Capture", systemImage: "circle.circle")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.cyan.opacity(0.3), in: Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Enemy turn indicator
                    if battleManager.battleState == .enemyTurn || battleManager.battleState == .animating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Enemy's turn...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding()
                    }
                }
                .frame(maxHeight: .infinity)

                // MARK: - Battle Log
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(battleManager.battleLog.suffix(5)) { entry in
                            Text(entry.message)
                                .font(.system(size: 10))
                                .foregroundStyle(logColor(entry.type))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.3), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 30)
                .padding(.bottom, 8)
            }

            // MARK: - Victory / Defeat Overlay
            if battleManager.battleState == .victory {
                BattleResultOverlay(isVictory: true, rewards: battleManager.rewards) {
                    dismiss()
                }
                .transition(.opacity)
            }

            if battleManager.battleState == .defeat {
                BattleResultOverlay(isVictory: false, rewards: nil) {
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .offset(x: screenShake)
    }

    private func triggerDamageFlash() {
        withAnimation(.easeInOut(duration: 0.1)) { damageFlash = true }
        withAnimation(.easeInOut(duration: 0.1).delay(0.1)) { damageFlash = false }

        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { screenShake = 5 }
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3).delay(0.1)) { screenShake = -3 }
        withAnimation(.spring(response: 0.1, dampingFraction: 0.5).delay(0.2)) { screenShake = 0 }
    }

    private func logColor(_ type: BattleManager.BattleLogEntry.LogType) -> Color {
        switch type {
        case .damage: return .red
        case .heal: return .green
        case .status: return .yellow
        case .system: return .white
        case .combo: return .orange
        case .critical: return .yellow
        }
    }
}

// MARK: - HP Bar

struct HPBar: View {
    let current: Int
    let max: Int
    let color: Color

    private var percentage: Double { Double(current) / Double(max) }

    private var barColor: Color {
        if percentage > 0.5 { return .green }
        if percentage > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * max(0, percentage))
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(current)/\(max)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
    }
}

// MARK: - Ability Button

struct AbilityButton: View {
    let ability: Ability
    let cooldown: TimeInterval
    let action: () -> Void

    var isReady: Bool { cooldown <= 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: ability.element.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ability.element.color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(ability.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("PWR \(ability.power)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))

                        if ability.isUltimate {
                            Text("ULT")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Spacer()

                if !isReady {
                    Text("\(Int(cooldown))s")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isReady ? ability.element.color.opacity(0.2) : .white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isReady ? ability.element.color.opacity(0.5) : .white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .disabled(!isReady)
        .opacity(isReady ? 1 : 0.5)
    }
}

// MARK: - Swap Creature Card

struct SwapCreatureCard: View {
    let creature: BattleManager.BattleCreature
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: creature.creature.element.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(creature.creature.element.color)

                Text(creature.creature.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Mini HP bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(creature.hpPercentage > 0.5 ? .green : creature.hpPercentage > 0.25 ? .yellow : .red)
                            .frame(width: geo.size.width * creature.hpPercentage)
                    }
                }
                .frame(height: 4)
            }
            .frame(width: 65)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? .blue.opacity(0.3) : .white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? .blue : .clear, lineWidth: 1)
                    )
            )
        }
        .disabled(isActive || !creature.isAlive)
        .opacity(creature.isAlive ? 1 : 0.3)
    }
}

// MARK: - Status Effect Badge

struct StatusEffectBadge: View {
    let status: StatusEffect

    var body: some View {
        Text(statusIcon)
            .font(.system(size: 12))
            .frame(width: 22, height: 22)
            .background(statusColor.opacity(0.3), in: Circle())
    }

    private var statusIcon: String {
        switch status.type {
        case .burn: return "🔥"
        case .freeze: return "🧊"
        case .poison: return "☠️"
        case .stun: return "⚡"
        case .sleep: return "💤"
        case .confuse: return "😵"
        case .blind: return "🌑"
        case .curse: return "💀"
        case .bless: return "✨"
        case .rage: return "😤"
        }
    }

    private var statusColor: Color {
        switch status.type {
        case .burn: return .red
        case .freeze: return .cyan
        case .poison: return .purple
        case .stun: return .yellow
        case .sleep: return .blue
        case .confuse: return .orange
        case .blind: return .gray
        case .curse: return .indigo
        case .bless: return .yellow
        case .rage: return .red
        }
    }
}

// MARK: - Action Tab

struct ActionTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? .white.opacity(0.1) : .clear)
        }
    }
}

// MARK: - Battle Result Overlay

struct BattleResultOverlay: View {
    let isVictory: Bool
    let rewards: BattleRewards?
    let onDismiss: () -> Void

    @State private var animateIn = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isVictory ? "VICTORY!" : "DEFEAT")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isVictory ? [.yellow, .orange] : [.red, .gray],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .opacity(animateIn ? 1 : 0)

                if isVictory, let rewards = rewards {
                    VStack(spacing: 8) {
                        RewardRow(icon: "star.fill", label: "Experience", value: "+\(rewards.experience)", color: .cyan)
                        RewardRow(icon: "dollarsign.circle.fill", label: "Gold", value: "+\(rewards.gold)", color: .yellow)
                        if !rewards.items.isEmpty {
                            RewardRow(icon: "gift.fill", label: "Items", value: "\(rewards.items.count) items", color: .purple)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .opacity(animateIn ? 1 : 0)
                }

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .padding(.horizontal, 40)
                .opacity(animateIn ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }
}

struct RewardRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
    }
}
