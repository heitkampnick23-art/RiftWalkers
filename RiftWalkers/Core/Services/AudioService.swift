import Foundation
import AVFoundation
import Combine

// MARK: - Audio Service
// Researched: Sound design is 40% of game "feel" (GDC talks).
// Pokemon GO's capture sound, Genshin's elemental burst sounds = dopamine triggers.

final class AudioService: ObservableObject {
    static let shared = AudioService()

    @Published var isMusicEnabled = true
    @Published var isSFXEnabled = true
    @Published var musicVolume: Float = 0.7
    @Published var sfxVolume: Float = 1.0

    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    private var ambientPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    // MARK: - Music

    func playMusic(_ track: MusicTrack) {
        guard isMusicEnabled else { return }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3") else { return }

        do {
            musicPlayer?.stop()
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = musicVolume
            musicPlayer?.play()
        } catch {
            print("Failed to play music: \(error)")
        }
    }

    func stopMusic(fadeOut: TimeInterval = 1.0) {
        guard let player = musicPlayer else { return }
        let steps = 20
        let interval = fadeOut / Double(steps)
        let volumeStep = player.volume / Float(steps)

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            player.volume -= volumeStep
            if player.volume <= 0 {
                player.stop()
                timer.invalidate()
            }
        }
    }

    // MARK: - SFX

    func playSFX(_ sound: SoundEffect) {
        guard isSFXEnabled else { return }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.play()
            sfxPlayers[sound.rawValue] = player
        } catch {
            print("Failed to play SFX: \(error)")
        }
    }

    // MARK: - Ambient

    func playAmbient(_ ambience: AmbienceType) {
        guard isSFXEnabled else { return }
        guard let url = Bundle.main.url(forResource: ambience.rawValue, withExtension: "mp3") else { return }

        do {
            ambientPlayer?.stop()
            ambientPlayer = try AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1
            ambientPlayer?.volume = sfxVolume * 0.3
            ambientPlayer?.play()
        } catch {
            print("Failed to play ambient: \(error)")
        }
    }
}

// MARK: - Sound Enums

enum MusicTrack: String {
    case mainTheme = "main_theme"
    case battleNormal = "battle_normal"
    case battleBoss = "battle_boss"
    case battlePvP = "battle_pvp"
    case mapExplore = "map_explore"
    case mapNight = "map_night"
    case territory = "territory"
    case victory = "victory"
    case defeat = "defeat"
    case shop = "shop"
    case guild = "guild"
    case riftDungeon = "rift_dungeon"
    case eventSpecial = "event_special"
    case onboarding = "onboarding"
}

enum SoundEffect: String {
    case creatureAppear = "creature_appear"
    case creatureCapture = "creature_capture"
    case creatureEscape = "creature_escape"
    case sphereThrow = "sphere_throw"
    case sphereShake = "sphere_shake"
    case battleHit = "battle_hit"
    case battleCrit = "battle_crit"
    case battleMiss = "battle_miss"
    case abilityFire = "ability_fire"
    case abilityWater = "ability_water"
    case abilityLightning = "ability_lightning"
    case abilityUltimate = "ability_ultimate"
    case levelUp = "level_up"
    case evolution = "evolution"
    case questComplete = "quest_complete"
    case itemPickup = "item_pickup"
    case itemUse = "item_use"
    case territoryCapture = "territory_capture"
    case territoryLost = "territory_lost"
    case riftOpen = "rift_open"
    case menuTap = "menu_tap"
    case menuBack = "menu_back"
    case notification = "notification"
    case rareDrop = "rare_drop"
    case gachaReveal = "gacha_reveal"
    case gachaLegendary = "gacha_legendary"
    case coinCollect = "coin_collect"
    case achievementUnlock = "achievement_unlock"
}

enum AmbienceType: String {
    case forest = "ambient_forest"
    case city = "ambient_city"
    case water = "ambient_water"
    case night = "ambient_night"
    case storm = "ambient_storm"
    case dungeon = "ambient_dungeon"
}
