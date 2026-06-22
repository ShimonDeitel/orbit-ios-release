import SwiftUI
import SwiftData

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var showInsights = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header metrics
                        HStack(spacing: 12) {
                            MetricTile(
                                value: "\(appModel.overduePeople.count)",
                                label: "overdue"
                            )
                            MetricTile(
                                value: "\(appModel.people.count)",
                                label: "in orbit"
                            )
                            MetricTile(
                                value: "\(appModel.weekStreak)w",
                                label: "streak"
                            )
                        }
                        .padding(.horizontal)

                        // Pro row
                        Button {
                            if store.isPro { showInsights = true } else { showPaywall = true }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.isPro ? "Orbit Pro" : "Upgrade to Pro")
                                        .font(.subheadline.weight(.semibold))
                                    Text(store.isPro ? "Insights, history & export" : "Unlimited people, circles & history")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: store.isPro ? "chart.line.uptrend.xyaxis" : "star.fill")
                                    .foregroundStyle(Color.qmAccent)
                            }
                            .qmCard()
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        // Overdue section
                        if !appModel.overduePeople.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reach out today")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(appModel.overduePeople) { person in
                                    OverdueRow(person: person)
                                        .padding(.horizontal)
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.qmCorrect)
                                Text("Everyone's in orbit")
                                    .font(.headline)
                                Text("No one is overdue right now.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }

                        // All people
                        if !appModel.people.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("All contacts")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(appModel.people) { person in
                                    NavigationLink(destination: PersonDetailView(person: person)) {
                                        PersonRow(person: person)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Add person
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
                        .padding(.vertical, 12)

                        if !store.isPro {
                            Text("\(appModel.people.count)/\(AppModel.freePeopleLimit) free contacts used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Orbit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(appModel)
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
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .environmentObject(appModel)
                    .environmentObject(store)
            }
            .onAppear {
                if let forced = forceScreen {
                    switch forced {
                    case "paywall": showPaywall = true
                    case "insights": showInsights = true
                    case "settings": showSettings = true
                    default: break
                    }
                }
            }
        }
    }
}

// MARK: - Overdue Row

struct OverdueRow: View {
    let person: OrbitPerson
    @EnvironmentObject var appModel: AppModel
    @State private var showLog = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(person.daysOverdue)d overdue · every \(person.cadenceDays)d")
                    .font(.caption)
                    .foregroundStyle(Color.qmWrong)
            }
            Spacer()
            Button {
                Haptics.success()
                appModel.logTouch(person: person)
            } label: {
                Label("Done", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
            }
            .softButton()
        }
        .qmCard()
    }
}

// MARK: - Person Row

struct PersonRow: View {
    let person: OrbitPerson

