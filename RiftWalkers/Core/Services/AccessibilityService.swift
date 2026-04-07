import Foundation
import UIKit
import Accessibility
import Speech
import AVFoundation
import CoreLocation
import CoreHaptics
import Combine

// MARK: - Accessibility Service
// Feature #10: Accessibility features for inclusive gameplay.
// Researched: Xbox Adaptive Controller success + Apple's accessibility-first philosophy.
// Key insight: ~15% of players have some disability. Accessibility features also help
// ALL players — voice control is great while walking, haptic-only mode saves battery,
// and remote play helps rural players with no POIs nearby.

final class AccessibilityService: ObservableObject {
    static let shared = AccessibilityService()

    // MARK: - Published State (all @AppStorage backed)

    @Published var isRemotePlayEnabled: Bool {
        didSet { UserDefaults.standard.set(isRemotePlayEnabled, forKey: StorageKey.remotePlay) }
    }
    @Published var isVoiceControlEnabled: Bool {
        didSet { UserDefaults.standard.set(isVoiceControlEnabled, forKey: StorageKey.voiceControl) }
    }
    @Published var isHapticOnlyMode: Bool {
        didSet { UserDefaults.standard.set(isHapticOnlyMode, forKey: StorageKey.hapticOnly) }
    }
    @Published var isReducedMotion: Bool {
        didSet { UserDefaults.standard.set(isReducedMotion, forKey: StorageKey.reducedMotion) }
    }
    @Published var textScale: Double {
        didSet { UserDefaults.standard.set(textScale, forKey: StorageKey.textScale) }
    }
    @Published var isHighContrast: Bool {
        didSet { UserDefaults.standard.set(isHighContrast, forKey: StorageKey.highContrast) }
    }

    // Remote Play
    @Published var virtualExploreLocation: CLLocationCoordinate2D?
    @Published var virtualSpawns: [VirtualSpawn] = []

    // Voice Control
    @Published var isListening: Bool = false
    @Published var lastRecognizedCommand: String = ""

    // MARK: - Models

    struct VirtualSpawn: Identifiable {
        let id: UUID
        let speciesId: String
        let coordinate: CLLocationCoordinate2D
        let spawnedAt: Date
        let expiresAt: Date

        init(
            id: UUID = UUID(),
            speciesId: String,
            coordinate: CLLocationCoordinate2D,
            spawnedAt: Date = Date(),
            expiresAt: Date = Date().addingTimeInterval(900) // 15 minutes
        ) {
            self.id = id
            self.speciesId = speciesId
            self.coordinate = coordinate
            self.spawnedAt = spawnedAt
            self.expiresAt = expiresAt
        }
    }

    struct VoiceCommand {
        let keyword: String
        let aliases: [String]
        let action: () -> Void
    }

    // MARK: - High Contrast Color Palettes

    struct HighContrastPalette {
        let background: (red: Double, green: Double, blue: Double)
        let foreground: (red: Double, green: Double, blue: Double)
        let accent: (red: Double, green: Double, blue: Double)
        let warning: (red: Double, green: Double, blue: Double)
        let success: (red: Double, green: Double, blue: Double)
    }

    var currentPalette: HighContrastPalette {
        if isHighContrast {
            return HighContrastPalette(
                background: (red: 0.0, green: 0.0, blue: 0.0),
                foreground: (red: 1.0, green: 1.0, blue: 1.0),
                accent: (red: 0.0, green: 0.8, blue: 1.0),
                warning: (red: 1.0, green: 0.8, blue: 0.0),
                success: (red: 0.0, green: 1.0, blue: 0.4)
            )
        } else {
            return HighContrastPalette(
                background: (red: 0.06, green: 0.06, blue: 0.12),
                foreground: (red: 0.9, green: 0.9, blue: 0.95),
                accent: (red: 0.4, green: 0.5, blue: 1.0),
                warning: (red: 1.0, green: 0.6, blue: 0.2),
                success: (red: 0.3, green: 0.85, blue: 0.5)
            )
        }
    }

    // MARK: - Private State

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var hapticEngine: CHHapticEngine?
    private var registeredCommands: [VoiceCommand] = []
    private var commandActionHandlers: [String: () -> Void] = [:]
    private var cancellables = Set<AnyCancellable>()

    // UserDefaults keys
    private enum StorageKey {
        static let remotePlay = "accessibility_remotePlay"
        static let voiceControl = "accessibility_voiceControl"
        static let hapticOnly = "accessibility_hapticOnly"
        static let reducedMotion = "accessibility_reducedMotion"
        static let textScale = "accessibility_textScale"
        static let highContrast = "accessibility_highContrast"
    }

    // MARK: - Init

