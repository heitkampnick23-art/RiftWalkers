import Foundation
import AVFoundation
import SwiftUI

// MARK: - AI Companion Guide (v2 — ElevenLabs Voice + Conversational AI)
// The "Rift Guide" — Professor Valen, an AI companion who SPEAKS to you.
// v2 upgrades: ElevenLabs high-quality voice, conversational GPT-4o-mini chat,
// location-aware ambient narration, and emotional memory.

final class AICompanionService: ObservableObject {
    static let shared = AICompanionService()

    @Published var currentMessage: String?
    @Published var isVisible = false
    @Published var isSpeaking = false
    @Published var isThinking = false
    @Published var chatHistory: [CompanionMessage] = []
    @Published var isChatOpen = false

    private let voice = VoiceService.shared
    private let ai = AIContentService.shared
    private var lastHintTime: Date = .distantPast
    private let minimumHintInterval: TimeInterval = 30
    private var spokenMessages: Set<String> = []
    private var conversationHistory: [[String: String]] = []

    private let proxyBaseURL = "https://riftwalkers-api.heitkampnick23.workers.dev"
    private let session = URLSession.shared

    // Location-aware narration
    private var lastNarrationLocation: (lat: Double, lng: Double)?
    private var narrationCooldown: Date = .distantPast

    struct CompanionMessage: Identifiable {
        let id = UUID()
        let text: String
        let isPlayer: Bool
        let timestamp: Date
    }

    private init() {}

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
        speak(message, context: "levelup_\(level)", priority: .important)
    }

    func onFirstLaunch() {
        speak("Welcome to RiftWalkers! Mythological rifts are opening all around you. Walk around to discover creatures from ancient legends. Tap one to begin your first capture!", context: "first_launch", priority: .critical)
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
        speak("Rift surge detected! A rare \(species.name) has appeared nearby. Don't miss this one!", context: "rare_\(species.id)", priority: .important)
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

    // MARK: - Location-Aware Ambient Narration

    func onLocationUpdate(latitude: Double, longitude: Double, mythology: Mythology?) {
        // Only narrate if moved significantly (200m+) and not too recently
        guard Date().timeIntervalSince(narrationCooldown) > 120 else { return }

        if let last = lastNarrationLocation {
            let distance = haversineDistance(lat1: last.lat, lng1: last.lng, lat2: latitude, lng2: longitude)
            guard distance > 200 else { return }
        }

        lastNarrationLocation = (latitude, longitude)
        narrationCooldown = Date()

        let hour = Calendar.current.component(.hour, from: Date())
        let timeContext: String
        switch hour {
        case 5..<8: timeContext = "dawn"
        case 8..<12: timeContext = "morning"
        case 12..<17: timeContext = "afternoon"
        case 17..<20: timeContext = "dusk"
        case 20..<23: timeContext = "evening"
        default: timeContext = "night"
        }

        Task {
            await generateAmbientNarration(mythology: mythology, timeOfDay: timeContext)
        }
    }

    private func generateAmbientNarration(mythology: Mythology?, timeOfDay: String) async {
        let mythStr = mythology?.rawValue ?? "mixed"
        let player = await MainActor.run { ProgressionManager.shared.player }
        let context: [String: Any] = [
            "playerLevel": player.level,
            "creaturesOwned": player.creaturesCaught,
            "currentMythology": mythStr,
            "timeOfDay": timeOfDay,
            "recentEvent": "exploring"
        ]

        let prompts = [
            "Comment briefly on the \(timeOfDay) rift energy in this \(mythStr) territory.",
            "Share a quick mythological fact about \(mythStr) creatures that appear at \(timeOfDay).",
            "Give a short ambient observation about the rift activity nearby.",
        ]

        if let response = await askCompanionAPI(message: prompts.randomElement()!, context: context) {
            await MainActor.run {
                speak(response, context: "ambient_\(Date().timeIntervalSince1970)", priority: .ambient)
            }
        }
    }

    // MARK: - Conversational AI (Ask Professor Valen)

    func askQuestion(_ question: String) async -> String? {
        await MainActor.run {
            isThinking = true
            chatHistory.append(CompanionMessage(text: question, isPlayer: true, timestamp: Date()))
        }

        let context = buildGameContext()
        let response = await askCompanionAPI(message: question, context: context)

        await MainActor.run {
            isThinking = false
            if let response {
                chatHistory.append(CompanionMessage(text: response, isPlayer: false, timestamp: Date()))
                speak(response, context: "chat_\(Date().timeIntervalSince1970)")
            }
        }

        return response
    }

    private func askCompanionAPI(message: String, context: [String: Any]) async -> String? {
        guard let url = URL(string: "\(proxyBaseURL)/v1/companion/chat") else {
            print("[Companion] Invalid URL")
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            // Convert ArraySlice to Array to prevent JSONSerialization crash
            let recentHistory = Array(conversationHistory.suffix(6))

            let body: [String: Any] = [
                "message": message,
                "context": context,
                "history": recentHistory
            ]

            guard JSONSerialization.isValidJSONObject(body) else {
                print("[Companion] Invalid JSON body")
                return nil
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, resp) = try await session.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                print("[Companion] API returned status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                // Track conversation
                conversationHistory.append(["role": "user", "content": message])
                conversationHistory.append(["role": "assistant", "content": response])
                if conversationHistory.count > 20 { conversationHistory.removeFirst(2) }
                return response
            }
        } catch {
            print("[Companion] Chat failed: \(error)")
        }
        return nil
    }

    private func buildGameContext() -> [String: Any] {
        let player = ProgressionManager.shared.player
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        return [
            "playerLevel": player.level,
            "creaturesOwned": player.creaturesCaught,
            "timeOfDay": timeOfDay,
        ]
    }

    // MARK: - Speech Engine (now uses VoiceService)

    func speak(_ message: String, context: String, priority: VoiceService.VoicePriority = .normal) {
        guard !spokenMessages.contains(context) else { return }
        spokenMessages.insert(context)

        currentMessage = message
        withAnimation(.spring()) { isVisible = true }
        isSpeaking = true

        // Use ElevenLabs voice
        if UserDefaults.standard.bool(forKey: "voiceGuideEnabled") != false {
            voice.speak(message, priority: priority)
        }

        // Auto-dismiss after reading time
        let readTime = max(4.0, Double(message.count) / 15.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + readTime) { [weak self] in
            withAnimation(.spring()) { self?.isVisible = false }
            self?.isSpeaking = false
        }
        lastHintTime = Date()
    }

    private func speakIfReady(_ message: String, context: String) {
        guard Date().timeIntervalSince(lastHintTime) > minimumHintInterval else { return }
        speak(message, context: context)
    }

    func dismiss() {
        voice.stopSpeaking()
        withAnimation(.spring()) { isVisible = false }
        isSpeaking = false
    }

    // MARK: - Dynamic AI Hints (GPT-4o-mini powered)

    func generateDynamicHint(context: String) async {
        let ctx = buildGameContext()
        if let hint = await askCompanionAPI(message: "Give a gameplay tip. Context: \(context)", context: ctx) {
            await MainActor.run {
                speak(hint, context: "dynamic_\(context)")
            }
        }
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

    // MARK: - Haversine Distance

    private func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng/2) * sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
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
                            Text("Professor Valen")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.cyan)
                            if guide.isSpeaking {
                                Image(systemName: "waveform")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.cyan)
                                    .symbolEffect(.variableColor.iterative)
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
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: guide.isVisible)
        .allowsHitTesting(guide.isVisible)
    }
}

