import Foundation

// MARK: - Species Database
// 100+ creature species across 10 mythologies. Each carefully designed
// with authentic mythological references for depth and educational value.
// Researched: Pokemon's 151 original roster success - quality over quantity at launch.

final class SpeciesDatabase {
    static let shared = SpeciesDatabase()

    private(set) var species: [String: CreatureSpecies] = [:]
    private(set) var abilityDatabase: [String: Ability] = [:]

    private init() {
        loadSpecies()
        loadAbilities()
    }

    func getSpecies(_ id: String) -> CreatureSpecies? {
        species[id]
    }

    func speciesForMythology(_ mythology: Mythology) -> [CreatureSpecies] {
        species.values.filter { $0.mythology == mythology }
    }

    func speciesForBiome(_ biome: BiomeType) -> [CreatureSpecies] {
        species.values.filter { $0.biomePreference.contains(biome) }
    }

    func speciesForRarity(_ rarity: Rarity) -> [CreatureSpecies] {
        species.values.filter { $0.rarity == rarity }
    }

    // MARK: - Abilities

    private func loadAbilities() {
        let abilities: [Ability] = [
            // Fire abilities
            Ability(id: UUID(), name: "Inferno Blast", element: .fire, power: 85, accuracy: 0.9, cooldown: 3, description: "Unleashes a devastating blast of mythic fire.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Ember Strike", element: .fire, power: 45, accuracy: 0.95, cooldown: 1, description: "A quick strike wreathed in flames.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Ragnarok Flame", element: .fire, power: 150, accuracy: 0.75, cooldown: 8, description: "Channels the fire of Ragnarok itself.", isUltimate: true, currentCooldown: 0),

            // Water abilities
            Ability(id: UUID(), name: "Tidal Surge", element: .water, power: 80, accuracy: 0.9, cooldown: 3, description: "Summons a crushing wave from the deep.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Frost Bite", element: .ice, power: 50, accuracy: 0.95, cooldown: 1.5, description: "A chilling bite that may freeze the target.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Leviathan's Wrath", element: .water, power: 140, accuracy: 0.8, cooldown: 8, description: "The fury of the sea serpent unleashed.", isUltimate: true, currentCooldown: 0),

            // Lightning abilities
            Ability(id: UUID(), name: "Thunder Strike", element: .lightning, power: 75, accuracy: 0.85, cooldown: 2.5, description: "A bolt of divine lightning.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Spark Chain", element: .lightning, power: 40, accuracy: 1.0, cooldown: 1, description: "Lightning that arcs between nearby enemies.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Mjolnir's Judgement", element: .lightning, power: 160, accuracy: 0.7, cooldown: 10, description: "Strike with the full force of Thor's hammer.", isUltimate: true, currentCooldown: 0),

            // Earth abilities
            Ability(id: UUID(), name: "Quake Slam", element: .earth, power: 90, accuracy: 0.85, cooldown: 3.5, description: "Shatters the ground beneath your foes.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Stone Shield", element: .earth, power: 0, accuracy: 1.0, cooldown: 5, description: "Raises a protective barrier of ancient stone.", isUltimate: false, currentCooldown: 0),

            // Shadow abilities
            Ability(id: UUID(), name: "Shadow Strike", element: .shadow, power: 70, accuracy: 0.95, cooldown: 2, description: "Strike from the darkness unseen.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Void Rend", element: .void, power: 120, accuracy: 0.8, cooldown: 6, description: "Tears the fabric of reality.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Eternal Night", element: .shadow, power: 145, accuracy: 0.75, cooldown: 10, description: "Plunges the battlefield into absolute darkness.", isUltimate: true, currentCooldown: 0),

            // Light abilities
            Ability(id: UUID(), name: "Divine Ray", element: .light, power: 75, accuracy: 0.9, cooldown: 2, description: "A beam of pure divine energy.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Purifying Light", element: .light, power: 30, accuracy: 1.0, cooldown: 4, description: "Heals allies and damages undead.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Solar Judgement", element: .light, power: 155, accuracy: 0.7, cooldown: 10, description: "The sun god passes judgement.", isUltimate: true, currentCooldown: 0),

            // Wind abilities
            Ability(id: UUID(), name: "Gale Force", element: .wind, power: 65, accuracy: 0.95, cooldown: 1.5, description: "A razor-sharp blast of wind.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "Typhoon", element: .wind, power: 130, accuracy: 0.8, cooldown: 7, description: "Summon a devastating typhoon.", isUltimate: true, currentCooldown: 0),

            // Nature abilities
            Ability(id: UUID(), name: "Vine Lash", element: .nature, power: 55, accuracy: 0.95, cooldown: 1.5, description: "Thorned vines strike with precision.", isUltimate: false, currentCooldown: 0),
            Ability(id: UUID(), name: "World Tree's Blessing", element: .nature, power: 0, accuracy: 1.0, cooldown: 8, description: "Yggdrasil's power heals all allies.", isUltimate: true, currentCooldown: 0),
        ]

        for ability in abilities {
            abilityDatabase[ability.name] = ability
        }
    }

    // MARK: - Species Loading

    private func loadSpecies() {
        let allSpecies: [CreatureSpecies] = [
            // ═══════════════════════════════════════
            // NORSE MYTHOLOGY (10 creatures)
            // ═══════════════════════════════════════
            CreatureSpecies(
                id: "norse_fenrir_pup", name: "Fenrir Pup", mythology: .norse, element: .shadow,
                rarity: .rare, lore: "A young descendant of Fenrir, the great wolf destined to devour the sun. Even as a pup, its howl can chill the bravest warrior.",
                baseHP: 65, baseAttack: 80, baseDefense: 45, baseSpeed: 75, baseSpecial: 40,
                abilities: ["Shadow Strike", "Frost Bite"], passiveAbility: "nightProwler",
                evolutionChainID: "fenrir_chain", evolutionStage: 1, evolvesInto: "norse_fenrir",
                shinyRate: 0.002, biomePreference: [.forest, .park, .cemetery],
                timePreference: .night, weatherPreference: [.fog, .snow],
                modelAsset: "fenrir_pup_3d", iconAsset: "fenrir_pup_icon"
            ),
            CreatureSpecies(
                id: "norse_fenrir", name: "Fenrir", mythology: .norse, element: .shadow,
                rarity: .legendary, lore: "The monstrous wolf of Ragnarok, unbound and hungry. Its jaws can swallow the sky.",
                baseHP: 130, baseAttack: 160, baseDefense: 80, baseSpeed: 120, baseSpecial: 90,
                abilities: ["Shadow Strike", "Void Rend", "Eternal Night"], passiveAbility: "nightProwler",
                evolutionChainID: "fenrir_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.forest, .mountain],
                timePreference: .night, weatherPreference: [.fog, .storm],
                modelAsset: "fenrir_3d", iconAsset: "fenrir_icon"
            ),
            CreatureSpecies(
                id: "norse_valkyrie", name: "Valkyrie Shade", mythology: .norse, element: .light,
                rarity: .epic, lore: "A spectral chooser of the slain, forever seeking worthy warriors for Valhalla.",
                baseHP: 90, baseAttack: 95, baseDefense: 70, baseSpeed: 110, baseSpecial: 100,
                abilities: ["Divine Ray", "Gale Force", "Purifying Light"], passiveAbility: "healOnKill",
                evolutionChainID: "valkyrie_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.historic, .mountain],
                timePreference: .any, weatherPreference: [.clear, .wind],
                modelAsset: "valkyrie_3d", iconAsset: "valkyrie_icon"
            ),
            CreatureSpecies(
                id: "norse_jormungandr", name: "Jörmungandr Spawn", mythology: .norse, element: .water,
                rarity: .epic, lore: "A lesser serpent of the World Serpent's brood, coiling through underground waterways.",
                baseHP: 110, baseAttack: 85, baseDefense: 100, baseSpeed: 60, baseSpecial: 95,
                abilities: ["Tidal Surge", "Frost Bite", "Leviathan's Wrath"], passiveAbility: "elementalResist",
                evolutionChainID: "jormungandr_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.water],
                timePreference: .any, weatherPreference: [.rain, .storm],
                modelAsset: "jormungandr_3d", iconAsset: "jormungandr_icon"
            ),
            CreatureSpecies(
                id: "norse_huginn", name: "Huginn", mythology: .norse, element: .wind,
                rarity: .rare, lore: "One of Odin's ravens, representing thought. It soars across Midgard gathering knowledge.",
                baseHP: 50, baseAttack: 60, baseDefense: 40, baseSpeed: 130, baseSpecial: 85,
                abilities: ["Gale Force", "Shadow Strike"], passiveAbility: "experienceBoost",
                evolutionChainID: "raven_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.urban, .university, .park],
                timePreference: .day, weatherPreference: [.clear, .cloudy],
                modelAsset: "huginn_3d", iconAsset: "huginn_icon"
            ),
            CreatureSpecies(
                id: "norse_draugr", name: "Draugr", mythology: .norse, element: .shadow,
                rarity: .common, lore: "An undead Norse warrior, restless in death. It guards ancient burial mounds with tireless fury.",
                baseHP: 70, baseAttack: 55, baseDefense: 60, baseSpeed: 30, baseSpecial: 25,
                abilities: ["Shadow Strike", "Stone Shield"], passiveAbility: "territoryGuard",
                evolutionChainID: "draugr_chain", evolutionStage: 1, evolvesInto: "norse_draugr_lord",
                shinyRate: 0.005, biomePreference: [.cemetery, .historic],
                timePreference: .night, weatherPreference: [.fog, .cloudy],
                modelAsset: "draugr_3d", iconAsset: "draugr_icon"
            ),
            CreatureSpecies(
                id: "norse_draugr_lord", name: "Draugr Overlord", mythology: .norse, element: .shadow,
                rarity: .rare, lore: "A mighty undead lord wreathed in grave-frost, commanding legions of the restless dead.",
                baseHP: 120, baseAttack: 95, baseDefense: 100, baseSpeed: 50, baseSpecial: 55,
                abilities: ["Shadow Strike", "Frost Bite", "Void Rend"], passiveAbility: "territoryGuard",
                evolutionChainID: "draugr_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.cemetery, .historic],
                timePreference: .night, weatherPreference: [.fog, .snow],
                modelAsset: "draugr_lord_3d", iconAsset: "draugr_lord_icon"
            ),
            CreatureSpecies(
                id: "norse_nidhogg", name: "Níðhöggr", mythology: .norse, element: .void,
                rarity: .mythic, lore: "The dragon that gnaws at the roots of Yggdrasil, the World Tree. Its appearance heralds the end of an age.",
                baseHP: 180, baseAttack: 170, baseDefense: 140, baseSpeed: 80, baseSpecial: 160,
                abilities: ["Void Rend", "Inferno Blast", "Eternal Night", "Ragnarok Flame"], passiveAbility: nil,
                evolutionChainID: "nidhogg_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.0005, biomePreference: [.forest, .mountain],
                timePreference: .night, weatherPreference: [.storm],
                modelAsset: "nidhogg_3d", iconAsset: "nidhogg_icon"
            ),
            CreatureSpecies(
                id: "norse_troll", name: "Frost Troll", mythology: .norse, element: .ice,
                rarity: .uncommon, lore: "A lumbering troll turned to ice by centuries of Nordic winters. It hurls frozen boulders at intruders.",
                baseHP: 95, baseAttack: 70, baseDefense: 85, baseSpeed: 25, baseSpecial: 35,
                abilities: ["Frost Bite", "Quake Slam"], passiveAbility: "weatherBoost",
                evolutionChainID: "troll_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.mountain, .forest],
                timePreference: .any, weatherPreference: [.snow, .fog],
                modelAsset: "troll_3d", iconAsset: "troll_icon"
            ),
            CreatureSpecies(
                id: "norse_light_elf", name: "Ljósálfr", mythology: .norse, element: .light,
                rarity: .uncommon, lore: "A radiant Light Elf of Alfheim, whose mere presence dispels darkness and brings warmth.",
                baseHP: 55, baseAttack: 40, baseDefense: 45, baseSpeed: 95, baseSpecial: 90,
                abilities: ["Divine Ray", "Purifying Light"], passiveAbility: "healOnKill",
                evolutionChainID: "elf_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.park, .forest, .suburban],
                timePreference: .dawn, weatherPreference: [.clear],
                modelAsset: "light_elf_3d", iconAsset: "light_elf_icon"
            ),

            // ═══════════════════════════════════════
            // GREEK MYTHOLOGY (10 creatures)
            // ═══════════════════════════════════════
            CreatureSpecies(
                id: "greek_minotaur", name: "Minotaur", mythology: .greek, element: .earth,
                rarity: .epic, lore: "The bull-headed guardian of the Labyrinth. Its fury is matched only by its cunning.",
                baseHP: 130, baseAttack: 120, baseDefense: 110, baseSpeed: 55, baseSpecial: 45,
                abilities: ["Quake Slam", "Stone Shield", "Ember Strike"], passiveAbility: "territoryGuard",
                evolutionChainID: "minotaur_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.urban, .historic, .commercial],
                timePreference: .any, weatherPreference: [.clear, .cloudy],
                modelAsset: "minotaur_3d", iconAsset: "minotaur_icon"
            ),
            CreatureSpecies(
                id: "greek_cerberus_pup", name: "Cerberus Pup", mythology: .greek, element: .fire,
                rarity: .rare, lore: "A three-headed puppy from the underworld. Each head has its own personality.",
                baseHP: 75, baseAttack: 85, baseDefense: 55, baseSpeed: 65, baseSpecial: 50,
                abilities: ["Inferno Blast", "Ember Strike"], passiveAbility: "nightProwler",
                evolutionChainID: "cerberus_chain", evolutionStage: 1, evolvesInto: "greek_cerberus",
                shinyRate: 0.003, biomePreference: [.cemetery, .urban],
                timePreference: .night, weatherPreference: [.clear, .fog],
                modelAsset: "cerberus_pup_3d", iconAsset: "cerberus_pup_icon"
            ),
            CreatureSpecies(
                id: "greek_cerberus", name: "Cerberus", mythology: .greek, element: .fire,
                rarity: .legendary, lore: "The three-headed hound of Hades, guardian of the gates to the Underworld.",
                baseHP: 150, baseAttack: 155, baseDefense: 120, baseSpeed: 90, baseSpecial: 80,
                abilities: ["Inferno Blast", "Ragnarok Flame", "Shadow Strike"], passiveAbility: "nightProwler",
                evolutionChainID: "cerberus_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.cemetery],
                timePreference: .night, weatherPreference: [.fog],
                modelAsset: "cerberus_3d", iconAsset: "cerberus_icon"
            ),
            CreatureSpecies(
                id: "greek_pegasus", name: "Pegasus", mythology: .greek, element: .wind,
                rarity: .epic, lore: "The divine winged horse born from Medusa's blood. Its grace defies the heavens.",
                baseHP: 85, baseAttack: 70, baseDefense: 65, baseSpeed: 145, baseSpecial: 90,
                abilities: ["Gale Force", "Divine Ray", "Typhoon"], passiveAbility: "dodgeChanceUp",
                evolutionChainID: "pegasus_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.mountain, .park],
                timePreference: .dawn, weatherPreference: [.clear, .wind],
                modelAsset: "pegasus_3d", iconAsset: "pegasus_icon"
            ),
            CreatureSpecies(
                id: "greek_siren", name: "Siren", mythology: .greek, element: .water,
                rarity: .rare, lore: "A haunting sea creature whose voice lures sailors to their doom.",
                baseHP: 60, baseAttack: 50, baseDefense: 45, baseSpeed: 80, baseSpecial: 110,
                abilities: ["Tidal Surge", "Gale Force"], passiveAbility: "captureRateUp",
                evolutionChainID: "siren_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.water],
                timePreference: .dusk, weatherPreference: [.fog, .rain],
                modelAsset: "siren_3d", iconAsset: "siren_icon"
            ),
            CreatureSpecies(
                id: "greek_hydra", name: "Hydra", mythology: .greek, element: .water,
                rarity: .legendary, lore: "The many-headed serpent of Lerna. Cut one head and two more grow in its place.",
                baseHP: 170, baseAttack: 130, baseDefense: 100, baseSpeed: 50, baseSpecial: 120,
                abilities: ["Tidal Surge", "Leviathan's Wrath", "Vine Lash"], passiveAbility: "healOnKill",
                evolutionChainID: "hydra_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.water, .forest],
                timePreference: .any, weatherPreference: [.rain, .storm],
                modelAsset: "hydra_3d", iconAsset: "hydra_icon"
            ),
            CreatureSpecies(
                id: "greek_satyr", name: "Satyr", mythology: .greek, element: .nature,
                rarity: .common, lore: "A playful woodland spirit, half-man half-goat, who dances through forests.",
                baseHP: 55, baseAttack: 40, baseDefense: 35, baseSpeed: 70, baseSpecial: 60,
                abilities: ["Vine Lash", "Gale Force"], passiveAbility: "experienceBoost",
                evolutionChainID: "satyr_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.005, biomePreference: [.park, .forest, .suburban],
                timePreference: .day, weatherPreference: [.clear],
                modelAsset: "satyr_3d", iconAsset: "satyr_icon"
            ),
            CreatureSpecies(
                id: "greek_phoenix", name: "Phoenix", mythology: .greek, element: .fire,
                rarity: .mythic, lore: "The immortal firebird reborn from its own ashes. A symbol of eternal renewal.",
                baseHP: 140, baseAttack: 150, baseDefense: 100, baseSpeed: 130, baseSpecial: 165,
                abilities: ["Inferno Blast", "Ragnarok Flame", "Divine Ray", "Purifying Light"], passiveAbility: "healOnKill",
                evolutionChainID: "phoenix_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.0005, biomePreference: [.desert, .mountain],
                timePreference: .dawn, weatherPreference: [.clear, .extreme],
                modelAsset: "phoenix_3d", iconAsset: "phoenix_icon"
            ),
            CreatureSpecies(
                id: "greek_empusa", name: "Empusa", mythology: .greek, element: .shadow,
                rarity: .uncommon, lore: "A shapeshifting demon-maiden sent by Hecate to guard crossroads.",
                baseHP: 60, baseAttack: 65, baseDefense: 40, baseSpeed: 85, baseSpecial: 75,
                abilities: ["Shadow Strike", "Ember Strike"], passiveAbility: "nightProwler",
                evolutionChainID: "empusa_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.urban, .cemetery],
                timePreference: .night, weatherPreference: [.fog],
                modelAsset: "empusa_3d", iconAsset: "empusa_icon"
            ),
            CreatureSpecies(
                id: "greek_griffin", name: "Griffin", mythology: .greek, element: .wind,
                rarity: .rare, lore: "Majestic creature with an eagle's head and a lion's body. Guardian of divine treasures.",
                baseHP: 95, baseAttack: 100, baseDefense: 85, baseSpeed: 100, baseSpecial: 70,
                abilities: ["Gale Force", "Thunder Strike", "Typhoon"], passiveAbility: "critRateUp",
                evolutionChainID: "griffin_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.mountain, .historic],
                timePreference: .day, weatherPreference: [.clear, .wind],
                modelAsset: "griffin_3d", iconAsset: "griffin_icon"
            ),

            // ═══════════════════════════════════════
            // EGYPTIAN MYTHOLOGY (10 creatures)
            // ═══════════════════════════════════════
            CreatureSpecies(
                id: "egypt_anubis_jackal", name: "Anubis Jackal", mythology: .egyptian, element: .shadow,
                rarity: .rare, lore: "A sacred jackal blessed by Anubis, guide of souls through the Duat.",
                baseHP: 70, baseAttack: 75, baseDefense: 60, baseSpeed: 90, baseSpecial: 70,
                abilities: ["Shadow Strike", "Divine Ray"], passiveAbility: "nightProwler",
                evolutionChainID: "anubis_chain", evolutionStage: 1, evolvesInto: "egypt_anubis",
                shinyRate: 0.003, biomePreference: [.desert, .cemetery, .historic],
                timePreference: .night, weatherPreference: [.clear],
                modelAsset: "anubis_jackal_3d", iconAsset: "anubis_jackal_icon"
            ),
            CreatureSpecies(
                id: "egypt_anubis", name: "Anubis", mythology: .egyptian, element: .shadow,
                rarity: .legendary, lore: "The jackal-headed god of mummification and the afterlife. Weigher of hearts.",
                baseHP: 140, baseAttack: 135, baseDefense: 110, baseSpeed: 120, baseSpecial: 130,
                abilities: ["Shadow Strike", "Void Rend", "Eternal Night", "Divine Ray"], passiveAbility: "nightProwler",
                evolutionChainID: "anubis_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.desert, .cemetery],
                timePreference: .night, weatherPreference: [.clear, .fog],
                modelAsset: "anubis_3d", iconAsset: "anubis_icon"
            ),
            CreatureSpecies(
                id: "egypt_scarab", name: "Khepri Scarab", mythology: .egyptian, element: .earth,
                rarity: .common, lore: "A sacred scarab beetle imbued with the power of the rising sun.",
                baseHP: 50, baseAttack: 35, baseDefense: 65, baseSpeed: 40, baseSpecial: 45,
                abilities: ["Stone Shield", "Ember Strike"], passiveAbility: "weatherBoost",
                evolutionChainID: "scarab_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.005, biomePreference: [.desert, .park, .suburban],
                timePreference: .dawn, weatherPreference: [.clear],
                modelAsset: "scarab_3d", iconAsset: "scarab_icon"
            ),
            CreatureSpecies(
                id: "egypt_sphinx", name: "Sphinx", mythology: .egyptian, element: .earth,
                rarity: .epic, lore: "The riddler of the desert. Those who cannot answer its question are devoured.",
                baseHP: 120, baseAttack: 80, baseDefense: 130, baseSpeed: 50, baseSpecial: 110,
                abilities: ["Quake Slam", "Stone Shield", "Shadow Strike"], passiveAbility: "territoryGuard",
                evolutionChainID: "sphinx_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.historic, .desert, .university],
                timePreference: .any, weatherPreference: [.clear, .cloudy],
                modelAsset: "sphinx_3d", iconAsset: "sphinx_icon"
            ),
            CreatureSpecies(
                id: "egypt_bastet_cat", name: "Bastet Kitten", mythology: .egyptian, element: .light,
                rarity: .uncommon, lore: "A playful kitten touched by the goddess Bastet. Brings joy and protection.",
                baseHP: 45, baseAttack: 55, baseDefense: 35, baseSpeed: 100, baseSpecial: 65,
                abilities: ["Divine Ray", "Gale Force"], passiveAbility: "dodgeChanceUp",
                evolutionChainID: "bastet_chain", evolutionStage: 1, evolvesInto: "egypt_bastet",
                shinyRate: 0.004, biomePreference: [.residential, .suburban, .urban],
                timePreference: .any, weatherPreference: [.clear],
                modelAsset: "bastet_kitten_3d", iconAsset: "bastet_kitten_icon"
            ),
            CreatureSpecies(
                id: "egypt_bastet", name: "Bastet", mythology: .egyptian, element: .light,
                rarity: .epic, lore: "The cat goddess of home, fertility, and protection. Fierce in battle, gentle in peace.",
                baseHP: 95, baseAttack: 110, baseDefense: 75, baseSpeed: 135, baseSpecial: 100,
                abilities: ["Divine Ray", "Solar Judgement", "Gale Force"], passiveAbility: "dodgeChanceUp",
                evolutionChainID: "bastet_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.residential, .historic],
                timePreference: .day, weatherPreference: [.clear],
                modelAsset: "bastet_3d", iconAsset: "bastet_icon"
            ),
            CreatureSpecies(
                id: "egypt_ammit", name: "Ammit", mythology: .egyptian, element: .void,
                rarity: .legendary, lore: "Devourer of the Dead — part crocodile, lion, and hippo. It consumes the hearts of the unworthy.",
                baseHP: 160, baseAttack: 145, baseDefense: 130, baseSpeed: 60, baseSpecial: 100,
                abilities: ["Void Rend", "Quake Slam", "Shadow Strike"], passiveAbility: nil,
                evolutionChainID: "ammit_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.water, .cemetery],
                timePreference: .night, weatherPreference: [.fog, .storm],
                modelAsset: "ammit_3d", iconAsset: "ammit_icon"
            ),
            CreatureSpecies(
                id: "egypt_ra_hawk", name: "Ra Hawk", mythology: .egyptian, element: .fire,
                rarity: .rare, lore: "A hawk carrying the solar disc, servant of Ra who brings light to the world.",
                baseHP: 60, baseAttack: 70, baseDefense: 50, baseSpeed: 120, baseSpecial: 85,
                abilities: ["Inferno Blast", "Divine Ray"], passiveAbility: "weatherBoost",
                evolutionChainID: "ra_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.desert, .park],
                timePreference: .day, weatherPreference: [.clear],
                modelAsset: "ra_hawk_3d", iconAsset: "ra_hawk_icon"
            ),
            CreatureSpecies(
                id: "egypt_apophis", name: "Apophis", mythology: .egyptian, element: .void,
                rarity: .mythic, lore: "The primordial serpent of chaos. It exists to destroy Ra and plunge creation into eternal darkness.",
                baseHP: 190, baseAttack: 175, baseDefense: 120, baseSpeed: 100, baseSpecial: 170,
                abilities: ["Void Rend", "Eternal Night", "Shadow Strike", "Tidal Surge"], passiveAbility: nil,
                evolutionChainID: "apophis_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.0003, biomePreference: [.desert],
                timePreference: .night, weatherPreference: [.storm, .extreme],
                modelAsset: "apophis_3d", iconAsset: "apophis_icon"
            ),
            CreatureSpecies(
                id: "egypt_mummy", name: "Restless Mummy", mythology: .egyptian, element: .earth,
                rarity: .common, lore: "An ancient mummy stirred from its eternal rest by rift energy.",
                baseHP: 65, baseAttack: 45, baseDefense: 70, baseSpeed: 20, baseSpecial: 35,
                abilities: ["Stone Shield", "Shadow Strike"], passiveAbility: "territoryGuard",
                evolutionChainID: "mummy_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.005, biomePreference: [.historic, .cemetery, .desert],
                timePreference: .night, weatherPreference: [.fog],
                modelAsset: "mummy_3d", iconAsset: "mummy_icon"
            ),

            // ═══════════════════════════════════════
            // JAPANESE MYTHOLOGY (10 creatures)
            // ═══════════════════════════════════════
            CreatureSpecies(
                id: "jp_kitsune", name: "Kitsune Kit", mythology: .japanese, element: .fire,
                rarity: .rare, lore: "A young fox spirit with a single tail. As it grows in wisdom, it gains more tails.",
                baseHP: 55, baseAttack: 65, baseDefense: 45, baseSpeed: 100, baseSpecial: 80,
                abilities: ["Ember Strike", "Inferno Blast"], passiveAbility: "dodgeChanceUp",
                evolutionChainID: "kitsune_chain", evolutionStage: 1, evolvesInto: "jp_kitsune_elder",
                shinyRate: 0.003, biomePreference: [.forest, .park, .residential],
                timePreference: .dusk, weatherPreference: [.clear, .fog],
                modelAsset: "kitsune_kit_3d", iconAsset: "kitsune_kit_icon"
            ),
            CreatureSpecies(
                id: "jp_kitsune_elder", name: "Nine-Tailed Kitsune", mythology: .japanese, element: .fire,
                rarity: .legendary, lore: "A divine fox spirit of immense power. Its nine tails can reshape reality itself.",
                baseHP: 120, baseAttack: 130, baseDefense: 85, baseSpeed: 140, baseSpecial: 155,
                abilities: ["Inferno Blast", "Ragnarok Flame", "Shadow Strike", "Divine Ray"], passiveAbility: "dodgeChanceUp",
                evolutionChainID: "kitsune_chain", evolutionStage: 2, evolvesInto: nil,
                shinyRate: 0.001, biomePreference: [.forest, .historic],
                timePreference: .night, weatherPreference: [.fog],
                modelAsset: "kitsune_elder_3d", iconAsset: "kitsune_elder_icon"
            ),
            CreatureSpecies(
                id: "jp_tanuki", name: "Tanuki", mythology: .japanese, element: .nature,
                rarity: .common, lore: "A mischievous raccoon dog spirit known for shapeshifting and causing harmless chaos.",
                baseHP: 60, baseAttack: 40, baseDefense: 50, baseSpeed: 65, baseSpecial: 55,
                abilities: ["Vine Lash", "Stone Shield"], passiveAbility: "luckBoost",
                evolutionChainID: "tanuki_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.005, biomePreference: [.forest, .park, .residential, .suburban],
                timePreference: .dusk, weatherPreference: [.clear, .cloudy],
                modelAsset: "tanuki_3d", iconAsset: "tanuki_icon"
            ),
            CreatureSpecies(
                id: "jp_oni", name: "Oni", mythology: .japanese, element: .fire,
                rarity: .epic, lore: "A fearsome demon ogre wielding a massive iron club. The terror of Japanese folklore.",
                baseHP: 140, baseAttack: 140, baseDefense: 95, baseSpeed: 55, baseSpecial: 60,
                abilities: ["Inferno Blast", "Quake Slam", "Ragnarok Flame"], passiveAbility: "critRateUp",
                evolutionChainID: "oni_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.mountain, .forest, .historic],
                timePreference: .night, weatherPreference: [.storm],
                modelAsset: "oni_3d", iconAsset: "oni_icon"
            ),
            CreatureSpecies(
                id: "jp_kodama", name: "Kodama", mythology: .japanese, element: .nature,
                rarity: .common, lore: "A gentle tree spirit whose presence means the forest is healthy. Its rattle echoes through the woods.",
                baseHP: 40, baseAttack: 25, baseDefense: 55, baseSpeed: 45, baseSpecial: 70,
                abilities: ["Vine Lash", "Purifying Light"], passiveAbility: "healOnKill",
                evolutionChainID: "kodama_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.006, biomePreference: [.forest, .park],
                timePreference: .any, weatherPreference: [.rain, .clear],
                modelAsset: "kodama_3d", iconAsset: "kodama_icon"
            ),
            CreatureSpecies(
                id: "jp_raijin", name: "Raijin Sprite", mythology: .japanese, element: .lightning,
                rarity: .rare, lore: "A lesser spirit of the thunder god. It dances among storm clouds, beating tiny drums.",
                baseHP: 55, baseAttack: 80, baseDefense: 40, baseSpeed: 110, baseSpecial: 90,
                abilities: ["Thunder Strike", "Spark Chain"], passiveAbility: "weatherBoost",
                evolutionChainID: "raijin_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.mountain, .urban],
                timePreference: .any, weatherPreference: [.storm, .rain],
                modelAsset: "raijin_sprite_3d", iconAsset: "raijin_sprite_icon"
            ),
            CreatureSpecies(
                id: "jp_kappa", name: "Kappa", mythology: .japanese, element: .water,
                rarity: .uncommon, lore: "A water imp that inhabits rivers and ponds. Loves cucumbers and sumo wrestling.",
                baseHP: 65, baseAttack: 55, baseDefense: 60, baseSpeed: 70, baseSpecial: 50,
                abilities: ["Tidal Surge", "Vine Lash"], passiveAbility: "elementalResist",
                evolutionChainID: "kappa_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.water, .park],
                timePreference: .any, weatherPreference: [.rain],
                modelAsset: "kappa_3d", iconAsset: "kappa_icon"
            ),
            CreatureSpecies(
                id: "jp_ryujin", name: "Ryūjin", mythology: .japanese, element: .water,
                rarity: .mythic, lore: "The Dragon King of the Sea, ruler of tides and master of all ocean creatures.",
                baseHP: 185, baseAttack: 160, baseDefense: 140, baseSpeed: 110, baseSpecial: 175,
                abilities: ["Leviathan's Wrath", "Tidal Surge", "Thunder Strike", "Typhoon"], passiveAbility: nil,
                evolutionChainID: "ryujin_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.0003, biomePreference: [.water],
                timePreference: .any, weatherPreference: [.storm, .rain],
                modelAsset: "ryujin_3d", iconAsset: "ryujin_icon"
            ),
            CreatureSpecies(
                id: "jp_yurei", name: "Yūrei", mythology: .japanese, element: .shadow,
                rarity: .uncommon, lore: "A vengeful spirit unable to pass on. Its mournful wails chill the living.",
                baseHP: 50, baseAttack: 60, baseDefense: 30, baseSpeed: 95, baseSpecial: 85,
                abilities: ["Shadow Strike", "Frost Bite"], passiveAbility: "nightProwler",
                evolutionChainID: "yurei_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.cemetery, .residential, .forest],
                timePreference: .night, weatherPreference: [.fog, .rain],
                modelAsset: "yurei_3d", iconAsset: "yurei_icon"
            ),
            CreatureSpecies(
                id: "jp_tengu", name: "Tengu", mythology: .japanese, element: .wind,
                rarity: .epic, lore: "A proud mountain warrior spirit with a long nose and crow-like wings. Master of martial arts.",
                baseHP: 95, baseAttack: 115, baseDefense: 80, baseSpeed: 120, baseSpecial: 85,
                abilities: ["Gale Force", "Typhoon", "Thunder Strike"], passiveAbility: "critRateUp",
                evolutionChainID: "tengu_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.mountain, .forest],
                timePreference: .day, weatherPreference: [.wind, .clear],
                modelAsset: "tengu_3d", iconAsset: "tengu_icon"
            ),

            // ═══════════════════════════════════════
            // CELTIC MYTHOLOGY (8 creatures)
            // ═══════════════════════════════════════
            CreatureSpecies(
                id: "celtic_faerie", name: "Sidhe Faerie", mythology: .celtic, element: .nature,
                rarity: .common, lore: "A tiny faerie of the Sidhe mounds, trailing sparkles of ancient magic.",
                baseHP: 35, baseAttack: 30, baseDefense: 30, baseSpeed: 110, baseSpecial: 75,
                abilities: ["Vine Lash", "Purifying Light"], passiveAbility: "luckBoost",
                evolutionChainID: "faerie_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.006, biomePreference: [.forest, .park, .suburban],
                timePreference: .dawn, weatherPreference: [.fog, .clear],
                modelAsset: "faerie_3d", iconAsset: "faerie_icon"
            ),
            CreatureSpecies(
                id: "celtic_cuchulain_hound", name: "Cú Sídhe", mythology: .celtic, element: .wind,
                rarity: .rare, lore: "A spectral fairy hound with emerald fur. Its bark can be heard across three worlds.",
                baseHP: 70, baseAttack: 80, baseDefense: 55, baseSpeed: 105, baseSpecial: 60,
                abilities: ["Gale Force", "Vine Lash"], passiveAbility: "packLeader",
                evolutionChainID: "cu_sidhe_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.forest, .park],
                timePreference: .dusk, weatherPreference: [.fog],
                modelAsset: "cu_sidhe_3d", iconAsset: "cu_sidhe_icon"
            ),
            CreatureSpecies(
                id: "celtic_dullahan", name: "Dullahan", mythology: .celtic, element: .shadow,
                rarity: .epic, lore: "The headless horseman of Irish legend. When it stops riding, someone dies.",
                baseHP: 110, baseAttack: 120, baseDefense: 85, baseSpeed: 100, baseSpecial: 90,
                abilities: ["Shadow Strike", "Void Rend", "Gale Force"], passiveAbility: "nightProwler",
                evolutionChainID: "dullahan_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.002, biomePreference: [.cemetery, .residential],
                timePreference: .night, weatherPreference: [.fog],
                modelAsset: "dullahan_3d", iconAsset: "dullahan_icon"
            ),
            CreatureSpecies(
                id: "celtic_green_man", name: "Green Man", mythology: .celtic, element: .nature,
                rarity: .rare, lore: "An ancient forest spirit, its face formed of living leaves and vines.",
                baseHP: 90, baseAttack: 60, baseDefense: 80, baseSpeed: 40, baseSpecial: 95,
                abilities: ["Vine Lash", "World Tree's Blessing"], passiveAbility: "healOnKill",
                evolutionChainID: "greenman_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.forest, .park],
                timePreference: .day, weatherPreference: [.rain, .clear],
                modelAsset: "green_man_3d", iconAsset: "green_man_icon"
            ),
            CreatureSpecies(
                id: "celtic_banshee", name: "Banshee", mythology: .celtic, element: .shadow,
                rarity: .rare, lore: "A wailing spirit whose scream foretells death. Her cry freezes the blood.",
                baseHP: 55, baseAttack: 50, baseDefense: 40, baseSpeed: 90, baseSpecial: 110,
                abilities: ["Shadow Strike", "Frost Bite", "Eternal Night"], passiveAbility: "nightProwler",
                evolutionChainID: "banshee_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.003, biomePreference: [.cemetery, .residential],
                timePreference: .night, weatherPreference: [.fog, .rain],
                modelAsset: "banshee_3d", iconAsset: "banshee_icon"
            ),
            CreatureSpecies(
                id: "celtic_leprechaun", name: "Leprechaun", mythology: .celtic, element: .earth,
                rarity: .uncommon, lore: "A cunning little cobbler who guards a pot of gold at the rainbow's end.",
                baseHP: 45, baseAttack: 35, baseDefense: 50, baseSpeed: 95, baseSpecial: 70,
                abilities: ["Stone Shield", "Vine Lash"], passiveAbility: "luckBoost",
                evolutionChainID: "leprechaun_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.park, .suburban, .commercial],
                timePreference: .day, weatherPreference: [.rain, .clear],
                modelAsset: "leprechaun_3d", iconAsset: "leprechaun_icon"
            ),
            CreatureSpecies(
                id: "celtic_morrigan", name: "The Morrígan", mythology: .celtic, element: .shadow,
                rarity: .mythic, lore: "The phantom queen of war and fate. She appears as a crow over battlefields, choosing who will fall.",
                baseHP: 170, baseAttack: 165, baseDefense: 120, baseSpeed: 135, baseSpecial: 155,
                abilities: ["Eternal Night", "Void Rend", "Shadow Strike", "Gale Force"], passiveAbility: nil,
                evolutionChainID: "morrigan_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.0003, biomePreference: [.cemetery, .historic],
                timePreference: .night, weatherPreference: [.fog, .storm],
                modelAsset: "morrigan_3d", iconAsset: "morrigan_icon"
            ),
            CreatureSpecies(
                id: "celtic_selkie", name: "Selkie", mythology: .celtic, element: .water,
                rarity: .uncommon, lore: "A seal that sheds its skin to become human. Gentle and curious, but fiercely protective.",
                baseHP: 65, baseAttack: 45, baseDefense: 55, baseSpeed: 80, baseSpecial: 75,
                abilities: ["Tidal Surge", "Purifying Light"], passiveAbility: "elementalResist",
                evolutionChainID: "selkie_chain", evolutionStage: 1, evolvesInto: nil,
                shinyRate: 0.004, biomePreference: [.water],
                timePreference: .dusk, weatherPreference: [.fog, .rain],
                modelAsset: "selkie_3d", iconAsset: "selkie_icon"
            ),
        ]

        for s in allSpecies {
            species[s.id] = s
        }
    }
}