    private init() {
        // Load persisted settings
        let defaults = UserDefaults.standard
        self.isRemotePlayEnabled = defaults.bool(forKey: StorageKey.remotePlay)
        self.isVoiceControlEnabled = defaults.bool(forKey: StorageKey.voiceControl)
        self.isHapticOnlyMode = defaults.bool(forKey: StorageKey.hapticOnly)
        self.isReducedMotion = defaults.bool(forKey: StorageKey.reducedMotion)
        self.textScale = max(1.0, min(2.0, defaults.double(forKey: StorageKey.textScale)))
        self.isHighContrast = defaults.bool(forKey: StorageKey.highContrast)

        // Default text scale to 1.0 if never set
        if self.textScale < 1.0 {
            self.textScale = 1.0
        }

        setupHapticEngine()
        registerDefaultVoiceCommands()
    }

    deinit {
        stopListening()
    }

    // MARK: - Remote Play Mode

    /// Starts remote play by setting a virtual exploration location.
    /// Allows exploring a virtual neighborhood from home for players who cannot walk.
    func startRemotePlay(at location: CLLocationCoordinate2D? = nil) {
        isRemotePlayEnabled = true

        if let location = location {
            virtualExploreLocation = location
        } else {
            // Default to a sample city center if no location provided
            virtualExploreLocation = CLLocationCoordinate2D(
                latitude: 40.7128,
                longitude: -74.0060 // New York City
            )
        }

        generateVirtualSpawns()
    }

    func stopRemotePlay() {
        isRemotePlayEnabled = false
        virtualExploreLocation = nil
        virtualSpawns.removeAll()
    }

    /// Moves the virtual exploration location by the given offset in meters.
    func moveVirtualLocation(latitudeOffsetMeters: Double, longitudeOffsetMeters: Double) {
        guard var location = virtualExploreLocation else { return }

        // Approximate degree offset from meters
        let latOffset = latitudeOffsetMeters / 111_111.0
        let lonOffset = longitudeOffsetMeters / (111_111.0 * cos(location.latitude * .pi / 180.0))

        location = CLLocationCoordinate2D(
            latitude: location.latitude + latOffset,
            longitude: location.longitude + lonOffset
        )
        virtualExploreLocation = location

        // Regenerate spawns around new location
        generateVirtualSpawns()
    }

    /// Generates creature spawns in a radius around the virtual explore location.
    func generateVirtualSpawns() {
        guard let center = virtualExploreLocation else { return }

        let allSpecies = Array(SpeciesDatabase.shared.species.values)
        guard !allSpecies.isEmpty else { return }

        var spawns: [VirtualSpawn] = []
        let spawnCount = Int.random(in: 3...8)

        for _ in 0..<spawnCount {
            // Random offset within ~200m radius
            let latOffset = Double.random(in: -0.002...0.002)
            let lonOffset = Double.random(in: -0.002...0.002)

            let spawnCoord = CLLocationCoordinate2D(
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset
            )

            let randomSpecies = allSpecies.randomElement()!
            let spawn = VirtualSpawn(
                speciesId: randomSpecies.id,
                coordinate: spawnCoord,
                expiresAt: Date().addingTimeInterval(Double.random(in: 600...1800))
            )
            spawns.append(spawn)
        }

        virtualSpawns = spawns
    }

    // MARK: - Voice Control

    /// Registers an action handler for a voice command keyword.
    func registerCommandAction(keyword: String, handler: @escaping () -> Void) {
        commandActionHandlers[keyword.lowercased()] = handler
    }

    /// Starts listening for voice commands using SFSpeechRecognizer.
    func startListening() {
        guard !isListening else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }

