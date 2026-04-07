import SwiftUI

// MARK: - Evolution View
// Full-screen dramatic evolution animation sequence.
// Researched: Pokemon's evolution animation is iconic because it builds anticipation.
// Phases: Confirm → Energy buildup → Flash → Reveal new form → Stats comparison.

struct EvolutionView: View {
    let creature: Creature
    let species: CreatureSpecies
    let onComplete: (Creature) -> Void
    let onCancel: () -> Void

    @StateObject private var progression = ProgressionManager.shared
    @State private var phase: EvolutionPhase = .confirm
    @State private var energyPulse: CGFloat = 1.0
    @State private var energyOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var particleScale: CGFloat = 0.5
    @State private var rotationAngle: Double = 0
    @State private var glowRadius: CGFloat = 5
    @State private var newFormOpacity: Double = 0
    @State private var statsRevealed = false
    @State private var evolvedCreature: Creature?
    @State private var shakeOffset: CGFloat = 0

    private var evolvedSpecies: CreatureSpecies? {
        guard let evolvedID = species.evolvesInto else { return nil }
        return SpeciesDatabase.shared.getSpecies(evolvedID)
    }

    enum EvolutionPhase {
        case confirm, charging, transforming, flash, reveal, stats
    }

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            switch phase {
            case .confirm:
                confirmPhase
                    .transition(.opacity)
            case .charging:
                chargingPhase
                    .transition(.opacity)
            case .transforming:
                transformingPhase
                    .transition(.opacity)
            case .flash:
                flashPhase
            case .reveal:
                revealPhase
                    .transition(.opacity)
            case .stats:
                statsPhase
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(phase != .confirm)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black

            // Mythology-colored nebula background
            RadialGradient(
                colors: [
                    species.mythology.color.opacity(phase == .confirm ? 0.1 : 0.3),
                    species.element.color.opacity(0.1),
                    .clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )

            // Animated particles during evolution
            if phase == .charging || phase == .transforming {
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(species.mythology.color.opacity(0.6))
                        .frame(width: CGFloat.random(in: 3...8))
                        .offset(
                            x: cos(Double(i) * .pi / 6 + rotationAngle) * 120 * particleScale,
                            y: sin(Double(i) * .pi / 6 + rotationAngle) * 120 * particleScale
                        )
                        .blur(radius: 2)
                }
            }

            // White flash overlay
            Color.white
                .opacity(flashOpacity)
        }
    }

    // MARK: - Confirm Phase

    private var confirmPhase: some View {
        VStack(spacing: 30) {
            Spacer()

            // Current creature
            VStack(spacing: 12) {
                Image(systemName: species.element.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(colors: [species.element.color, .white], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: species.element.color, radius: 20)

                Text(creature.displayName)
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)

                HStack(spacing: 2) {
                    ForEach(0..<species.rarity.starCount, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(species.rarity.color)
                    }
                }
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.title.weight(.bold))
                .foregroundStyle(species.mythology.color)
                .padding(.vertical, 8)

            // Evolution target
            if let evolved = evolvedSpecies {
                VStack(spacing: 12) {
                    Image(systemName: evolved.element.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(evolved.element.color.opacity(0.5))
                        .overlay(
                            Image(systemName: "questionmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        )

                    Text("???")
                        .font(.title.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 2) {
                        ForEach(0..<evolved.rarity.starCount, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(evolved.rarity.color.opacity(0.5))
                        }
                    }
                }
            }

            Spacer()

            // Cost summary
            if let cost = creature.evolutionCost {
                HStack(spacing: 20) {
                    Label("\(cost.goldCost) Gold", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)

                    Label("\(cost.essenceCost) Essence", systemImage: species.mythology.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(species.mythology.color)
                }
            }

            // Buttons
            VStack(spacing: 12) {
                Button {
                    startEvolution()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("BEGIN EVOLUTION")
                            .font(.headline.weight(.black))
                        Image(systemName: "sparkles")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [species.mythology.color, species.element.color],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: species.mythology.color.opacity(0.5), radius: 10)
                }

                Button("Cancel") {
                    onCancel()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Charging Phase

    private var chargingPhase: some View {
        VStack {
            Spacer()

            ZStack {
                // Pulsing energy rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(species.mythology.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i) * 60)
                        .scaleEffect(energyPulse)
                        .opacity(energyOpacity)
                }

                // Creature silhouette shaking
                Image(systemName: species.element.icon)
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(colors: [species.element.color, .white], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: species.element.color, radius: glowRadius)
                    .offset(x: shakeOffset)
            }

            Spacer()

            Text("Evolving...")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(energyOpacity))
                .padding(.bottom, 80)
        }
    }

    // MARK: - Transforming Phase

    private var transformingPhase: some View {
        VStack {
            Spacer()

            ZStack {
                // Bright glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [species.mythology.color, species.element.color.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .scaleEffect(energyPulse)

                // Morphing silhouette
                Image(systemName: species.element.icon)
                    .font(.system(size: 100))
                    .foregroundStyle(.white)
                    .blur(radius: 10)
                    .scaleEffect(energyPulse)
            }

            Spacer()
        }
    }

    // MARK: - Flash Phase

    private var flashPhase: some View {
        Color.clear
    }

    // MARK: - Reveal Phase

    private var revealPhase: some View {
        VStack(spacing: 20) {
            Spacer()

            if let evolved = evolvedSpecies {
                // New form reveal
                VStack(spacing: 16) {
                    Image(systemName: evolved.element.icon)
                        .font(.system(size: 120))
                        .foregroundStyle(
                            LinearGradient(colors: [evolved.element.color, .white], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: evolved.element.color, radius: 30)
                        .opacity(newFormOpacity)
                        .scaleEffect(newFormOpacity)

                    Text(evolved.name)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                        .opacity(newFormOpacity)

                    HStack(spacing: 3) {
                        ForEach(0..<evolved.rarity.starCount, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundStyle(evolved.rarity.color)
                        }
                    }
                    .opacity(newFormOpacity)

                    Text(evolved.rarity.rawValue.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(4)
                        .foregroundStyle(evolved.rarity.color)
                        .opacity(newFormOpacity)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .stats
                }
            } label: {
                Text("View Stats")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
            .opacity(newFormOpacity)
        }
    }

    // MARK: - Stats Phase

    private var statsPhase: some View {
        VStack(spacing: 20) {
            Spacer()

            if let evolved = evolvedSpecies {
                Text("Evolution Complete!")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                // Before vs After comparison
                VStack(spacing: 12) {
                    HStack {
                        Text(species.name)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("STAT")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 40)
                        Text(evolved.name)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(evolved.rarity.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    statCompareRow("HP", before: species.baseHP, after: evolved.baseHP)
                    statCompareRow("ATK", before: species.baseAttack, after: evolved.baseAttack)
                    statCompareRow("DEF", before: species.baseDefense, after: evolved.baseDefense)
                    statCompareRow("SPD", before: species.baseSpeed, after: evolved.baseSpeed)
                    statCompareRow("SPC", before: species.baseSpecial, after: evolved.baseSpecial)

                    Divider().background(.white.opacity(0.2))

                    let totalBefore = species.baseHP + species.baseAttack + species.baseDefense + species.baseSpeed + species.baseSpecial
                    let totalAfter = evolved.baseHP + evolved.baseAttack + evolved.baseDefense + evolved.baseSpeed + evolved.baseSpecial
                    statCompareRow("TOTAL", before: totalBefore, after: totalAfter)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .opacity(statsRevealed ? 1 : 0)
                .offset(y: statsRevealed ? 0 : 20)
            }

            Spacer()

            Button {
                if let evolved = evolvedCreature {
                    onComplete(evolved)
                } else {
                    onCancel()
                }
            } label: {
                Text("AWESOME!")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [evolvedSpecies?.rarity.color ?? .purple, species.mythology.color],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                statsRevealed = true
            }
        }
    }

    private func statCompareRow(_ label: String, before: Int, after: Int) -> some View {
        HStack {
            Text("\(before)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 40)

            HStack(spacing: 4) {
                Text("\(after)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                if after > before {
                    Text("+\(after - before)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Animation Sequence

    private func startEvolution() {
        // Actually perform the evolution
        evolvedCreature = progression.evolveCreature(id: creature.id)
        guard evolvedCreature != nil else {
            onCancel()
            return
        }

        // Phase 1: Charging (2 seconds)
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = .charging
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            energyPulse = 1.3
            energyOpacity = 1.0
        }

        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = .pi * 2
        }

        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowRadius = 30
        }

        // Shake effect
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if phase == .charging || phase == .transforming {
                shakeOffset = CGFloat.random(in: -4...4)
            } else {
                shakeOffset = 0
                timer.invalidate()
            }
        }

        // Phase 2: Transforming (1.5 seconds after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .transforming
            }

            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                energyPulse = 1.8
            }

            withAnimation(.easeInOut(duration: 0.5)) {
                particleScale = 0.1
            }
        }

        // Phase 3: Flash (3 seconds after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            phase = .flash
            withAnimation(.easeIn(duration: 0.15)) {
                flashOpacity = 1.0
            }
        }

        // Phase 4: Reveal (3.5 seconds after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                flashOpacity = 0
            }

            phase = .reveal
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                newFormOpacity = 1.0
            }
        }
    }
}
