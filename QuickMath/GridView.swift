import SwiftUI

/// Primary entry screen — the daily "who's overdue" orbit ring dashboard.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var selectedPerson: OrbitPerson? = nil

    var body: some View {
        ZStack {
            QMBackground()
            if appModel.people.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        orbitRingSection
                        overdueSummary
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPersonView()
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .sheet(item: $selectedPerson) { person in
            PersonDetailView(person: person)
                .environmentObject(appModel)
                .environmentObject(store)
        }
    }

    // MARK: - Orbit Ring

    private var orbitRingSection: some View {
        ZStack {
            // Orbit ring background
            Circle()
                .strokeBorder(Color.qmHair, lineWidth: 1.5)
                .frame(width: 260, height: 260)

            // Overdue arc
            let total = max(appModel.people.count, 1)
            let overdue = appModel.overduePeople.count
            let fraction = Double(overdue) / Double(total)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.qmWrong, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: fraction)

            // Center info
            VStack(spacing: 4) {
                Text("\(overdue)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(overdue > 0 ? Color.qmWrong : Color.qmCorrect)
                Text(overdue == 1 ? "overdue" : overdue == 0 ? "all good" : "overdue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Dots for each person on the ring
            ForEach(Array(appModel.people.enumerated()), id: \.element.id) { idx, person in
                let angle = Double(idx) / Double(total) * 360 - 90
                let radius: Double = 130
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius

                Button {
                    selectedPerson = person
                } label: {
                    Circle()
                        .fill(person.isOverdue ? Color.qmWrong : Color.qmAccent)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2)
                        )
                }
                .offset(x: x, y: y)
            }
        }
        .frame(width: 300, height: 300)
    }

    // MARK: - Overdue summary

    private var overdueSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appModel.overduePeople.isEmpty {
                Text("Everyone is in orbit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                Text("Reach out today")
                    .font(.headline)

                ForEach(Array(appModel.overduePeople.prefix(5))) { person in
                    Button {
                        selectedPerson = person
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(person.daysOverdue)d overdue")
                                    .font(.caption)
                                    .foregroundStyle(Color.qmWrong)
                            }
                            Spacer()
                            Button {
                                Haptics.success()
                                appModel.logTouch(person: person)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.qmAccent)
                            }
                        }
                        .qmCard()
                    }
                    .buttonStyle(.plain)
                }

                if appModel.overduePeople.count > 5 {
                    Text("+ \(appModel.overduePeople.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                Spacer()
                Button {
                    if appModel.atLimitFree { showPaywall = true } else { showAdd = true }
                } label: {
                    Label("Add Person", systemImage: "plus")
                }
                .prominentButton()
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(Color.qmHair, lineWidth: 1.5)
                    .frame(width: 200, height: 200)
                Circle()
                    .fill(Color.qmAccent)
                    .frame(width: 14, height: 14)
                    .offset(x: 100, y: 0)
                Text("Your orbit\nis empty")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Button {
                showAdd = true
            } label: {
                Label("Add your first contact", systemImage: "plus")
            }
            .prominentButton()

            Text("Add up to \(AppModel.freePeopleLimit) people free.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
