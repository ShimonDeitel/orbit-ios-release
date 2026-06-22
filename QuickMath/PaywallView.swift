import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, text: String)] = [
        ("person.3.fill", "Unlimited people plus circle tags (family, work, friends) with per-circle health rings"),
        ("clock.arrow.circlepath", "Full contact-history timeline per person and streak of weeks with zero overdue contacts"),
        ("bell.badge", "Daily reminder notification and CSV export of your full touch log")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 0) {
                    // Icon + headline
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.qmAccent, lineWidth: 2)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(Color.qmAccent)
                                .frame(width: 12, height: 12)
                                .offset(x: 36, y: 0)
                        }
                        .padding(.top, 36)

                        Text("Orbit Pro")
                            .font(.title.weight(.bold))

                        Text("$0.99 / month. Auto-renews until you cancel.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Benefits
                    VStack(spacing: 12) {
                        ForEach(benefits, id: \.text) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.qmAccent)
                                    .frame(width: 24)
                                Text(benefit.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .qmCard()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    Spacer()

                    // CTA
                    VStack(spacing: 14) {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Group {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Unlock for \(store.displayPrice)/mo")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .prominentButton()
                        .disabled(store.purchaseInFlight)

                        Button {
                            Task { await store.restore() }
                        } label: {
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundStyle(Color.qmAccent)
                        }

                        // Auto-renew disclosure
                        Text("Orbit Pro is \(store.displayPrice)/month. Subscription auto-renews monthly until cancelled. Cancel any time in Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link("Privacy", destination: URL(string: "https://shimondeitel.github.io/orbit-site/privacy.html")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.qmAccent)

                        Button {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Manage Subscription")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}
