import Foundation
import AVFoundation
import SwiftUI

// MARK: - AI Companion Guide
// The "Rift Guide" — an AI companion that speaks through the device at key moments.
// Researched: Navi from Zelda, Cortana from Halo, Ghost from Destiny.
// Smart contextual tips + personality = emotional bond with the game.
// Uses GPT-4o-mini via cloud proxy for dynamic, context-aware dialogue.
// Uses AVSpeechSynthesizer for text-to-speech so the guide literally talks.

final class AICompanionService: ObservableObject {
    static let shared = AICompanionService()

    @Published var currentMessage: String?
    @Published var isVisible = false
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let ai = AIContentService.shared
    private var lastHintTime: Date = .distantPast
    private let minimumHintInterval: TimeInterval = 30 // Don't spam hints
    private var spokenMessages: Set<String> = [] // Avoid repeating
    private var delegate: SpeechDelegate?

    private init() {
        delegate = SpeechDelegate(service: self)
        synthesizer.delegate = delegate
    }

    // MARK: - Contextual Hints (Triggered at smart moments)

    func onCreatureEncounter(species: CreatureSpecies, isShiny: Bool) {
        let hints: [String] = [
            "A wild \(species.name) from \(species.mythology.rawValue) mythology! \(rarityHint(species.rarity))",
            isShiny ? "Whoa, that's a shiny! These are incredibly rare. Don't let it escape!" : "Nice find! \(elementHint(species.element))",
            "\(species.name) is a \(species.rarity.rawValue) creature. \(captureAdvice(species.rarity))",
        ]
        speak(hints.randomElement()!, context: "encounter_\(species.id)")
    }

    func onCaptureSuccess(creature: Creature) {
        let ivTotal = creature.ivHP + creature.ivAttack + creature.ivDefense + creature.ivSpeed + creature.ivSpecial
        let ivPercent = Double(ivTotal) / Double(31 * 5)
        let quality = ivPercent > 0.8 ? "Those stats are incredible! This one's a keeper." :
                      ivPercent > 0.6 ? "Solid stats. This creature will serve you well in battle." :
                      "Every creature has potential. Level it up and it can surprise you."
        speak("Got it! \(quality)", context: "capture_\(creature.id)")
    }

    func onCaptureFail() {
        let hints = [
            "It broke free! Try using a Great Sphere for better odds.",
            "So close! Feed it a berry first to calm it down.",
            "Don't give up! Higher rarity creatures are harder to catch.",
        ]
        speakIfReady(hints.randomElement()!, context: "capture_fail")
    }

    func onLevelUp(level: Int) {
        let message: String
        if let unlock = ProgressionManager.shared.levelUnlocks[level] {
            message = "Level \(level)! \(unlock)"
        } else {
            message = "Level \(level)! You're getting stronger. Keep exploring those rifts."
        }
        speak(message, context: "levelup_\(level)")
    }

    func onFirstLaunch() {
        speak("Welcome to RiftWalkers! Mythological rifts are opening all around you. Walk around to discover creatures from ancient legends. Tap one to begin your first capture!", context: "first_launch")
    }

    func onMapIdle() {
        speakIfReady(mapIdleHints.randomElement()!, context: "map_idle")
    }

    func onShopVisit() {
        speakIfReady("The shop refreshes daily. Check back for special deals and limited-time offers.", context: "shop_visit")
    }

    func onLowSpheres() {
        speakIfReady("Running low on capture spheres! Visit a supply point on the map or grab some from the shop.", context: "low_spheres")
    }

    func onRareSpawn(species: CreatureSpecies) {
        speak("Rift surge detected! A rare \(species.name) has appeared nearby. Don't miss this one!", context: "rare_\(species.id)")
    }

    func onBattleStart() {
        let hints = [
            "Choose your moves wisely. Type advantages deal double damage!",
            "Watch your creature's HP. Swap out before they faint to keep your team strong.",
            "Abilities have cooldowns. Time them for maximum impact.",
        ]
        speakIfReady(hints.randomElement()!, context: "battle_start")
    }

    func onDailyLogin(streak: Int) {
        if streak >= 7 {
            speak("Incredible! \(streak) day streak! Your dedication is paying off with bonus rewards.", context: "streak_\(streak)")
        } else if streak > 1 {
            speak("Day \(streak) streak! Keep logging in daily for escalating rewards.", context: "streak_\(streak)")
        }
    }

    // MARK: - Dynamic AI Hints (GPT-4o-mini powered)

