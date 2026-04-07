import Foundation
import Combine

final class GamePersistenceService: ObservableObject {
    static let shared = GamePersistenceService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var isAuthenticated = false

    private let network = NetworkService.shared
    private let saveKey = "riftwalkers_local_save"
    private let autoSaveInterval: TimeInterval = 300 // 5 minutes
    private var autoSaveTimer: Timer?

    private init() {
        isAuthenticated = network.restoreSession()
        startAutoSave()
    }

    // MARK: - Auth Flow

    func authenticateOrRegister() async -> Bool {
        // Try login first (existing account)
        if let _ = KeychainService.shared.getPlayerID() {
            do {
                let _ = try await network.login()
                await MainActor.run { isAuthenticated = true }
                return true
            } catch {
                // Token expired or invalid — fall through to register
            }
        }

        // Register new account
        do {
            let name = generatePlayerName()
            let _ = try await network.register(displayName: name)
            await MainActor.run { isAuthenticated = true }
            return true
        } catch {
            print("[Persistence] Auth failed: \(error.localizedDescription)")
            // Continue in offline mode
            await MainActor.run { isAuthenticated = false }
            return false
        }
    }

    // MARK: - Save to Cloud

    func syncToCloud(player: Player, creatures: [Creature], items: [InventoryItem]) async {
        guard isAuthenticated else { return }
        await MainActor.run { isSyncing = true }

        let playerSave = PlayerSaveData(
            level: player.level,
            xp: player.experience,
            gold: player.gold,
            riftGems: player.riftGems,
            riftDust: player.riftDust,
            seasonTokens: 0,
            totalCatches: player.creaturesCaught,
            totalBattles: player.pvpWins + player.pvpLosses,
            totalDistanceKm: player.totalDistanceWalked
        )

        let creaturesSave = creatures.map { c in
            CreatureSaveData(
                id: c.id.uuidString,
                speciesId: c.speciesID,
                nickname: c.nickname,
                level: c.level,
                xp: c.experience,
                cp: c.combatPower,
                hp: c.maxHP,
                attack: c.baseAttack,
                defense: c.baseDefense,
                speed: c.baseSpeed,
                ivHp: c.ivHP,
                ivAttack: c.ivAttack,
                ivDefense: c.ivDefense,
                ivSpeed: c.ivSpeed,
                isShiny: c.isShiny,
                evolutionStage: c.evolutionStage,
                caughtLatitude: c.captureLocation.latitude,
                caughtLongitude: c.captureLocation.longitude
            )
        }

        let inventorySave = items.map { item in
            InventorySaveData(
                itemId: item.id.uuidString,
                itemType: item.type.rawValue,
                quantity: item.quantity
            )
        }

        let state = GameStateSave(
            player: playerSave,
            creatures: creaturesSave,
            inventory: inventorySave
        )

        do {
            let _ = try await network.saveGameState(state)
            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
        } catch {
            print("[Persistence] Cloud sync failed: \(error.localizedDescription)")
            await MainActor.run { isSyncing = false }
        }
    }

    // MARK: - Load from Cloud

    func loadFromCloud() async -> GameStateResponse? {
        guard isAuthenticated else { return nil }
        do {
            let state = try await network.fetchGameState()
            await MainActor.run { lastSyncDate = Date() }
            return state
        } catch {
            print("[Persistence] Cloud load failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Local Save / Load

    func saveLocally(player: Player, creatures: [Creature]) {
        let data = LocalSaveData(player: player, creatures: creatures, savedAt: Date())
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    func loadLocal() -> LocalSaveData? {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let save = try? JSONDecoder().decode(LocalSaveData.self, from: data) else {
            return nil
        }
        return save
    }

    // MARK: - Auto Save

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            NotificationCenter.default.post(name: .autoSaveTriggered, object: nil)
        }
    }

    // MARK: - Helpers

    private func generatePlayerName() -> String {
        let adjectives = ["Swift", "Shadow", "Storm", "Rift", "Ancient", "Mystic", "Wild", "Dark", "Frost", "Iron"]
        let nouns = ["Walker", "Hunter", "Seeker", "Warden", "Keeper", "Sage", "Knight", "Rogue", "Mage", "Scout"]
        let adj = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        let num = Int.random(in: 100...999)
        return "\(adj)\(noun)\(num)"
    }
}

// MARK: - Local Save Model

struct LocalSaveData: Codable {
    let player: Player
    let creatures: [Creature]
    let savedAt: Date
}

// MARK: - Notification

extension Notification.Name {
    static let autoSaveTriggered = Notification.Name("autoSaveTriggered")
}
