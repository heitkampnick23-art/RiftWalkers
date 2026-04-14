import SwiftUI
import StoreKit

// MARK: - Shop View
// Researched: Genshin Impact's shop UX. Multiple tabs prevent overwhelm.
// Key monetization insight: Show VALUE not PRICE. "500 gems = 10 pulls"
// Fortnite's daily rotating shop creates urgency + collectibility.

struct ShopView: View {
    @StateObject private var economy = EconomyManager.shared

    @State private var selectedTab: ShopTab = .featured
    @State private var showPurchaseConfirm = false
    @State private var selectedProduct: Product?
    @State private var showGachaPull = false
    @State private var gachaPullCount = 1
    @State private var gachaResults: [(rarity: Rarity, species: CreatureSpecies?)] = []
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false

    enum ShopTab: String, CaseIterable {
        case featured = "Featured"
        case gems = "Rift Gems"
        case items = "Items"
        case battlePass = "Battle Pass"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Currency bar
                HStack(spacing: 16) {
                    CurrencyPill(icon: "dollarsign.circle.fill", value: economy.gold, color: .yellow)
                    CurrencyPill(icon: "diamond.fill", value: economy.riftGems, color: .purple)
                    CurrencyPill(icon: "sparkle", value: economy.riftDust, color: .cyan)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ShopTab.allCases, id: \.self) { tab in
                            Button(action: { withAnimation { selectedTab = tab } }) {
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? .blue.opacity(0.3) : .clear, in: Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }

                ScrollView {
                    switch selectedTab {
                    case .featured: featuredTab
                    case .gems: gemsTab
                    case .items: itemsTab
                    case .battlePass: battlePassTab
                    }
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGachaPull) {
                GachaPullResultView(results: gachaResults)
            }
            .sheet(isPresented: $showTermsSheet) {
                EULAView(onAccept: { showTermsSheet = false })
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyPolicyView()
            }
        }
    }

    // MARK: - Shop Purchase

    private func buyItem(gold: Int = 0, gems: Int = 0) {
        if economy.spend(gold: gold, gems: gems) {
            HapticsService.shared.notification(.success)
            AudioService.shared.playSFX(.coinCollect)
        } else {
            HapticsService.shared.notification(.error)
        }
    }

    // MARK: - Gacha Pull Logic

    private func performGachaPull(count: Int) {
        let banner = EconomyManager.GachaBanner(
            id: UUID(),
            name: "Norse Legends",
            featuredCreatures: Array(SpeciesDatabase.shared.species.keys.prefix(3)),
            mythology: .norse,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 14),
            costPerPull: 160,
            costPer10Pull: 1440
        )

        let totalCost = count >= 10 ? banner.costPer10Pull : banner.costPerPull * count
        guard economy.riftGems >= totalCost else {
            HapticsService.shared.notification(.error)
            return
        }

        var results: [(rarity: Rarity, species: CreatureSpecies?)] = []
        let allSpecies = Array(SpeciesDatabase.shared.species.values)

        for _ in 0..<count {
            if let pull = economy.performGachaPull(banner: banner) {
                let matchingSpecies = allSpecies.filter { $0.rarity == pull.rarity }.randomElement()
                    ?? allSpecies.randomElement()
                results.append((pull.rarity, matchingSpecies))
            }
        }

