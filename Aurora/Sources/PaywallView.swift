import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false
    @State private var errorMessage: String?

    private let auroraGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.45, blue: 0.95),
                 Color(red: 0.90, green: 0.35, blue: 0.45),
                 Color(red: 0.25, green: 0.80, blue: 0.60)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: 20) {
            Text("Aurora Pro")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(auroraGradient)
                .padding(.top, 28)

            VStack(alignment: .leading, spacing: 10) {
                benefit("infinity", "Unlimited tracked trips")
                benefit("applewatch.radiowaves.left.and.right", "Watch wake-up at your stop")
                benefit("bolt.badge.clock", "Live Activity in the Dynamic Island")
                benefit("tram.fill", "NYC Subway + NJ PATH, live arrivals")
                benefit("bell.badge.fill", "Underground tracking & alerts")
            }
            .padding(.horizontal, 32)

            if store.products.isEmpty {
                ProgressView("Loading plans…")
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            buy(product)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(planName(product))
                                        .font(.headline)
                                    if product.id == Store.yearlyID {
                                        Text("Best value").font(.caption2).foregroundStyle(.green)
                                    }
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.headline.monospacedDigit())
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                        .disabled(purchasing)
                    }
                }
                .padding(.horizontal, 24)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Text("Free plan: \(Store.freeTripsPerWeek) tracked trips a week. Demo mode is always free.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Button("Restore Purchases") {
                    Task { await store.restore(); if store.isPro { dismiss() } }
                }
                Link("Privacy", destination: URL(string: "https://assiamahs.github.io/aurora-privacy.html")!)
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption)
            .padding(.bottom, 16)

            Button("Not now") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 26)
                .foregroundStyle(auroraGradient)
            Text(text).font(.subheadline)
        }
    }

    private func planName(_ product: Product) -> String {
        switch product.id {
        case Store.monthlyID: return "Monthly"
        case Store.yearlyID: return "Yearly"
        case Store.lifetimeID: return "Lifetime"
        default: return product.displayName
        }
    }

    private func buy(_ product: Product) {
        purchasing = true
        errorMessage = nil
        Task {
            do {
                try await store.purchase(product)
                if store.isPro { dismiss() }
            } catch {
                errorMessage = "Purchase didn't go through. Try again."
            }
            purchasing = false
        }
    }
}
