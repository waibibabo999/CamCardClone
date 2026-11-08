#if DEBUG
import Foundation

@MainActor
enum UITestSupport {
    static func seedIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-seed"),
              let json = ProcessInfo.processInfo.environment["UITEST_SEED_JSON"],
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SeedPayload.self, from: data)
        else {
            return
        }

        let store = BusinessCardStore()
        do {
            for tag in payload.tags {
                try store.addTag(tag)
            }
            for seed in payload.cards {
                try store.add(BusinessCard(
                    name: seed.name,
                    company: seed.company,
                    jobTitle: seed.jobTitle,
                    mobile: seed.mobile,
                    email: seed.email,
                    address: seed.address,
                    notes: seed.notes,
                    tags: seed.tags
                ))
            }
        } catch {
            print("UI test seed failed: \(error)")
        }
    }

    private struct SeedPayload: Decodable {
        var tags: [String]
        var cards: [SeedCard]
    }

    private struct SeedCard: Decodable {
        var name: String?
        var company: String?
        var jobTitle: String?
        var mobile: String?
        var email: String?
        var address: String?
        var notes: String?
        var tags: [String]
    }
}
#endif