            DispatchQueue.main.async {
                self?.beginRecognition()
            }
        }
    }

    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    private func beginRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let spokenText = result.bestTranscription.formattedString.lowercased()
                self.processVoiceInput(spokenText)
            }

            if error != nil || (result?.isFinal == true) {
                self.stopListening()
                // Restart after a brief pause for continuous listening
                if self.isVoiceControlEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.startListening()
                    }
                }
            }
        }
    }

    private func processVoiceInput(_ text: String) {
        // Check each registered command
        for command in registeredCommands {
            let allKeywords = [command.keyword] + command.aliases
            for keyword in allKeywords {
                if text.contains(keyword.lowercased()) {
                    DispatchQueue.main.async {
                        self.lastRecognizedCommand = keyword
                        command.action()
                        // Also call any registered external handler
                        self.commandActionHandlers[command.keyword.lowercased()]?()
                    }
                    return
                }
            }
        }
    }

    private func registerDefaultVoiceCommands() {
        registeredCommands = [
            VoiceCommand(keyword: "catch", aliases: ["grab", "capture"]) {
                NotificationCenter.default.post(name: .voiceCommandCatch, object: nil)
            },
            VoiceCommand(keyword: "throw", aliases: ["toss", "launch"]) {
                NotificationCenter.default.post(name: .voiceCommandThrow, object: nil)
            },
            VoiceCommand(keyword: "battle", aliases: ["fight", "attack"]) {
                NotificationCenter.default.post(name: .voiceCommandBattle, object: nil)
            },
            VoiceCommand(keyword: "dodge", aliases: ["evade", "duck"]) {
                NotificationCenter.default.post(name: .voiceCommandDodge, object: nil)
            },
            VoiceCommand(keyword: "use potion", aliases: ["heal", "potion"]) {
                NotificationCenter.default.post(name: .voiceCommandUsePotion, object: nil)
            },
            VoiceCommand(keyword: "switch creature", aliases: ["swap", "change creature"]) {
                NotificationCenter.default.post(name: .voiceCommandSwitchCreature, object: nil)
            },
            VoiceCommand(keyword: "run away", aliases: ["flee", "escape", "run"]) {
                NotificationCenter.default.post(name: .voiceCommandRunAway, object: nil)
            },
            VoiceCommand(keyword: "open map", aliases: ["show map", "map"]) {
                NotificationCenter.default.post(name: .voiceCommandOpenMap, object: nil)
            },
            VoiceCommand(keyword: "open inventory", aliases: ["inventory", "bag", "items"]) {
                NotificationCenter.default.post(name: .voiceCommandOpenInventory, object: nil)
            }
        ]
    }

    // MARK: - Haptic-Only Mode

    /// Provides a haptic feedback pattern based on creature proximity distance.
    /// Closer creatures produce stronger, more frequent vibrations.
    func hapticForCreatureNearby(distance: Double) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Fallback to basic haptics
            let generator = UIImpactFeedbackGenerator(style: distance < 20 ? .heavy : .light)
            generator.impactOccurred()
            return
        }

        guard let engine = hapticEngine else { return }

        // Intensity inversely proportional to distance (closer = stronger)
        let maxDistance: Double = 100.0
        let normalizedDistance = min(distance, maxDistance) / maxDistance
        let intensity = Float(1.0 - normalizedDistance)
        let sharpness = Float(0.3 + (1.0 - normalizedDistance) * 0.7)

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: 0.2
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic creature proximity error: \(error.localizedDescription)")
        }
    }

    /// Provides a distinct haptic pattern per rarity level.
    func hapticForRarity(_ rarity: Rarity) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch rarity {
            case .common, .uncommon: style = .light
            case .rare, .epic: style = .medium
            case .legendary, .mythic: style = .heavy
            }
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            return
        }

        guard let engine = hapticEngine else { return }

        let events: [CHHapticEvent]
        switch rarity {
        case .common:
            // Single gentle tap
            events = [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                              ],
                              relativeTime: 0)
            ]
        case .uncommon:
            // Two quick taps
            events = [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                              ],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                              ],
                              relativeTime: 0.15)
            ]
        case .rare:
            // Three ascending taps
            events = (0..<3).map { i in
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 + Float(i) * 0.15),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4 + Float(i) * 0.15)
                              ],
                              relativeTime: TimeInterval(i) * 0.12)
            }
        case .epic:
            // Pulsing crescendo
            events = (0..<4).map { i in
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5 + Float(i) * 0.12),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5 + Float(i) * 0.12)
                              ],
                              relativeTime: TimeInterval(i) * 0.1)
            }
        case .legendary:
            // Dramatic build with burst
            events = [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                              ],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                              ],
                              relativeTime: 0.1),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                              ],
                              relativeTime: 0.2),
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                              ],
                              relativeTime: 0.35,
                              duration: 0.3)
            ]
        case .mythic:
            // Intense multi-pulse explosion pattern
            events = [
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                              ],
                              relativeTime: 0,
                              duration: 0.2),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                              ],
                              relativeTime: 0.25),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                              ],
                              relativeTime: 0.35),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                              ],
                              relativeTime: 0.45),
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                              ],
                              relativeTime: 0.55,
                              duration: 0.4)
            ]
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic rarity pattern error: \(error.localizedDescription)")
        }
    }

    // MARK: - Haptic Engine Setup

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
            try hapticEngine?.start()
        } catch {
            print("Haptic engine init error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Voice Command Notification Names

extension Notification.Name {
    static let voiceCommandCatch = Notification.Name("voiceCommandCatch")
    static let voiceCommandThrow = Notification.Name("voiceCommandThrow")
    static let voiceCommandBattle = Notification.Name("voiceCommandBattle")
    static let voiceCommandDodge = Notification.Name("voiceCommandDodge")
    static let voiceCommandUsePotion = Notification.Name("voiceCommandUsePotion")
    static let voiceCommandSwitchCreature = Notification.Name("voiceCommandSwitchCreature")
    static let voiceCommandRunAway = Notification.Name("voiceCommandRunAway")
    static let voiceCommandOpenMap = Notification.Name("voiceCommandOpenMap")
    static let voiceCommandOpenInventory = Notification.Name("voiceCommandOpenInventory")
}
