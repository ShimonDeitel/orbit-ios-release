import SwiftUI

/// Pro feature: full contact history, circle health rings, streak, and CSV export.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showExportSheet = false
    @State private var csvContent = ""

    private let circleTags = ["family", "work", "friends"]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Streak
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.weekStreak)", label: "week streak")
                            MetricTile(value: "\(appModel.touchEvents.count)", label: "total touches")
                            MetricTile(value: "\(appModel.people.count)", label: "in orbit")
                        }

                        // Circle health rings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Circle Health")
                                .font(.headline)

                            ForEach(circleTags, id: \.self) { tag in
                                let health = appModel.circleHealth(tag: tag)
                                let members = appModel.people.filter { $0.circleTag == tag }
                                if !members.isEmpty {
                                    CircleHealthRow(tag: tag, health: health, count: members.count)
                                }
                            }

                            let untagged = appModel.people.filter { $0.circleTag.isEmpty }
                            if !untagged.isEmpty {
                                CircleHealthRow(tag: "general", health: appModel.circleHealth(tag: ""), count: untagged.count)
                            }

                            if appModel.people.allSatisfy({ $0.circleTag.isEmpty }) || appModel.people.isEmpty {
                                Text("Add circle tags to people to see health rings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 8)
                            }
                        }

                        // Recent activity
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Activity")
                                .font(.headline)

                            if appModel.touchEvents.isEmpty {
                                Text("No touches logged yet. Tap the checkmark on any overdue contact to start.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(appModel.touchEvents.prefix(20))) { event in
                                    if let person = appModel.people.first(where: { $0.id == event.personID }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(person.name)
                                                    .font(.subheadline.weight(.medium))
                                                Text(event.channel.capitalized + (event.note.isEmpty ? "" : " · \(event.note)"))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(event.date, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .qmCard()
                                    }
                                }
                            }
                        }

                        // Export
                        VStack(spacing: 8) {
                            Button {
                                csvContent = appModel.exportCSV()
                                showExportSheet = true
                            } label: {
                                Label("Export Touch Log (CSV)", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .prominentButton()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(activityItems: [csvContent])
            }
        }
    }
}

// MARK: - Circle Health Row

struct CircleHealthRow: View {
    let tag: String
    let health: Double
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Color.qmHair, lineWidth: 2)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: health)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: health)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.capitalized)
                    .font(.subheadline.weight(.medium))
                Text("\(count) people · \(Int(health * 100))% in orbit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .qmCard()
    }

    private var healthColor: Color {
        if health >= 0.8 { return Color.qmCorrect }
        if health >= 0.5 { return Color(hex: "#FF9500") }
        return Color.qmWrong
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