    var body: some View {
        HStack {
            Circle()
                .fill(circleColor(for: person.circleTag))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(person.isOverdue ? Color.qmWrong : .secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .qmCard()
    }

    private var statusText: String {
        if person.isOverdue {
            return "\(person.daysOverdue)d overdue"
        } else {
            let remaining = -person.daysOverdue
            return "next in \(remaining)d"
        }
    }

    private func circleColor(for tag: String) -> Color {
        switch tag {
        case "family": return Color.qmCorrect
        case "work": return Color.qmAccent
        case "friends": return Color(hex: "#FF9500")
        default: return Color.qmHair
        }
    }
}

// MARK: - Add Person View

struct AddPersonView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cadenceDays = 30
    @State private var circleTag = ""
    @State private var notes = ""

    private let cadenceOptions = [7, 14, 30, 60, 90]
    private let circleTags = ["", "family", "work", "friends"]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    Section("Name") {
                        TextField("Full name", text: $name)
                    }
                    Section("Cadence") {
                        Picker("Contact every", selection: $cadenceDays) {
                            ForEach(cadenceOptions, id: \.self) { days in
                                Text(cadenceLabel(days)).tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.isPro {
                        Section("Circle") {
                            Picker("Circle", selection: $circleTag) {
                                Text("None").tag("")
                                Text("Family").tag("family")
                                Text("Work").tag("work")
                                Text("Friends").tag("friends")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    Section("Notes") {
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Haptics.success()
                        appModel.addPerson(name: name.trimmingCharacters(in: .whitespaces),
                                           cadenceDays: cadenceDays,
                                           circleTag: store.isPro ? circleTag : "",
                                           notes: notes)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func cadenceLabel(_ days: Int) -> String {
        switch days {
        case 7: return "Weekly"
        case 14: return "2 wks"
        case 30: return "Monthly"
        case 60: return "2 mo"
        case 90: return "Quarterly"
        default: return "\(days)d"
        }
    }
}

// MARK: - Person Detail

struct PersonDetailView: View {
    let person: OrbitPerson
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showLogTouch = false
    @State private var showDelete = false

    var body: some View {
        ZStack {
            QMBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status card
                    HStack(spacing: 16) {
                        MetricTile(
                            value: person.isOverdue ? "+\(person.daysOverdue)d" : "-\(-person.daysOverdue)d",
                            label: person.isOverdue ? "overdue" : "until due"
                        )
                        MetricTile(
                            value: "\(person.cadenceDays)d",
                            label: "cadence"
                        )
                        MetricTile(
                            value: "\(appModel.touchEvents(for: person).count)",
                            label: "touches"
                        )
                    }

                    if !person.notes.isEmpty {
                        Text(person.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .qmCard()
                    }

                    // Log touch button
                    Button {
                        showLogTouch = true
                    } label: {
                        Label("Log a touch", systemImage: "hand.tap")
                            .frame(maxWidth: .infinity)
                    }
                    .prominentButton()

                    // Recent touches (Pro)
                    if store.isPro {
                        let events = appModel.touchEvents(for: person)
                        if !events.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("History")
                                    .font(.headline)
                                ForEach(Array(events.prefix(10))) { event in
                                    HStack {
                                        Image(systemName: channelIcon(event.channel))
                                            .foregroundStyle(Color.qmAccent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.channel.capitalized)
                                                .font(.subheadline.weight(.medium))
                                            if !event.note.isEmpty {
                                                Text(event.note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(event.date, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .qmCard()
                                }
                            }
                        }
                    }

                    // Delete
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Remove from Orbit", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditPersonView(person: person)
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .sheet(isPresented: $showLogTouch) {
            LogTouchView(person: person)
                .environmentObject(appModel)
        }
        .confirmationDialog("Remove \(person.name)?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                appModel.deletePerson(person)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func channelIcon(_ channel: String) -> String {
        switch channel {
        case "call": return "phone"
        case "text": return "message"
        case "email": return "envelope"
        case "in-person": return "person.2"
        default: return "hand.wave"
        }
    }
}

// MARK: - Edit Person View

struct EditPersonView: View {
    let person: OrbitPerson
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var cadenceDays: Int
    @State private var circleTag: String
    @State private var notes: String

    private let cadenceOptions = [7, 14, 30, 60, 90]

    init(person: OrbitPerson) {
        self.person = person
        _name = State(initialValue: person.name)
        _cadenceDays = State(initialValue: person.cadenceDays)
        _circleTag = State(initialValue: person.circleTag)
        _notes = State(initialValue: person.notes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    Section("Name") {
                        TextField("Full name", text: $name)
                    }
                    Section("Cadence") {
                        Picker("Contact every", selection: $cadenceDays) {
                            ForEach(cadenceOptions, id: \.self) { days in
                                Text(cadenceLabel(days)).tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.isPro {
                        Section("Circle") {
                            Picker("Circle", selection: $circleTag) {
                                Text("None").tag("")
                                Text("Family").tag("family")
                                Text("Work").tag("work")
                                Text("Friends").tag("friends")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    Section("Notes") {
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appModel.updatePerson(person,
                                              name: name.trimmingCharacters(in: .whitespaces),
                                              cadenceDays: cadenceDays,
                                              circleTag: circleTag,
                                              notes: notes)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func cadenceLabel(_ days: Int) -> String {
        switch days {
        case 7: return "Weekly"
        case 14: return "2 wks"
        case 30: return "Monthly"
        case 60: return "2 mo"
        case 90: return "Quarterly"
        default: return "\(days)d"
        }
    }
}

// MARK: - Log Touch View

struct LogTouchView: View {
    let person: OrbitPerson
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var channel = "other"
    @State private var note = ""

    private let channels = ["call", "text", "email", "in-person", "other"]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    Section("How did you connect?") {
                        Picker("Channel", selection: $channel) {
                            ForEach(channels, id: \.self) { ch in
                                Text(ch.capitalized).tag(ch)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Note (optional)") {
                        TextField("What did you talk about?", text: $note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle("Log Touch — \(person.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        appModel.logTouch(person: person, channel: channel, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}
