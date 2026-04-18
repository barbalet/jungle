import SwiftUI

@main
struct JungleApp: App {
    @StateObject private var coordinator = JungleEngineCoordinator()

    var body: some Scene {
        WindowGroup("jungle") {
            JungleRootView(coordinator: coordinator)
        }
    }
}
