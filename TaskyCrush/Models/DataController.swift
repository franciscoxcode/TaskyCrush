import Foundation
import SwiftData

@MainActor
final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    private init() {
        let configuration = ModelConfiguration(
            "TaskyCrush",
            cloudKitDatabase: .automatic
        )

        do {
            container = try ModelContainer(
                for: ProjectRecord.self,
                TaskRecord.self,
                configurations: configuration
            )
        } catch {
            assertionFailure("Cloud-backed container failed: \(error.localizedDescription). Falling back to local store.")
            do {
                container = try ModelContainer(
                    for: ProjectRecord.self,
                    TaskRecord.self
                )
            } catch {
                fatalError("Failed to create SwiftData container even for local store: \(error.localizedDescription)")
            }
        }
    }
}
