import SwiftUI
import SwiftData

@main
struct TaskyCrushMacApp: App {
    private let dataController = DataController.shared

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            MacHomeView()
        }
        .modelContainer(dataController.container)
    }
}