// MARK: - Companion Chat View (Full Conversation Screen)

struct CompanionChatView: View {
    @StateObject private var companion = AICompanionService.shared
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if companion.chatHistory.isEmpty {
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    Text("Professor Valen")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text("Your Rift Guide — ask me anything about creatures, strategy, mythology, or the rifts.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)

                                    // Quick questions
                                    VStack(spacing: 8) {
                                        QuickQuestion("What should I evolve next?")
                                        QuickQuestion("Tell me about Norse mythology")
                                        QuickQuestion("Best strategy for PvP?")
                                        QuickQuestion("What creatures are rare nearby?")
                                    }
                                }
                                .padding(.top, 40)
                            }

                            ForEach(companion.chatHistory) { msg in
                                ChatMessageBubble(message: msg)
                                    .id(msg.id)
                            }

                            if companion.isThinking {
                                HStack {
                                    ThinkingDots()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("thinking")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: companion.chatHistory.count) { _, _ in
                        if let last = companion.chatHistory.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: companion.isThinking) { _, thinking in
                        if thinking {
                            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                        }
                    }
                }

                // Input bar
                HStack(spacing: 10) {
                    TextField("Ask Professor Valen...", text: $inputText)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .focused($isInputFocused)
                        .onSubmit { sendMessage() }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.cyan)
                    }
                    .disabled(inputText.isEmpty || companion.isThinking)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Professor Valen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        Task {
            _ = await companion.askQuestion(text)
        }
    }

    @ViewBuilder
    private func QuickQuestion(_ text: String) -> some View {
        Button {
            guard !companion.isThinking else { return }
            Task {
                _ = await companion.askQuestion(text)
            }
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(.cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.cyan.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(.cyan.opacity(0.3), lineWidth: 1))
        }
        .disabled(companion.isThinking)
    }
}

// MARK: - Chat Bubble

private struct ChatMessageBubble: View {
    let message: AICompanionService.CompanionMessage

    var body: some View {
        HStack {
            if message.isPlayer { Spacer(minLength: 60) }

            VStack(alignment: message.isPlayer ? .trailing : .leading, spacing: 4) {
                if !message.isPlayer {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8))
                            .foregroundStyle(.cyan)
                        Text("Professor Valen")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        message.isPlayer
                            ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }

            if !message.isPlayer { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Thinking Dots Animation

private struct ThinkingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 8))
                .foregroundStyle(.cyan)
            ForEach(0..<3) { i in
                Circle()
                    .fill(.cyan)
                    .frame(width: 6, height: 6)
                    .opacity(animate ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: animate)
            }
        }
        .padding(12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .onAppear { animate = true }
    }
}
