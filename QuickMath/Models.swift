import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class OrbitPerson {
    var id: UUID
    var name: String
    var cadenceDays: Int
    var lastContacted: Date
    var notes: String
    var circleTag: String   // "family", "work", "friends", ""
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        cadenceDays: Int = 30,
        lastContacted: Date = Date(),
        notes: String = "",
        circleTag: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cadenceDays = cadenceDays
        self.lastContacted = lastContacted
        self.notes = notes
        self.circleTag = circleTag
        self.createdAt = createdAt
    }

    /// How many days since we last contacted this person.
    var daysSinceContact: Int {
        Calendar.current.dateComponents([.day], from: lastContacted, to: Date()).day ?? 0
    }

    /// How many days overdue (positive = overdue, negative = still in orbit).
    var daysOverdue: Int {
        daysSinceContact - cadenceDays
    }

    var isOverdue: Bool { daysOverdue > 0 }

    var nextContactDate: Date {
        Calendar.current.date(byAdding: .day, value: cadenceDays, to: lastContacted) ?? Date()
    }
}

@Model
final class TouchEvent {
    var id: UUID
    var personID: UUID
    var date: Date
    var channel: String   // "call", "text", "email", "in-person", "other"
    var note: String

    init(
        id: UUID = UUID(),
        personID: UUID,
        date: Date = Date(),
        channel: String = "other",
        note: String = ""
    ) {
        self.id = id
        self.personID = personID
        self.date = date
        self.channel = channel
        self.note = note
    }
}

// MARK: - App Model

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var people: [OrbitPerson] = []
    @Published private(set) var touchEvents: [TouchEvent] = []

    static let freePeopleLimit = 15

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([OrbitPerson.self, TouchEvent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let mc = try? ModelContainer(for: schema, configurations: [fallback]) {
                return mc
            }
            // Last resort — should never reach here in production
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    func reload() {
        let ctx = container.mainContext
        let peopleFetch = FetchDescriptor<OrbitPerson>(sortBy: [SortDescriptor(\.name)])
        let eventFetch = FetchDescriptor<TouchEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        people = (try? ctx.fetch(peopleFetch)) ?? []
        touchEvents = (try? ctx.fetch(eventFetch)) ?? []
    }

    func refresh() { reload() }

    // MARK: Computed

    var overduePeople: [OrbitPerson] {
        people.filter(\.isOverdue).sorted { $0.daysOverdue > $1.daysOverdue }
    }

    var atLimitFree: Bool {
        guard store?.isPro != true else { return false }
        return people.count >= AppModel.freePeopleLimit
    }

    // MARK: Mutations

    func addPerson(name: String, cadenceDays: Int, circleTag: String, notes: String) {
        let ctx = container.mainContext
        let person = OrbitPerson(
            name: name,
            cadenceDays: cadenceDays,
            lastContacted: Calendar.current.date(byAdding: .day, value: -cadenceDays - 1, to: Date()) ?? Date(),
            notes: notes,
            circleTag: circleTag
        )
        ctx.insert(person)
        try? ctx.save()
        reload()
    }

    func logTouch(person: OrbitPerson, channel: String = "other", note: String = "") {
        let ctx = container.mainContext
        person.lastContacted = Date()
        let event = TouchEvent(personID: person.id, channel: channel, note: note)
        ctx.insert(event)
        try? ctx.save()
        reload()
    }

    func updatePerson(_ person: OrbitPerson, name: String, cadenceDays: Int, circleTag: String, notes: String) {
        person.name = name
        person.cadenceDays = cadenceDays
        person.circleTag = circleTag
        person.notes = notes
        try? container.mainContext.save()
        reload()
    }

    func deletePerson(_ person: OrbitPerson) {
        let ctx = container.mainContext
        // Remove associated touch events
        let pid = person.id
        let events = touchEvents.filter { $0.personID == pid }
        for e in events { ctx.delete(e) }
        ctx.delete(person)
        try? ctx.save()
        reload()
    }

    func touchEvents(for person: OrbitPerson) -> [TouchEvent] {
        touchEvents.filter { $0.personID == person.id }
    }

    /// Circle health: fraction of people NOT overdue in a given circle.
    func circleHealth(tag: String) -> Double {
        let members = people.filter { $0.circleTag == tag }
        guard !members.isEmpty else { return 1.0 }
        let ok = members.filter { !$0.isOverdue }.count
        return Double(ok) / Double(members.count)
    }

    /// Streak: consecutive complete weeks (Mon–Sun) where zero contacts were overdue at week-end.
    /// Simplified: count consecutive 7-day windows back from today with ≥1 touch logged.
    var weekStreak: Int {
        var streak = 0
        var weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for _ in 0..<52 {
            let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
            let hasTouch = touchEvents.contains { $0.date >= weekStart && $0.date < weekEnd }
            if hasTouch { streak += 1 } else { break }
            weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        }
        return streak
    }

    // MARK: CSV Export

    func exportCSV() -> String {
        var lines = ["Name,Circle,Channel,Date,Note"]
        for event in touchEvents {
            if let person = people.first(where: { $0.id == event.personID }) {
                let dateStr = ISO8601DateFormatter().string(from: event.date)
                let note = event.note.replacingOccurrences(of: ",", with: ";")
                lines.append("\(person.name),\(person.circleTag),\(event.channel),\(dateStr),\(note)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func deleteAllData() {
        let ctx = container.mainContext
        for e in touchEvents { ctx.delete(e) }
        for p in people { ctx.delete(p) }
        try? ctx.save()
        reload()
    }
}
