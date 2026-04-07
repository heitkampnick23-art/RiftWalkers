import Foundation
import Combine

// MARK: - Battle Manager
// Researched: Pokemon GO's swipe-combat was TOO simple (user churn).
// Genshin Impact's elemental reactions added depth.
// We use a hybrid: real-time with cooldown-based abilities + elemental combos.
// Goal: 30-second casual battles, 3-minute deep battles.

final class BattleManager: ObservableObject {
    static let shared = BattleManager()

    // MARK: - Published State

    @Published var battleState: BattleState = .idle
    @Published var playerCreatures: [BattleCreature] = []
    @Published var enemyCreatures: [BattleCreature] = []
    @Published var activePlayerCreature: BattleCreature?
    @Published var activeEnemyCreature: BattleCreature?
    @Published var battleLog: [BattleLogEntry] = []
    @Published var comboCounter: Int = 0
    @Published var elementalReactions: [ElementalReaction] = []
    @Published var turnNumber: Int = 0
    @Published var rewards: BattleRewards?

    // MARK: - Properties

    private let haptics = HapticsService.shared
    private let audio = AudioService.shared
    private var battleTimer: Timer?
    private var cooldownTimer: Timer?

    enum BattleState: Equatable {
        case idle
        case starting
        case playerTurn
        case enemyTurn
        case animating
        case victory
        case defeat
        case fled
    }

    // MARK: - Battle Creature (runtime wrapper)

    struct BattleCreature: Identifiable {
        let id: UUID
        var creature: Creature
        var currentHP: Int
        var maxHP: Int
        var statusEffects: [StatusEffect]
        var abilityCooldowns: [UUID: TimeInterval]
        var isActive: Bool

        var hpPercentage: Double { Double(currentHP) / Double(maxHP) }
        var isAlive: Bool { currentHP > 0 }
    }

    // MARK: - Battle Log

    struct BattleLogEntry: Identifiable {
        let id = UUID()
        let message: String
        let type: LogType
        let timestamp: Date

        enum LogType {
            case damage, heal, status, system, combo, critical
        }
    }

    // MARK: - Elemental Reactions (Genshin Impact inspired)

    struct ElementalReaction: Identifiable {
        let id = UUID()
        let name: String
        let elements: (Element, Element)
        let damageMultiplier: Double
        let description: String
    }

    // MARK: - Start Battle

