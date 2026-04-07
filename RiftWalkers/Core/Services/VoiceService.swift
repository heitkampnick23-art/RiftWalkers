import Foundation
import AVFoundation
import SwiftUI

// MARK: - Voice Service (ElevenLabs TTS)
// High-quality AI voice for Professor Valen companion.
// Proxied through Cloudflare Worker — API key never leaves the server.
// Falls back to AVSpeechSynthesizer if ElevenLabs is unavailable.

final class VoiceService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = VoiceService()

    @Published var isSpeaking = false
    @Published var voiceEnabled = true
    @Published var useElevenLabs = true

    private let proxyBaseURL = "https://riftwalkers-api.heitkampnick23.workers.dev"
    private let session: URLSession
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechQueue: [(text: String, priority: VoicePriority)] = []
    private var isProcessingQueue = false
    private let audioCache = NSCache<NSString, NSData>()
    private var delegate: SynthDelegate?

    // Configurable voice settings
    var elevenLabsVoiceID: String {
        get { UserDefaults.standard.string(forKey: "elevenlabs_voice_id") ?? "pNInz6obpgDQGcFmaJgB" }
        set { UserDefaults.standard.set(newValue, forKey: "elevenlabs_voice_id") }
    }
    var stability: Double = 0.5
    var similarityBoost: Double = 0.75
    var style: Double = 0.4

    enum VoicePriority: Int, Comparable {
        case ambient = 0
        case normal = 1
        case important = 2
        case critical = 3

        static func < (lhs: VoicePriority, rhs: VoicePriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
        super.init()
        delegate = SynthDelegate(service: self)
        synthesizer.delegate = delegate
        audioCache.countLimit = 30
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("[Voice] Audio session config failed: \(error)")
        }
    }

    // MARK: - Public API

    func speak(_ text: String, priority: VoicePriority = .normal) {
        guard voiceEnabled else { return }

        if priority == .critical {
            // Critical messages interrupt everything
            stopSpeaking()
            speechQueue.insert((text, priority), at: 0)
        } else {
            speechQueue.append((text, priority))
        }

        if !isProcessingQueue {
            processQueue()
        }
    }

    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func clearQueue() {
        speechQueue.removeAll()
        stopSpeaking()
        isProcessingQueue = false
    }

    // MARK: - Queue Processing

    private func processQueue() {
        guard !speechQueue.isEmpty else {
            isProcessingQueue = false
            return
        }

        isProcessingQueue = true
        let next = speechQueue.removeFirst()

        Task {
            await MainActor.run { isSpeaking = true }

            if useElevenLabs {
                let success = await speakWithElevenLabs(next.text)
                if !success {
                    // Fallback to system TTS
                    await speakWithSystemTTS(next.text)
                }
            } else {
                await speakWithSystemTTS(next.text)
            }
        }
    }

    // MARK: - ElevenLabs TTS

    private func speakWithElevenLabs(_ text: String) async -> Bool {
        // Check cache first
        let cacheKey = text.prefix(100) as NSString
        if let cached = audioCache.object(forKey: cacheKey) {
            return await playAudioData(cached as Data)
        }

        do {
            var request = URLRequest(url: URL(string: "\(proxyBaseURL)/v1/voice/tts")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "text": text,
                "voiceId": elevenLabsVoiceID,
                "stability": stability,
                "similarityBoost": similarityBoost,
                "style": style
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }

            // Cache the audio
            audioCache.setObject(data as NSData, forKey: cacheKey)

            return await playAudioData(data)
        } catch {
            print("[Voice] ElevenLabs TTS failed: \(error)")
            return false
        }
    }

    private func playAudioData(_ data: Data) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.play()
                    // Continuation resumes in audioPlayerDidFinishPlaying
                    self._playbackContinuation = continuation
                } catch {
                    print("[Voice] Audio playback failed: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private var _playbackContinuation: CheckedContinuation<Bool, Never>?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?._playbackContinuation?.resume(returning: flag)
            self?._playbackContinuation = nil
            self?.processQueue()
        }
    }

    // MARK: - System TTS Fallback

    private func speakWithSystemTTS(_ text: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.52
                utterance.pitchMultiplier = 1.05
                utterance.volume = 0.8
                self.delegate?.completion = {
                    continuation.resume()
                    DispatchQueue.main.async {
                        self.isSpeaking = false
                        self.processQueue()
                    }
                }
                self.synthesizer.speak(utterance)
            }
        }
    }
}

// MARK: - AVSpeechSynthesizer Delegate

private class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var service: VoiceService?
    var completion: (() -> Void)?

    init(service: VoiceService) {
        self.service = service
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion?()
        completion = nil
    }
}
