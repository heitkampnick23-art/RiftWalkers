import SwiftUI

// MARK: - Creature Encounter View
// The capture screen. Researched: Pokemon GO's throw mechanic + Genshin's wish animation.
// This is the DOPAMINE MOMENT. Every element must trigger satisfaction:
// - Creature reveal animation (anticipation)
// - Rarity glow effect (surprise)
// - Shake animation (tension)
// - Capture burst (release)
// - Stats reveal (reward)

struct CreatureEncounterView: View {
    let spawn: SpawnEvent

    @StateObject private var spawnManager = SpawnManager.shared
    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var economy = EconomyManager.shared

    @State private var creature: Creature?
    @State private var encounterPhase: EncounterPhase = .appearing
    @State private var selectedSphere: String = "basic"
    @State private var spherePosition: CGSize = .zero
    @State private var isThrowingAnimation = false
    @State private var shakeCount = 0
    @State private var captureResult: CaptureResultState = .none
    @State private var showBattleOption = false
    @State private var creatureOpacity: Double = 0
    @State private var creatureScale: Double = 0.3
    @State private var glowPulse = false
    @State private var particleEmit = false

    @Environment(\.dismiss) private var dismiss

    enum EncounterPhase {
        case appearing, idle, throwing, shaking, captured, escaped, fled
    }

    enum CaptureResultState {
        case none, success, failure
    }

    var species: CreatureSpecies? {
        SpeciesDatabase.shared.getSpecies(spawn.speciesID)
    }

    var body: some View {
        ZStack {
            // Background gradient based on mythology
            LinearGradient(
                colors: [
                    (species?.mythology.color ?? .gray).opacity(0.8),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Info Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    if let species = species {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                ForEach(0..<species.rarity.stars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(species.rarity.color)
                                }
                            }
                            Text(species.mythology.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding()

                Spacer()

                // MARK: - Creature Display
                ZStack {
                    // Rarity glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (species?.rarity.color ?? .white).opacity(glowPulse ? 0.4 : 0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

                    // Mythology rune circle
                    Circle()
                        .stroke(species?.mythology.color.opacity(0.3) ?? .clear, lineWidth: 1)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(glowPulse ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: glowPulse)

                    // Creature visual
                    VStack(spacing: 8) {
                        Image(systemName: species?.element.icon ?? "questionmark.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [species?.element.color ?? .white, species?.mythology.color ?? .gray],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: species?.element.color.opacity(0.5) ?? .clear, radius: 15)

                        if spawn.isShiny {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("SHINY")
                                Image(systemName: "sparkles")
                            }
                            .font(.caption.weight(.black))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .leading, endPoint: .trailing)
                            )
                        }
                    }
                    .scaleEffect(creatureScale)
                    .opacity(creatureOpacity)
                }

                // Creature name and level
                if let creature = creature {
                    VStack(spacing: 4) {
                        Text(creature.name)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            Label("Lv.\(creature.level)", systemImage: "arrow.up.circle")
                            Label("CP \(creature.combatPower)", systemImage: "bolt.fill")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))

                        // Element and type
                        HStack(spacing: 8) {
                            Label(creature.element.rawValue, systemImage: creature.element.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(creature.element.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(creature.element.color.opacity(0.2), in: Capsule())
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer()

                // MARK: - Capture Controls
                if encounterPhase == .idle {
                    VStack(spacing: 16) {
                        // Sphere selector
                        HStack(spacing: 16) {
                            SphereButton(type: "basic", name: "Basic", color: .gray, isSelected: selectedSphere == "basic") {
                                selectedSphere = "basic"
                            }
                            SphereButton(type: "great", name: "Great", color: .blue, isSelected: selectedSphere == "great") {
                                selectedSphere = "great"
                            }
                            SphereButton(type: "ultra", name: "Ultra", color: .purple, isSelected: selectedSphere == "ultra") {
                                selectedSphere = "ultra"
                            }
                        }

                        // Action buttons
                        HStack(spacing: 20) {
                            // Battle button
                            Button(action: { showBattleOption = true }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "figure.fencing")
                                        .font(.title3)
                                    Text("Battle")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 60)
                                .background(.red.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            }

                            // Capture button (main CTA)
                            Button(action: attemptCapture) {
                                VStack(spacing: 4) {
                                    Image(systemName: "circle.circle.fill")
                                        .font(.system(size: 36))
                                    Text("Throw")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 90, height: 80)
                                .background(
                                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                            }

                            // Feed button (increases capture rate)
                            Button(action: feedCreature) {
                                VStack(spacing: 4) {
                                    Image(systemName: "leaf.fill")
                                        .font(.title3)
                                    Text("Feed")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 60)
                                .background(.green.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Flee button
                        Button("Run Away") {
                            dismiss()
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // MARK: - Capture Result
                if captureResult == .success {
                    CaptureSuccessView(creature: creature, species: species)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 40)
                }

                if captureResult == .failure {
                    VStack(spacing: 8) {
                        Text("It broke free!")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.red)
                        Text("Try again or use a better sphere.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { encounterPhase = .idle; captureResult = .none }
                        }
                    }
                }
            }
        }
        .onAppear {
            creature = spawnManager.getCreatureForSpawn(spawn)
            glowPulse = true
            animateAppearance()
        }
    }

    // MARK: - Animations

    private func animateAppearance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
            creatureOpacity = 1
            creatureScale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { encounterPhase = .idle }
        }
    }

    private func attemptCapture() {
        withAnimation { encounterPhase = .throwing }
        HapticsService.shared.sphereShake()

        // Simulate sphere shakes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { encounterPhase = .shaking }

            let shakes = Int.random(in: 1...3)
            for i in 0..<shakes {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                    HapticsService.shared.sphereShake()
                }
            }

            // Result
            let captureChance = calculateCaptureChance()
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(shakes) * 0.6 + 0.5) {
                if Double.random(in: 0...1) < captureChance {
                    withAnimation(.spring()) {
                        captureResult = .success
                        encounterPhase = .captured
                    }
                    HapticsService.shared.captureSuccess()
                    AudioService.shared.playSFX(.creatureCapture)

                    if var captured = creature {
                        spawnManager.markCaptured(spawn.id)
                        progression.addCreature(captured)
                    }
                } else {
                    withAnimation {
                        captureResult = .failure
                        encounterPhase = .escaped
                    }
                    HapticsService.shared.captureFailure()
                    AudioService.shared.playSFX(.creatureEscape)
                }
            }
        }
    }

    private func feedCreature() {
        AudioService.shared.playSFX(.itemUse)
        HapticsService.shared.selection()
    }

    private func calculateCaptureChance() -> Double {
        guard let creature = creature else { return 0.3 }

        let baseRate: Double = {
            switch selectedSphere {
            case "great": return 0.5
            case "ultra": return 0.7
            default: return 0.3
            }
        }()

        let rarityModifier = 1.0 / Double(creature.rarity.stars)
        return min(0.95, baseRate * rarityModifier)
    }
}

// MARK: - Sphere Button

struct SphereButton: View {
    let type: String
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: isSelected ? 2 : 0)
                    )
                    .shadow(color: isSelected ? color : .clear, radius: 5)

