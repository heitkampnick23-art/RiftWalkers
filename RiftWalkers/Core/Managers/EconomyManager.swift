import Foundation
import StoreKit
import Combine

// MARK: - Economy Manager
// Researched: Diablo Immortal's multi-currency system (generated $100M+ in 2 months).
// Key insight: Multiple currency sinks prevent inflation and create spending decisions.
// Free players MUST feel progression. Whales need exclusive but non-P2W items.
//
// Currency hierarchy:
// 1. Gold (soft) - earned freely, used for basic upgrades
// 2. Rift Gems (hard) - premium, bought with real money or earned slowly
// 3. Essences (per-mythology) - evolution currency, creates collection depth
// 4. Rift Dust - crafting currency
// 5. Season Tokens - battle pass progression

final class EconomyManager: ObservableObject {
    static let shared = EconomyManager()

    @Published var gold: Int = 1000
    @Published var riftGems: Int = 50
    @Published var riftDust: Int = 100
    @Published var essences: [Mythology: Int] = [:]
    @Published var seasonTokens: Int = 0

    // StoreKit 2 for IAP - Production App Store
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isPurchasing = false

    private var transactionListener: Task<Void, Error>?

    // MARK: - Product IDs (App Store Connect)
    // These MUST match exactly what is configured in App Store Connect.
    // Bundle ID: com.riftwalkers.app
    struct ProductIDs {
        // Consumable — Rift Gem Packs
        static let gemPack100  = "com.riftwalkers.app.gems.100"
        static let gemPack500  = "com.riftwalkers.app.gems.500"
        static let gemPack1200 = "com.riftwalkers.app.gems.1200"
        static let gemPack2500 = "com.riftwalkers.app.gems.2500"
        static let gemPack6500 = "com.riftwalkers.app.gems.6500"

        // Non-Consumable — Battle Pass (seasonal, one-time per season)
        static let battlePassPremium = "com.riftwalkers.app.battlepass.premium"
        static let battlePassDeluxe  = "com.riftwalkers.app.battlepass.deluxe"

        // Auto-Renewable Subscription — Rift Walker Plus
        static let monthlySubscription = "com.riftwalkers.app.sub.monthly"

        // Consumable — Special Bundles
        static let starterPack = "com.riftwalkers.app.starter.pack"
        static let weeklyDeal  = "com.riftwalkers.app.weekly.deal"

        // All product IDs for StoreKit product request
        static let allIDs: [String] = [
            gemPack100, gemPack500, gemPack1200, gemPack2500, gemPack6500,
            battlePassPremium, battlePassDeluxe, monthlySubscription,
            starterPack, weeklyDeal
        ]

        // Subscription Group ID (for App Store Connect)
        static let subscriptionGroupName = "RiftWalker Plus"
        static let subscriptionGroupID   = "com.riftwalkers.app.sub"
    }