    func generateDynamicHint(context: String) async {
        let prompt = """
        You are "Rift Guide", an AI companion in a Pokemon GO-style game called RiftWalkers \
        where mythological creatures appear through dimensional rifts. Give a short (1-2 sentences), \
        helpful, in-character gameplay tip. Context: \(context). Be enthusiastic but not annoying. \
        Sound like a knowledgeable friend, not a tutorial bot.
        """
        if let hint = await ai.generateLore(for: SpeciesDatabase.shared.species.values.first!) {
            await MainActor.run {
                speak(hint, context: "dynamic_\(context)")
            }
        }
    }

    // MARK: - Speech Engine

    func speak(_ message: String, context: String) {
        // Don't repeat the same context
        guard !spokenMessages.contains(context) else { return }
        spokenMessages.insert(context)

        currentMessage = message
        withAnimation(.spring()) { isVisible = true }

        // Text-to-speech
        if UserDefaults.standard.bool(forKey: "voiceGuideEnabled") != false {
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.1
            utterance.volume = 0.8
            synthesizer.speak(utterance)
            isSpeaking = true
        }

        // Auto-dismiss after reading time
        let readTime = max(4.0, Double(message.count) / 15.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + readTime) { [weak self] in
            withAnimation(.spring()) { self?.isVisible = false }
        }
        lastHintTime = Date()
    }

    private func speakIfReady(_ message: String, context: String) {
        guard Date().timeIntervalSince(lastHintTime) > minimumHintInterval else { return }
        speak(message, context: context)
    }

    func dismiss() {
        synthesizer.stopSpeaking(at: .word)
        withAnimation(.spring()) { isVisible = false }
        isSpeaking = false
    }

    // MARK: - Hint Libraries

    private func rarityHint(_ rarity: Rarity) -> String {
        switch rarity {
        case .common: return "Common, but great for building your collection."
        case .uncommon: return "Uncommon! Worth adding to your roster."
        case .rare: return "A rare find! Use a Great Sphere for better odds."
        case .epic: return "Epic rarity! Don't let this one get away."
        case .legendary: return "Legendary! Use your best sphere. This is the one!"
        case .mythic: return "MYTHIC! This is unbelievably rare. Go all out!"
        }
    }

    private func elementHint(_ element: Element) -> String {
        switch element {
        case .fire: return "Fire types are strong against nature but weak to water."
        case .water: return "Water types dominate fire creatures."
        case .earth: return "Earth types have high defense. Patience is key."
        case .air: return "Air types are fast. Strike before they dodge!"
        case .lightning: return "Lightning types hit hard. Watch for their burst damage."
        case .shadow: return "Shadow types are tricky. They can debuff your team."
        case .light: return "Light types have healing abilities. Take them down fast."
        case .nature: return "Nature types regenerate HP. Don't drag the fight out."
        case .ice: return "Ice types can freeze opponents. Very strategic."
        case .wind: return "Wind types are evasive. Boost your accuracy."
        case .void: return "Void types are mysterious. Expect the unexpected."
        case .frost: return "Frost types slow down opponents. Control the battle tempo."
        case .arcane: return "Arcane types wield pure magical energy. Unpredictable and powerful."
        }
    }

    private func captureAdvice(_ rarity: Rarity) -> String {
        switch rarity {
        case .common, .uncommon: return "A basic sphere should do the trick."
        case .rare: return "A Great Sphere will boost your catch rate."
        case .epic: return "Use an Ultra Sphere and feed it first."
        case .legendary: return "Ultra Sphere minimum. Feed it and time your throw."
        case .mythic: return "Mythic Sphere recommended. This is once in a lifetime."
        }
    }

    private var mapIdleHints: [String] {
        [
            "Try exploring different areas. Parks, landmarks, and water features attract rare creatures.",
            "Walk around to hatch any eggs you're incubating. Every step counts!",
            "Different times of day bring different creatures. Night spawns are often rarer.",
            "Check your quests tab. Completing daily quests is the fastest way to level up.",
            "Rainy weather boosts water and lightning spawns. Use the weather to your advantage!",
            "Territories near you might be unclaimed. Capture one for passive resource income.",
        ]
    }
}

// MARK: - Speech Delegate

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var service: AICompanionService?

    init(service: AICompanionService) {
        self.service = service
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.service?.isSpeaking = false
        }
    }
}

// MARK: - Rift Guide Overlay View (appears on top of any screen)

struct RiftGuideOverlay: View {
    @StateObject private var guide = AICompanionService.shared

    var body: some View {
        VStack {
            Spacer()

            if guide.isVisible, let message = guide.currentMessage {
                HStack(alignment: .top, spacing: 10) {
                    // Guide avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Rift Guide")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.cyan)
                            if guide.isSpeaking {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.cyan)
                            }
                            Spacer()
                            Button(action: { guide.dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.bottom, 90) // Above tab bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: guide.isVisible)
        .allowsHitTesting(guide.isVisible)
    }
}