                Text(name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.5))
            }
        }
        .animation(.spring(), value: isSelected)
    }
}

// MARK: - Capture Success View

struct CaptureSuccessView: View {
    let creature: Creature?
    let species: CreatureSpecies?

    @State private var showStats = false

    var body: some View {
        VStack(spacing: 12) {
            Text("CAPTURED!")
                .font(.title.weight(.black))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )

            if let creature = creature {
                VStack(spacing: 8) {
                    Text(creature.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    if showStats {
                        // IV quality indicator
                        let ivTotal = creature.ivHP + creature.ivAttack + creature.ivDefense + creature.ivSpeed + creature.ivSpecial
                        let ivPercent = Double(ivTotal) / Double(31 * 5)
                        let quality = ivPercent > 0.8 ? "Amazing!" : ivPercent > 0.6 ? "Strong" : ivPercent > 0.4 ? "Decent" : "OK"

                        Text("Appraisal: \(quality) (\(Int(ivPercent * 100))%)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ivPercent > 0.8 ? .yellow : ivPercent > 0.6 ? .green : .white)

                        HStack(spacing: 16) {
                            StatPill(label: "HP", value: creature.maxHP)
                            StatPill(label: "ATK", value: creature.attack)
                            StatPill(label: "DEF", value: creature.defense)
                            StatPill(label: "SPD", value: creature.speed)
                        }
                    }

                    Text("+100 XP  +25 Gold  +\(creature.rarity.stars * 3) \(creature.mythology.rawValue) Essence")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { showStats = true }
            }
        }
    }
}

struct StatPill: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text("\(value)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 40)
        .padding(.vertical, 4)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}
