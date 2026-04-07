import Foundation
import HealthKit
import Combine

// MARK: - Fitness Service
// Feature #6: HealthKit integration for fitness-driven gameplay.
// Researched: Pokemon GO Adventure Sync uses CMPedometer + HealthKit background delivery.
// Key insight: Tying real physical activity to in-game rewards creates the strongest
// retention loop — players feel healthier AND progress in-game simultaneously.

final class FitnessService: ObservableObject {
    static let shared = FitnessService()

    // MARK: - Published State

    @Published var stepsToday: Int = 0
    @Published var distanceToday: Double = 0.0 // kilometers
    @Published var caloriesBurned: Double = 0.0
    @Published var currentHeartRate: Double = 0.0
    @Published var xpMultiplier: Double = 1.0
    @Published var isAuthorized: Bool = false
    @Published var isTracking: Bool = false

    // Egg hatching progress driven by steps
    @Published var stepsForCurrentEgg: Int = 5000
    @Published var eggStepsAccumulated: Int = 0

    var eggProgress: Double {
        guard stepsForCurrentEgg > 0 else { return 0.0 }
        return min(1.0, Double(eggStepsAccumulated) / Double(stepsForCurrentEgg))
    }

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Heart rate zones for XP multiplier
    private enum ActivityZone {
        case resting    // HR < 100
        case walking    // HR 100-120
        case jogging    // HR 120-150
        case running    // HR 150+

        var xpMultiplier: Double {
            switch self {
            case .resting: return 1.0
            case .walking: return 1.0
            case .jogging: return 2.0
            case .running: return 3.0
            }
        }
    }

    // UserDefaults keys for offline access
    private enum StorageKey {
        static let stepsToday = "fitness_stepsToday"
        static let distanceToday = "fitness_distanceToday"
        static let caloriesBurned = "fitness_caloriesBurned"
        static let eggStepsAccumulated = "fitness_eggSteps"
        static let lastRecordedDate = "fitness_lastDate"
    }

    private init() {
        loadCachedData()
        resetIfNewDay()
    }

    deinit {
        stopTracking()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.startTracking()
                }
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Tracking

    func startTracking() {
        guard HKHealthStore.isHealthDataAvailable(), !isTracking else { return }
        isTracking = true

        setupStepObserver()
        setupHeartRateObserver()
        fetchTodayStats()

        // Refresh every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchTodayStats()
            self?.calculateXPMultiplier()
        }
    }

    func stopTracking() {
        isTracking = false
        refreshTimer?.invalidate()
        refreshTimer = nil

        if let observerQuery = observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        if let heartRateQuery = heartRateQuery {
            healthStore.stop(heartRateQuery)
            self.heartRateQuery = nil
        }
    }

    // MARK: - Step Observer (Live Updates)

    private func setupStepObserver() {
        let stepType = HKQuantityType(.stepCount)

        let query = HKObserverQuery(sampleType: stepType, predicate: todayPredicate()) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Step observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            self?.fetchTodaySteps()
            completionHandler()
        }

        observerQuery = query
        healthStore.execute(query)

        // Enable background delivery for step counting
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Heart Rate Observer

    private func setupHeartRateObserver() {
        let heartRateType = HKQuantityType(.heartRate)
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: todayPredicate(),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            guard error == nil else { return }
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            guard error == nil else { return }
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latestSample = quantitySamples.last else { return }

        let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
            self.calculateXPMultiplier()
        }
    }

    // MARK: - Fetch Today's Stats

    func fetchTodayStats() {
        fetchTodaySteps()
        fetchTodayDistance()
        fetchTodayCalories()
    }

    private func fetchTodaySteps() {
        let stepType = HKQuantityType(.stepCount)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, error == nil,
                  let sum = result?.sumQuantity() else { return }

            let steps = Int(sum.doubleValue(for: .count()))

            DispatchQueue.main.async {
                let previousSteps = self.stepsToday
                self.stepsToday = steps

                // Accumulate egg hatching steps
                let delta = max(0, steps - previousSteps)
                if delta > 0 {
                    self.eggStepsAccumulated += delta
                }

                self.cacheData()
            }
        }
        healthStore.execute(query)
    }

    private func fetchTodayDistance() {
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { [weak self] _, result, error in
            guard error == nil,
                  let sum = result?.sumQuantity() else { return }

            let distanceKm = sum.doubleValue(for: .meterUnit(with: .kilo))

            DispatchQueue.main.async {
                self?.distanceToday = distanceKm
                self?.cacheData()
            }
        }
        healthStore.execute(query)
    }

    private func fetchTodayCalories() {
        let calorieType = HKQuantityType(.activeEnergyBurned)
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { [weak self] _, result, error in
            guard error == nil,
                  let sum = result?.sumQuantity() else { return }

            let calories = sum.doubleValue(for: .kilocalorie())

            DispatchQueue.main.async {
                self?.caloriesBurned = calories
                self?.cacheData()
            }
        }
        healthStore.execute(query)
    }

    // MARK: - XP Multiplier Calculation

    func calculateXPMultiplier() {
        let zone: ActivityZone
        let hr = currentHeartRate

        if hr >= 150 {
            zone = .running
        } else if hr >= 120 {
            zone = .jogging
        } else if hr >= 100 {
            zone = .walking
        } else {
            zone = .resting
        }

        DispatchQueue.main.async {
            self.xpMultiplier = zone.xpMultiplier
        }
    }

    // MARK: - Egg Hatching

    func resetEgg(requiredSteps: Int) {
        eggStepsAccumulated = 0
        stepsForCurrentEgg = requiredSteps
        cacheData()
    }

    func isEggHatched() -> Bool {
        return eggProgress >= 1.0
    }

    // MARK: - Persistence (UserDefaults for offline access)

    private func cacheData() {
        let defaults = UserDefaults.standard
        defaults.set(stepsToday, forKey: StorageKey.stepsToday)
        defaults.set(distanceToday, forKey: StorageKey.distanceToday)
        defaults.set(caloriesBurned, forKey: StorageKey.caloriesBurned)
        defaults.set(eggStepsAccumulated, forKey: StorageKey.eggStepsAccumulated)
        defaults.set(Date().timeIntervalSince1970, forKey: StorageKey.lastRecordedDate)
    }

    private func loadCachedData() {
        let defaults = UserDefaults.standard
        stepsToday = defaults.integer(forKey: StorageKey.stepsToday)
        distanceToday = defaults.double(forKey: StorageKey.distanceToday)
        caloriesBurned = defaults.double(forKey: StorageKey.caloriesBurned)
        eggStepsAccumulated = defaults.integer(forKey: StorageKey.eggStepsAccumulated)
    }

    private func resetIfNewDay() {
        let defaults = UserDefaults.standard
        let lastTimestamp = defaults.double(forKey: StorageKey.lastRecordedDate)
        guard lastTimestamp > 0 else { return }

        let lastDate = Date(timeIntervalSince1970: lastTimestamp)
        if !Calendar.current.isDateInToday(lastDate) {
            stepsToday = 0
            distanceToday = 0.0
            caloriesBurned = 0.0
            cacheData()
        }
    }

    // MARK: - Helpers

    private func todayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
    }
}