    func startWildBattle(playerParty: [Creature], wildCreature: Creature) {
        battleState = .starting
        battleLog = []
        comboCounter = 0
        turnNumber = 0

        playerCreatures = playerParty.map { creature in
            BattleCreature(
                id: creature.id,
                creature: creature,
                currentHP: creature.currentHP,
                maxHP: creature.maxHP,
                statusEffects: [],
                abilityCooldowns: [:],
                isActive: false
            )
        }

        enemyCreatures = [BattleCreature(
            id: wildCreature.id,
            creature: wildCreature,
            currentHP: wildCreature.currentHP,
            maxHP: wildCreature.maxHP,
            statusEffects: [],
            abilityCooldowns: [:],
            isActive: true
        )]

        // Set first creature as active
        if !playerCreatures.isEmpty {
            playerCreatures[0].isActive = true
            activePlayerCreature = playerCreatures[0]
        }
        activeEnemyCreature = enemyCreatures.first

        audio.playMusic(.battleNormal)
        haptics.creatureEncounter()

        addLog("A wild \(wildCreature.name) appeared!", type: .system)

        // Transition to player turn
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.battleState = .playerTurn
            self.turnNumber = 1
            self.startCooldownTimer()
        }
    }

    func startPvPBattle(playerParty: [Creature], opponentParty: [Creature]) {
        battleState = .starting
        audio.playMusic(.battlePvP)
        // Similar setup but with opponent creatures
        addLog("PvP Battle started!", type: .system)
    }

    func startRaidBattle(playerParty: [Creature], boss: Creature) {
        battleState = .starting
        audio.playMusic(.battleBoss)
        addLog("Raid Boss \(boss.name) challenges you!", type: .system)
    }

    // MARK: - Player Actions

    func useAbility(_ ability: Ability) {
        guard battleState == .playerTurn,
              var attacker = activePlayerCreature,
              var defender = activeEnemyCreature else { return }

        // Check cooldown
        if let cooldown = attacker.abilityCooldowns[ability.id], cooldown > 0 {
            addLog("\(ability.name) is on cooldown!", type: .system)
            return
        }

        battleState = .animating

        // Accuracy check
        let accuracyRoll = Double.random(in: 0...1)
        guard accuracyRoll <= ability.accuracy else {
            addLog("\(attacker.creature.displayName)'s \(ability.name) missed!", type: .system)
            audio.playSFX(.battleMiss)
            endPlayerTurn()
            return
        }

        // Damage calculation
        var damage = calculateDamage(
            ability: ability,
            attacker: attacker.creature,
            defender: defender.creature
        )

        // Critical hit (10% base chance)
        let isCritical = Double.random(in: 0...1) < 0.1 + (attacker.creature.passiveAbility?.effect == .critRateUp ? 0.15 : 0)
        if isCritical {
            damage = Int(Double(damage) * 1.5)
            addLog("Critical hit!", type: .critical)
            haptics.battleCritical()
            audio.playSFX(.battleCrit)
        } else {
            haptics.battleHit()
            audio.playSFX(.battleHit)
        }

        // Elemental effectiveness
        let effectiveness = calculateEffectiveness(ability.element, against: defender.creature.element)
        damage = Int(Double(damage) * effectiveness.multiplier)
        if effectiveness.multiplier > 1.0 {
            addLog("It's super effective!", type: .combo)
        } else if effectiveness.multiplier < 1.0 {
            addLog("It's not very effective...", type: .system)
        }

        // Check for elemental reaction
        if let reaction = checkElementalReaction(ability.element, target: defender) {
            damage = Int(Double(damage) * reaction.damageMultiplier)
            addLog("\(reaction.name)! \(reaction.description)", type: .combo)
            comboCounter += 1
            elementalReactions.append(reaction)
        }

        // Apply damage
        defender.currentHP = max(0, defender.currentHP - damage)
        addLog("\(attacker.creature.displayName) used \(ability.name) for \(damage) damage!", type: .damage)

        // Set cooldown
        attacker.abilityCooldowns[ability.id] = ability.cooldown

        // Update state
        updateCreatureState(attacker: &attacker, defender: &defender)

        // Check victory
        if !defender.isAlive {
            handleEnemyDefeated(defender)
        } else {
            endPlayerTurn()
        }
    }

    func useItem(_ item: InventoryItem) {
        guard battleState == .playerTurn else { return }

        switch item.type {
        case .potion:
            guard var active = activePlayerCreature else { return }
            let healAmount = item.effects.first(where: { $0.type == .heal })?.value ?? 50
            active.currentHP = min(active.maxHP, active.currentHP + Int(healAmount))
            addLog("Used \(item.name)! Healed \(Int(healAmount)) HP.", type: .heal)
            audio.playSFX(.itemUse)
            activePlayerCreature = active
            endPlayerTurn()
        default:
            break
        }
    }

    func swapCreature(to index: Int) {
        guard battleState == .playerTurn,
              index < playerCreatures.count,
              playerCreatures[index].isAlive else { return }

        // Deactivate current
        if let currentIndex = playerCreatures.firstIndex(where: { $0.isActive }) {
            playerCreatures[currentIndex].isActive = false
        }

        // Activate new
        playerCreatures[index].isActive = true
        activePlayerCreature = playerCreatures[index]
        addLog("Go, \(playerCreatures[index].creature.displayName)!", type: .system)

        endPlayerTurn()
    }

    func attemptFlee() {
        guard battleState == .playerTurn else { return }

        let fleeChance = 0.5 + (Double(activePlayerCreature?.creature.speed ?? 50) / 200.0)
        if Double.random(in: 0...1) < fleeChance {
            battleState = .fled
            addLog("Got away safely!", type: .system)
            endBattle()
        } else {
            addLog("Can't escape!", type: .system)
            endPlayerTurn()
        }
    }

    func attemptCapture(sphereType: String) {
        guard battleState == .playerTurn,
              let enemy = activeEnemyCreature else { return }

        let baseRate = captureRate(for: sphereType)
        let hpFactor = 1.0 - (Double(enemy.currentHP) / Double(enemy.maxHP)) * 0.5
        let rarityFactor = 1.0 / Double(enemy.creature.rarity.stars)
        let statusBonus = enemy.statusEffects.isEmpty ? 0.0 : 0.15

        let captureChance = min(0.95, baseRate * hpFactor * rarityFactor + statusBonus)

        audio.playSFX(.sphereThrow)
        battleState = .animating

        // Simulate shake animation
        let shakes = Int.random(in: 1...3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 * Double(shakes)) {
            if Double.random(in: 0...1) < captureChance {
                // Captured!
                self.audio.playSFX(.creatureCapture)
                self.haptics.captureSuccess()
                self.addLog("Caught \(enemy.creature.displayName)!", type: .system)
                self.battleState = .victory
                self.endBattle()
            } else {
                self.audio.playSFX(.creatureEscape)
                self.haptics.captureFailure()
                self.addLog("\(enemy.creature.displayName) broke free!", type: .system)
                self.endPlayerTurn()
            }
        }
    }

    // MARK: - Enemy AI

    private func executeEnemyTurn() {
        guard battleState == .enemyTurn,
              var enemy = activeEnemyCreature,
              var player = activePlayerCreature else { return }

        battleState = .animating

        // Simple AI: choose best available ability
        let availableAbilities = enemy.creature.abilities.filter { ability in
            let cooldown = enemy.abilityCooldowns[ability.id] ?? 0
            return cooldown <= 0
        }

        guard let chosenAbility = availableAbilities.randomElement() ?? enemy.creature.abilities.first else {
            endEnemyTurn()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let accuracyRoll = Double.random(in: 0...1)
            guard accuracyRoll <= chosenAbility.accuracy else {
                self.addLog("\(enemy.creature.displayName)'s \(chosenAbility.name) missed!", type: .system)
                self.endEnemyTurn()
                return
            }

            var damage = self.calculateDamage(
                ability: chosenAbility,
                attacker: enemy.creature,
                defender: player.creature
            )

            let isCritical = Double.random(in: 0...1) < 0.1
            if isCritical {
                damage = Int(Double(damage) * 1.5)
                self.addLog("Critical hit!", type: .critical)
            }

            let effectiveness = self.calculateEffectiveness(chosenAbility.element, against: player.creature.element)
            damage = Int(Double(damage) * effectiveness.multiplier)

            player.currentHP = max(0, player.currentHP - damage)
            self.addLog("\(enemy.creature.displayName) used \(chosenAbility.name) for \(damage) damage!", type: .damage)
            self.haptics.battleHit()

            enemy.abilityCooldowns[chosenAbility.id] = chosenAbility.cooldown

            self.updateCreatureState(attacker: &enemy, defender: &player)

            if !player.isAlive {
                self.handlePlayerCreatureDefeated()
            } else {
                self.endEnemyTurn()
            }
        }
    }

    // MARK: - Turn Management

    private func endPlayerTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.processStatusEffects(for: &self.playerCreatures)
            self.battleState = .enemyTurn
            self.executeEnemyTurn()
        }
    }

    private func endEnemyTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.processStatusEffects(for: &self.enemyCreatures)
            self.turnNumber += 1
            self.tickCooldowns()
            self.battleState = .playerTurn
        }
    }

    // MARK: - Damage Calculation

    private func calculateDamage(ability: Ability, attacker: Creature, defender: Creature) -> Int {
        let attackStat = ability.power > 80 ? attacker.special : attacker.attack
        let defenseStat = ability.power > 80 ? defender.special : defender.defense
        let levelModifier = Double(attacker.level) / 50.0 + 0.5

        let baseDamage = Double(ability.power) * (Double(attackStat) / Double(max(1, defenseStat))) * levelModifier
        let variance = Double.random(in: 0.85...1.15)

        return max(1, Int(baseDamage * variance))
    }

    private func calculateEffectiveness(_ attackElement: Element, against defenseElement: Element) -> (multiplier: Double, description: String) {
        let advantages: [Element: [Element]] = [
            .fire: [.nature, .ice],
            .water: [.fire, .earth],
            .earth: [.lightning, .fire],
            .wind: [.earth, .nature],
            .lightning: [.water, .wind],
            .ice: [.wind, .nature],
            .shadow: [.light, .nature],
            .light: [.shadow, .void],
            .void: [.light, .lightning],
            .nature: [.water, .earth]
        ]

        if advantages[attackElement]?.contains(defenseElement) == true {
            return (1.5, "Super effective")
        }
        if advantages[defenseElement]?.contains(attackElement) == true {
            return (0.67, "Not very effective")
        }
        return (1.0, "Normal")
    }

    // MARK: - Elemental Reactions

    private func checkElementalReaction(_ element: Element, target: BattleCreature) -> ElementalReaction? {
        let activeStatus = target.statusEffects.map { $0.type }

        // Fire + Ice = Melt (2x)
        if element == .fire && activeStatus.contains(.freeze) {
            return ElementalReaction(name: "Melt", elements: (.fire, .ice), damageMultiplier: 2.0, description: "The ice shatters violently!")
        }
        // Water + Lightning = Electro-Charge (1.8x)
        if element == .lightning && target.creature.element == .water {
            return ElementalReaction(name: "Electro-Charge", elements: (.lightning, .water), damageMultiplier: 1.8, description: "Electricity surges through the water!")
        }
        // Fire + Wind = Swirl (1.5x)
        if element == .wind && activeStatus.contains(.burn) {
            return ElementalReaction(name: "Firestorm", elements: (.wind, .fire), damageMultiplier: 1.5, description: "Wind fans the flames into a storm!")
        }
        // Shadow + Light = Annihilation (2.5x but rare)
        if (element == .shadow && target.creature.element == .light) ||
           (element == .light && target.creature.element == .shadow) {
            return ElementalReaction(name: "Annihilation", elements: (.shadow, .light), damageMultiplier: 2.5, description: "Light and shadow collide catastrophically!")
        }

        return nil
    }

    // MARK: - Status Effects

    private func processStatusEffects(for creatures: inout [BattleCreature]) {
        for i in creatures.indices {
            var toRemove: [Int] = []
            for j in creatures[i].statusEffects.indices {
                switch creatures[i].statusEffects[j].type {
                case .burn:
                    let burnDamage = Int(Double(creatures[i].maxHP) * 0.05)
                    creatures[i].currentHP = max(0, creatures[i].currentHP - burnDamage)
                    addLog("\(creatures[i].creature.displayName) takes \(burnDamage) burn damage!", type: .damage)
                case .poison:
                    let poisonDamage = Int(Double(creatures[i].maxHP) * 0.08)
                    creatures[i].currentHP = max(0, creatures[i].currentHP - poisonDamage)
                    addLog("\(creatures[i].creature.displayName) takes \(poisonDamage) poison damage!", type: .damage)
                case .bless:
                    let healAmount = Int(Double(creatures[i].maxHP) * 0.05)
                    creatures[i].currentHP = min(creatures[i].maxHP, creatures[i].currentHP + healAmount)
                    addLog("\(creatures[i].creature.displayName) heals \(healAmount) from blessing!", type: .heal)
                default:
                    break
                }

                creatures[i].statusEffects[j].turnsRemaining -= 1
                if creatures[i].statusEffects[j].turnsRemaining <= 0 {
                    toRemove.append(j)
                }
            }

            for index in toRemove.reversed() {
                creatures[i].statusEffects.remove(at: index)
            }
        }
    }

    // MARK: - Cooldown Management

    private func startCooldownTimer() {
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickCooldowns()
        }
    }

    private func tickCooldowns() {
        for i in playerCreatures.indices {
            for (abilityID, cooldown) in playerCreatures[i].abilityCooldowns {
                playerCreatures[i].abilityCooldowns[abilityID] = max(0, cooldown - 1)
            }
        }
        for i in enemyCreatures.indices {
            for (abilityID, cooldown) in enemyCreatures[i].abilityCooldowns {
                enemyCreatures[i].abilityCooldowns[abilityID] = max(0, cooldown - 1)
            }
        }
    }

    // MARK: - Battle Resolution

    private func handleEnemyDefeated(_ enemy: BattleCreature) {
        addLog("\(enemy.creature.displayName) was defeated!", type: .system)

        // Check if more enemies
        let remainingEnemies = enemyCreatures.filter { $0.isAlive && $0.id != enemy.id }
        if remainingEnemies.isEmpty {
            battleState = .victory
            audio.playMusic(.victory)
            haptics.levelUp()
            endBattle()
        } else {
            // Next enemy
            if let nextIndex = enemyCreatures.firstIndex(where: { $0.isAlive && $0.id != enemy.id }) {
                enemyCreatures[nextIndex].isActive = true
                activeEnemyCreature = enemyCreatures[nextIndex]
                endPlayerTurn()
            }
        }
    }

    private func handlePlayerCreatureDefeated() {
        guard let defeated = activePlayerCreature else { return }
        addLog("\(defeated.creature.displayName) fainted!", type: .system)

        let remaining = playerCreatures.filter { $0.isAlive && $0.id != defeated.id }
        if remaining.isEmpty {
            battleState = .defeat
            audio.playMusic(.defeat)
            endBattle()
        } else {
            // Auto-switch to next alive creature
            if let nextIndex = playerCreatures.firstIndex(where: { $0.isAlive && $0.id != defeated.id }) {
                playerCreatures[nextIndex].isActive = true
                activePlayerCreature = playerCreatures[nextIndex]
                addLog("Go, \(playerCreatures[nextIndex].creature.displayName)!", type: .system)
                endEnemyTurn()
            }
        }
    }

    private func endBattle() {
        cooldownTimer?.invalidate()
        battleTimer?.invalidate()

        if battleState == .victory {
            rewards = BattleRewards(
                experience: 100 * turnNumber,
                gold: 50 + comboCounter * 10,
                items: [],
                pvpRatingChange: nil
            )
        }
    }

    private func updateCreatureState(attacker: inout BattleCreature, defender: inout BattleCreature) {
        // Update the arrays
        if let idx = playerCreatures.firstIndex(where: { $0.id == attacker.id }) {
            playerCreatures[idx] = attacker
            activePlayerCreature = attacker
        } else if let idx = enemyCreatures.firstIndex(where: { $0.id == attacker.id }) {
            enemyCreatures[idx] = attacker
            activeEnemyCreature = attacker
        }

        if let idx = playerCreatures.firstIndex(where: { $0.id == defender.id }) {
            playerCreatures[idx] = defender
            activePlayerCreature = defender
        } else if let idx = enemyCreatures.firstIndex(where: { $0.id == defender.id }) {
            enemyCreatures[idx] = defender
            activeEnemyCreature = defender
        }
    }

    private func captureRate(for sphereType: String) -> Double {
        switch sphereType {
        case "basic": return 0.3
        case "great": return 0.5
        case "ultra": return 0.7
        case "master": return 0.9
        case "mythic": return 0.95
        default: return 0.3
        }
    }

    // MARK: - Helpers

    private func addLog(_ message: String, type: BattleLogEntry.LogType) {
        battleLog.append(BattleLogEntry(message: message, type: type, timestamp: Date()))
    }
}
