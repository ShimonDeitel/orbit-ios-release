import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    // Pro section
                    Section("Orbit Pro") {
                        if store.isPro {
                            HStack {
                                Text("Status")
                                Spacer()
                                Text("Active")
                                    .foregroundStyle(Color.qmCorrect)
                                    .fontWeight(.medium)
                            }
                            Link("Manage Subscription",
                                 destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        } else {
                            Button("Unlock Orbit Pro — \(store.displayPrice)/mo") {
                                showPaywall = true
                            }
                            .foregroundStyle(Color.qmAccent)

                            Button("Restore Purchase") {
                                Task { await store.restore() }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $themeRaw) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Notifications (Pro)
                    if store.isPro {
                        Section("Notifications") {
                            Button("Enable Daily Reminder") {
                                Task {
                                    let granted = await Reminders.requestAuthorization()
                                    if granted {
                                        Reminders.schedule(hour: 9, minute: 0)
                                    }
                                }
                            }
                            Button("Disable Reminder") {
                                Reminders.cancel()
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Legal
                    Section("Legal") {
                        Link("Privacy Policy",
                             destination: URL(string: "https://shimondeitel.github.io/orbit-site/privacy.html")!)
                        Link("Terms of Use",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }

                    // Data
                    Section("Data") {
                        Button("Delete All Data", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    appModel.deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all contacts and touch history. This cannot be undone.")
            }
        }
    }
}
