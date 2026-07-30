import Foundation
import StoreKit

/// Aurora Pro: StoreKit 2 subscriptions + lifetime unlock, and the free-tier
/// trip allowance (3 tracked trips per week).
@MainActor
final class Store: ObservableObject {
    static let monthlyID = "aurora.pro.monthly"
    static let yearlyID = "aurora.pro.yearly"
    static let lifetimeID = "aurora.pro.lifetime"
    static let allIDs = [monthlyID, yearlyID, lifetimeID]

    @Published var products: [Product] = []
    @Published var isPro = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if let tx = try? update.payloadValue {
                    await tx.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.allIDs)) ?? []
        products.sort { $0.price < $1.price }
    }

    func refreshEntitlements() async {
        var pro = false
        for await entitlement in Transaction.currentEntitlements {
            if let tx = try? entitlement.payloadValue, Self.allIDs.contains(tx.productID) {
                pro = true
            }
        }
        isPro = pro
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result, let tx = try? verification.payloadValue {
            await tx.finish()
            await refreshEntitlements()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Free-tier trip allowance

    private static let countKey = "aurora.trips.count"
    private static let weekKey = "aurora.trips.weekStart"
    static let freeTripsPerWeek = 3

    var tripsLeftThisWeek: Int {
        rolloverIfNeeded()
        return max(0, Self.freeTripsPerWeek - UserDefaults.standard.integer(forKey: Self.countKey))
    }

    /// Demo rides are always free; real tracked trips burn the allowance.
    func canStartTrip() -> Bool {
        isPro || tripsLeftThisWeek > 0
    }

    func consumeTrip() {
        guard !isPro else { return }
        rolloverIfNeeded()
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Self.countKey) + 1, forKey: Self.countKey)
    }

    private func rolloverIfNeeded() {
        let d = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let weekStart = d.double(forKey: Self.weekKey)
        if now - weekStart > 7 * 86400 {
            d.set(now, forKey: Self.weekKey)
            d.set(0, forKey: Self.countKey)
        }
    }
}
