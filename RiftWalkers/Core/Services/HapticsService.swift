import Foundation
import UIKit
import CoreHaptics

// MARK: - Haptics Service
// Researched: Apple's haptic design guidelines + Pokemon GO's vibration on encounter.
// Good haptics make digital interactions feel physical - critical for AR/geo games.

final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }

    // MARK: - Simple Haptics

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Game Haptics

    func creatureEncounter() {
        playPattern([
            (intensity: 0.5, sharpness: 0.3, time: 0.0),
            (intensity: 0.8, sharpness: 0.6, time: 0.1),
            (intensity: 1.0, sharpness: 0.8, time: 0.2),
        ])
    }

    func captureSuccess() {
        playPattern([
            (intensity: 0.3, sharpness: 0.2, time: 0.0),
            (intensity: 0.6, sharpness: 0.5, time: 0.15),
            (intensity: 1.0, sharpness: 1.0, time: 0.3),
            (intensity: 0.4, sharpness: 0.3, time: 0.5),
        ])
    }

    func captureFailure() {
        playPattern([
            (intensity: 0.8, sharpness: 0.8, time: 0.0),
            (intensity: 0.3, sharpness: 0.2, time: 0.2),
        ])
    }

    func battleHit() {
        impact(.heavy)
    }

    func battleCritical() {
        playPattern([
            (intensity: 1.0, sharpness: 1.0, time: 0.0),
            (intensity: 0.5, sharpness: 0.5, time: 0.05),
            (intensity: 1.0, sharpness: 1.0, time: 0.1),
        ])
    }

    func levelUp() {
        playPattern([
            (intensity: 0.4, sharpness: 0.3, time: 0.0),
            (intensity: 0.6, sharpness: 0.5, time: 0.1),
            (intensity: 0.8, sharpness: 0.7, time: 0.2),
            (intensity: 1.0, sharpness: 1.0, time: 0.3),
            (intensity: 0.6, sharpness: 0.4, time: 0.5),
            (intensity: 0.3, sharpness: 0.2, time: 0.7),
        ])
    }

    func rareDrop() {
        playPattern([
            (intensity: 0.5, sharpness: 0.8, time: 0.0),
            (intensity: 0.3, sharpness: 0.3, time: 0.1),
            (intensity: 0.7, sharpness: 0.9, time: 0.2),
            (intensity: 0.3, sharpness: 0.3, time: 0.3),
            (intensity: 1.0, sharpness: 1.0, time: 0.4),
        ])
    }

    func sphereShake() {
        impact(.medium)
    }

    func territoryCapture() {
        playPattern([
            (intensity: 0.6, sharpness: 0.4, time: 0.0),
            (intensity: 0.8, sharpness: 0.6, time: 0.15),
            (intensity: 1.0, sharpness: 0.8, time: 0.3),
            (intensity: 0.5, sharpness: 0.3, time: 0.5),
            (intensity: 0.7, sharpness: 0.5, time: 0.65),
            (intensity: 1.0, sharpness: 1.0, time: 0.8),
        ])
    }

    // MARK: - Pattern Player

    private func playPattern(_ events: [(intensity: Float, sharpness: Float, time: TimeInterval)]) {
        guard supportsHaptics, let engine = engine else {
            impact(.medium)
            return
        }

        let hapticEvents = events.map { event in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                ],
                relativeTime: event.time
            )
        }

        do {
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic pattern failed: \(error)")
        }
    }
}