        gachaResults = results
        if !results.isEmpty {
            showGachaPull = true
            HapticsService.shared.notification(.success)
            AudioService.shared.playSFX(.rareDrop)
        }
    }

    // MARK: - Featured Tab

    private var featuredTab: some View {
        VStack(spacing: 16) {
            // Daily deal banner
            Button(action: { purchaseStarterPack() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red, .purple],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 140)

                    VStack(spacing: 8) {
                        Text("DAILY DEAL")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Starter Adventurer Pack")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                        Text("300 Gems + 5000 Gold + 10 Great Spheres")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(spacing: 4) {
                            Text("$4.99")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                            Text("$9.99")
                                .font(.caption)
                                .strikethrough()
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Rotating daily items
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Daily Rotation")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Resets in 14h 32m")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(economy.shopItems.prefix(6), id: \.id) { item in
                            ShopItemCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Gacha banner
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Mythic Summon")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Pity: \(economy.currentPityCount)/90")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple, .black],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Norse Legends Banner")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Featured: Fenrir, Valkyrie Shade")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Rate Up: 0.6% -> Soft Pity at 75")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Button(action: { performGachaPull(count: 1) }) {
                                Text("1x Pull")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.purple, in: Capsule())
                            }
                            Text("160 Gems")
                                .font(.system(size: 9))
                                .foregroundStyle(.purple)

                            Button(action: { performGachaPull(count: 10) }) {
                                Text("10x Pull")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing),
                                        in: Capsule()
                                    )
                            }
                            Text("1440 Gems (10% off)")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Gems Tab (IAP)

    private var gemsTab: some View {
        VStack(spacing: 12) {
            ForEach(economy.availableProducts, id: \.id) { product in
                GemPackCard(product: product) {
                    selectedProduct = product
                    Task {
                        _ = try? await economy.purchase(product)
                    }
                }
            }

            // Fallback if products haven't loaded
            if economy.availableProducts.isEmpty {
                ForEach(gemPackFallback, id: \.name) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pack.name)
                                .font(.subheadline.weight(.bold))
                            Text("\(pack.gems) Rift Gems")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            if let bonus = pack.bonus {
                                Text("+\(bonus) Bonus!")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        Button(pack.price) {}
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.blue, in: Capsule())
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Restore Purchases") {
                Task { await economy.restorePurchases() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Items Tab

    private var itemsTab: some View {
        VStack(spacing: 12) {
            ForEach(EconomyManager.ShopCategory.allCases, id: \.self) { category in
                let items = economy.shopItems.filter { $0.category == category }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.rawValue)
                            .font(.headline.weight(.bold))
                            .padding(.horizontal)

                        ForEach(items, id: \.id) { item in
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let gold = item.goldCost {
                                    Button(action: { buyItem(gold: gold) }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .foregroundStyle(.yellow)
                                            Text("\(gold)")
                                                .font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.yellow.opacity(0.15), in: Capsule())
                                    }
                                } else if let gems = item.gemCost {
                                    Button(action: { buyItem(gems: gems) }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "diamond.fill")
                                                .foregroundStyle(.purple)
                                            Text("\(gems)")
                                                .font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.purple.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .padding(.vertical)
    }

    // MARK: - Battle Pass Tab

    private var battlePassTab: some View {
        VStack(spacing: 16) {
            // Season banner
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Mythology.norse.color, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                VStack(spacing: 4) {
                    Text("SEASON 1")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Whispers of Ragnarok")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("42 days remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)

            // Current tier
            HStack {
                Text("Current Tier:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Tier \(ProgressionManager.shared.player.battlePassTier)")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if !ProgressionManager.shared.player.battlePassPremium {
                    Button(action: { purchaseBattlePass() }) {
                        Text("Upgrade to Premium")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                } else {
                    Text("PREMIUM")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal)

            // Subscription disclosure (Apple Guideline 3.1.2(c))
            if !ProgressionManager.shared.player.battlePassPremium {
                VStack(spacing: 6) {
                    Text("Rift Walker Plus — Auto-Renewable Subscription")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("$4.99/month • Renews automatically • Cancel anytime")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 16) {
                        Button(action: { showTermsSheet = true }) {
                            Text("Terms of Use")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }
                        Button(action: { showPrivacySheet = true }) {
                            Text("Privacy Policy")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }
                        Link("Subscription Terms",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(.horizontal)
            }

            // Tier reward preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1..<51, id: \.self) { tier in
                        BattlePassTierCard(
                            tier: tier,
                            isUnlocked: tier <= ProgressionManager.shared.player.battlePassTier,
                            isPremium: ProgressionManager.shared.player.battlePassPremium
                        ) {
                            claimTierReward(tier: tier)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private func purchaseBattlePass() {
        // Try real IAP first
        if let product = economy.availableProducts.first(where: { $0.id == EconomyManager.ProductIDs.battlePassPremium }) {
            Task {
                do {
                    _ = try await economy.purchase(product)
                } catch {
                    // Fallback to gem purchase
                    await MainActor.run { fallbackBattlePassPurchase() }
                }
            }
        } else {
            fallbackBattlePassPurchase()
        }
    }

    private func fallbackBattlePassPurchase() {
        if economy.spend(gems: 980) {
            ProgressionManager.shared.player.battlePassPremium = true
            HapticsService.shared.notification(.success)
            AudioService.shared.playSFX(.rareDrop)
        } else {
            HapticsService.shared.notification(.error)
        }
    }

    private func purchaseStarterPack() {
        if let product = economy.availableProducts.first(where: { $0.id == EconomyManager.ProductIDs.starterPack }) {
            Task {
                _ = try? await economy.purchase(product)
            }
        } else {
            // Fallback: award items directly for testing
            economy.earn(gold: 5000, gems: 300)
            HapticsService.shared.notification(.success)
            AudioService.shared.playSFX(.rareDrop)
        }
    }

    private func claimTierReward(tier: Int) {
        guard tier <= ProgressionManager.shared.player.battlePassTier else { return }
        // Award tier reward
        switch tier % 5 {
        case 0: economy.earn(gems: 20)
        case 1: economy.earn(gold: 200)
        case 2: economy.earn(gold: 300)
        case 3: economy.earn(dust: 100)
        default: economy.earn(gems: 10, dust: 50)
        }
        HapticsService.shared.notification(.success)
        AudioService.shared.playSFX(.coinCollect)
    }

    // MARK: - Fallback gem packs

    private var gemPackFallback: [(name: String, gems: Int, bonus: Int?, price: String)] {
        [
            ("Handful of Gems", 100, nil, "$0.99"),
            ("Pouch of Gems", 500, 50, "$4.99"),
            ("Chest of Gems", 1200, 200, "$9.99"),
            ("Vault of Gems", 2500, 500, "$24.99"),
            ("Hoard of Gems", 6500, 1500, "$49.99"),
        ]
    }
}

// MARK: - Components

struct CurrencyPill: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct ShopItemCard: View {
    let item: EconomyManager.ShopItem

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Text(item.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)

            if let gold = item.goldCost {
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text("\(gold)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .frame(width: 80)
    }
}

struct GemPackCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "diamond.fill")
                .font(.title2)
                .foregroundStyle(.purple)

            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.subheadline.weight(.bold))
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: action) {
                Text(product.displayPrice)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Gacha Pull Result View

struct GachaPullResultView: View {
    let results: [(rarity: Rarity, species: CreatureSpecies?)]

    @State private var revealedCount = 0
    @State private var showAll = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo, .purple.opacity(0.6), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(results.count > 1 ? "MULTI-SUMMON" : "SUMMON")
                    .font(.title2.weight(.black))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .padding(.top, 30)

                if showAll {
                    // Show all cards in grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 12) {
                            ForEach(Array(results.enumerated()), id: \.offset) { idx, result in
                                if let species = result.species {
                                    CreatureCardView(
                                        species: species,
                                        creature: nil,
                                        isShiny: false,
                                        showStats: false,
                                        size: .small
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if revealedCount < results.count, let species = results[revealedCount].species {
                    // Single card reveal
                    Spacer()

                    ZStack {
                        // Rarity burst
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [species.rarity.color.opacity(0.5), .clear],
                                    center: .center, startRadius: 20, endRadius: 180
                                )
                            )
                            .frame(width: 360, height: 360)

                        CreatureCardView(
                            species: species,
                            creature: nil,
                            isShiny: false,
                            showStats: true,
                            size: .large
                        )
                    }

                    Text("\(revealedCount + 1) / \(results.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()
                }

                // Controls
                HStack(spacing: 16) {
                    if !showAll && results.count > 1 {
                        Button(action: { withAnimation { showAll = true } }) {
                            Text("Show All")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.15), in: Capsule())
                        }
                    }

                    Button(action: {
                        if !showAll && revealedCount < results.count - 1 {
                            withAnimation(.spring()) { revealedCount += 1 }
                            HapticsService.shared.selection()
                        } else {
                            dismiss()
                        }
                    }) {
                        Text(showAll || revealedCount >= results.count - 1 ? "Done" : "Next")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct BattlePassTierCard: View {
    let tier: Int
    let isUnlocked: Bool
    let isPremium: Bool
    var onClaim: (() -> Void)?

    @State private var claimed = false

    var body: some View {
        Button(action: {
            if isUnlocked && !claimed {
                claimed = true
                onClaim?()
            }
        }) {
            VStack(spacing: 4) {
                Text("T\(tier)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isPremium && tier % 3 == 0 ? .yellow : .secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(claimed ? .green.opacity(0.5) : isUnlocked ? .green.opacity(0.3) : .gray.opacity(0.15))
                        .frame(width: 50, height: 50)

                    if claimed {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: rewardIcon(tier))
                            .font(.title3)
                            .foregroundStyle(isUnlocked ? .white : .secondary)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPremium && tier % 3 == 0 ? .yellow.opacity(0.6) : isUnlocked ? .green : .gray.opacity(0.3), lineWidth: 1)
                )

                if isUnlocked && !claimed {
                    Text("Claim")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                } else if claimed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }
        }
        .disabled(!isUnlocked || claimed)
    }

    private func rewardIcon(_ tier: Int) -> String {
        switch tier % 5 {
        case 0: return "diamond.fill"
        case 1: return "circle.fill"
        case 2: return "dollarsign.circle.fill"
        case 3: return "star.fill"
        default: return "gift.fill"
        }
    }
}