    private init() {
        initializeEssences()
        startTransactionListener()
        Task { await loadProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Currency Operations

    private func initializeEssences() {
        for mythology in Mythology.allCases {
            essences[mythology] = 0
        }
    }

    func canAfford(gold: Int = 0, gems: Int = 0, dust: Int = 0, essence: (Mythology, Int)? = nil) -> Bool {
        var affordable = self.gold >= gold && riftGems >= gems && riftDust >= dust
        if let (myth, amount) = essence {
            affordable = affordable && (essences[myth] ?? 0) >= amount
        }
        return affordable
    }

    func spend(gold: Int = 0, gems: Int = 0, dust: Int = 0, essence: (Mythology, Int)? = nil) -> Bool {
        guard canAfford(gold: gold, gems: gems, dust: dust, essence: essence) else { return false }

        self.gold -= gold
        self.riftGems -= gems
        self.riftDust -= dust
        if let (myth, amount) = essence {
            essences[myth, default: 0] -= amount
        }
        return true
    }

    func earn(gold: Int = 0, gems: Int = 0, dust: Int = 0, essence: (Mythology, Int)? = nil) {
        self.gold += gold
        self.riftGems += gems
        self.riftDust += dust
        if let (myth, amount) = essence {
            essences[myth, default: 0] += amount
        }
    }

    func earnSeasonTokens(_ amount: Int) {
        seasonTokens += amount
    }

    // MARK: - Daily Rewards
    // Researched: Streak-based rewards are the #1 DAU driver across all mobile games.
    // Missing a day resets to day 1 = powerful loss aversion.

    struct DailyReward {
        let day: Int
        let gold: Int
        let gems: Int
        let items: [String]
        let description: String
    }

    var dailyRewardSchedule: [DailyReward] {
        [
            DailyReward(day: 1, gold: 200, gems: 0, items: ["basic_sphere_x5"], description: "5 Capture Spheres"),
            DailyReward(day: 2, gold: 300, gems: 5, items: [], description: "300 Gold + 5 Gems"),
            DailyReward(day: 3, gold: 200, gems: 0, items: ["potion_x3", "incense_x1"], description: "3 Potions + 1 Incense"),
            DailyReward(day: 4, gold: 500, gems: 10, items: [], description: "500 Gold + 10 Gems"),
            DailyReward(day: 5, gold: 300, gems: 0, items: ["great_sphere_x3", "lure_x1"], description: "3 Great Spheres + 1 Lure"),
            DailyReward(day: 6, gold: 800, gems: 15, items: [], description: "800 Gold + 15 Gems"),
            DailyReward(day: 7, gold: 1000, gems: 50, items: ["ultra_sphere_x3", "rift_key_x1"], description: "MEGA REWARD: 1000 Gold + 50 Gems + Ultra Spheres + Rift Key"),
        ]
    }

    func claimDailyReward(streakDay: Int) -> DailyReward? {
        let day = ((streakDay - 1) % 7) + 1
        guard let reward = dailyRewardSchedule.first(where: { $0.day == day }) else { return nil }

        earn(gold: reward.gold, gems: reward.gems)
        return reward
    }

    // MARK: - Gacha System
    // Researched: Genshin Impact's pity system is the gold standard.
    // Hard pity at 90 pulls, soft pity starting at 75.
    // Guaranteed featured at 180 pulls (2x hard pity if lost 50/50).
    // This creates predictable whale spending while giving F2P hope.

    struct GachaBanner: Identifiable {
        let id: UUID
        let name: String
        let featuredCreatures: [String]  // Species IDs
        let mythology: Mythology
        let startDate: Date
        let endDate: Date
        let costPerPull: Int    // In rift gems
        let costPer10Pull: Int  // Discount for 10x
    }

    @Published var currentPityCount: Int = 0
    @Published var guaranteed5Star: Bool = false  // Lost 50/50 flag

    let softPityThreshold = 75
    let hardPityThreshold = 90
    let base5StarRate = 0.006   // 0.6%
    let base4StarRate = 0.051   // 5.1%

    func calculateGachaRate() -> (fiveStarRate: Double, fourStarRate: Double) {
        var fiveStarRate = base5StarRate

        // Soft pity: rate increases dramatically after threshold
        if currentPityCount >= softPityThreshold {
            let bonusRate = Double(currentPityCount - softPityThreshold + 1) * 0.06
            fiveStarRate = min(1.0, base5StarRate + bonusRate)
        }

        // Hard pity: guaranteed
        if currentPityCount >= hardPityThreshold - 1 {
            fiveStarRate = 1.0
        }

        return (fiveStarRate, base4StarRate)
    }

    func performGachaPull(banner: GachaBanner) -> (rarity: Rarity, speciesID: String, isGuaranteed: Bool)? {
        guard spend(gems: banner.costPerPull) else { return nil }

        currentPityCount += 1
        let rates = calculateGachaRate()
        let roll = Double.random(in: 0..<1)

        if roll < rates.fiveStarRate {
            // 5-star pull!
            currentPityCount = 0
            let isFeatured = guaranteed5Star || Double.random(in: 0..<1) < 0.5
            guaranteed5Star = !isFeatured // If lost 50/50, next is guaranteed

            let speciesID = isFeatured
                ? (banner.featuredCreatures.randomElement() ?? "")
                : "" // Random from standard pool
            return (.legendary, speciesID, isFeatured)
        } else if roll < rates.fiveStarRate + rates.fourStarRate {
            // 4-star pull
            return (.epic, "", false)
        } else {
            // 3-star pull
            return (.rare, "", false)
        }
    }

    // MARK: - StoreKit 2 Integration (Production App Store)

    func loadProducts() async {
        do {
            let products = try await Product.products(for: ProductIDs.allIDs)
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        await MainActor.run { isPurchasing = true }

        let result = try await product.purchase()

        await MainActor.run { isPurchasing = false }

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            await fulfillPurchase(product: product, transaction: transaction)
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerification(result) {
                await fulfillPurchase(product: nil, transaction: transaction)
                await transaction.finish()
            }
        }
    }

    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func fulfillPurchase(product: Product?, transaction: Transaction) async {
        let productID = transaction.productID

        await MainActor.run {
            purchasedProductIDs.insert(productID)

            switch productID {
            // Consumable — Gem Packs
            case ProductIDs.gemPack100:  riftGems += 100
            case ProductIDs.gemPack500:  riftGems += 550   // 500 + 50 bonus
            case ProductIDs.gemPack1200: riftGems += 1400  // 1200 + 200 bonus
            case ProductIDs.gemPack2500: riftGems += 3000  // 2500 + 500 bonus
            case ProductIDs.gemPack6500: riftGems += 8000  // 6500 + 1500 bonus

            // Consumable — Starter Pack
            case ProductIDs.starterPack:
                riftGems += 300
                gold += 5000

            // Consumable — Weekly Deal
            case ProductIDs.weeklyDeal:
                riftGems += 150
                gold += 3000
                riftDust += 500

            // Non-Consumable — Battle Pass
            case ProductIDs.battlePassPremium:
                ProgressionManager.shared.player.battlePassPremium = true

            case ProductIDs.battlePassDeluxe:
                ProgressionManager.shared.player.battlePassPremium = true
                ProgressionManager.shared.player.battlePassTier += 25  // Skip 25 tiers
                riftGems += 500

            // Auto-Renewable Subscription — Rift Walker Plus
            case ProductIDs.monthlySubscription:
                // Daily gems delivered on login; flag stored for entitlement check
                UserDefaults.standard.set(true, forKey: "riftwalker_plus_active")

            default:
                break
            }
        }
    }

    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerification(result) {
                    await self.fulfillPurchase(product: nil, transaction: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Shop Items

    struct ShopItem: Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let goldCost: Int?
        let gemCost: Int?
        let category: ShopCategory
        let isLimited: Bool
        let expiresAt: Date?
    }

    enum ShopCategory: String, CaseIterable {
        case spheres = "Capture Spheres"
        case potions = "Potions & Healing"
        case boosters = "Boosters"
        case keys = "Rift Keys"
        case cosmetics = "Cosmetics"
        case bundles = "Special Bundles"
    }

    var shopItems: [ShopItem] {
        [
            ShopItem(id: "basic_sphere", name: "Capture Sphere", description: "Basic capture device", icon: "circle.fill", goldCost: 50, gemCost: nil, category: .spheres, isLimited: false, expiresAt: nil),
            ShopItem(id: "great_sphere", name: "Great Sphere", description: "Higher catch rate", icon: "circle.circle.fill", goldCost: 150, gemCost: nil, category: .spheres, isLimited: false, expiresAt: nil),
            ShopItem(id: "ultra_sphere", name: "Ultra Sphere", description: "Premium catch rate", icon: "largecircle.fill.circle", goldCost: nil, gemCost: 20, category: .spheres, isLimited: false, expiresAt: nil),
            ShopItem(id: "mythic_sphere", name: "Mythic Sphere", description: "Near-guaranteed capture", icon: "star.circle.fill", goldCost: nil, gemCost: 100, category: .spheres, isLimited: false, expiresAt: nil),
            ShopItem(id: "potion_50", name: "Potion", description: "Restore 50 HP", icon: "cross.vial.fill", goldCost: 30, gemCost: nil, category: .potions, isLimited: false, expiresAt: nil),
            ShopItem(id: "potion_200", name: "Super Potion", description: "Restore 200 HP", icon: "cross.vial.fill", goldCost: 100, gemCost: nil, category: .potions, isLimited: false, expiresAt: nil),
            ShopItem(id: "revive", name: "Revive Crystal", description: "Revive fainted creature at 50% HP", icon: "diamond.fill", goldCost: 200, gemCost: nil, category: .potions, isLimited: false, expiresAt: nil),
            ShopItem(id: "xp_booster", name: "XP Boost (30min)", description: "Double XP for 30 minutes", icon: "arrow.up.circle.fill", goldCost: nil, gemCost: 30, category: .boosters, isLimited: false, expiresAt: nil),
            ShopItem(id: "incense", name: "Rift Incense", description: "Attract creatures for 30 min", icon: "smoke.fill", goldCost: nil, gemCost: 25, category: .boosters, isLimited: false, expiresAt: nil),
            ShopItem(id: "lure", name: "Territory Lure", description: "Increase spawns at a territory", icon: "mappin.and.ellipse", goldCost: 300, gemCost: nil, category: .boosters, isLimited: false, expiresAt: nil),
            ShopItem(id: "rift_key", name: "Rift Key", description: "Access a Rift Dungeon", icon: "key.fill", goldCost: nil, gemCost: 50, category: .keys, isLimited: false, expiresAt: nil),
            ShopItem(id: "golden_key", name: "Golden Rift Key", description: "Access Mythic difficulty", icon: "key.fill", goldCost: nil, gemCost: 150, category: .keys, isLimited: false, expiresAt: nil),
        ]
    }
}
