import SwiftUI

private enum JungleWindowID {
    static let render = "render-window"
    static let overview = "overview-panel"
    static let camera = "camera-panel"
    static let projection = "projection-panel"
    static let engine = "engine-panel"
}

@main
struct JungleApp: App {
    @StateObject private var coordinator = JungleEngineCoordinator()

    var body: some Scene {
        Window("jungle", id: JungleWindowID.render) {
            JungleRootView(coordinator: coordinator)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            JunglePanelCommands()
        }

        Window("Overview", id: JungleWindowID.overview) {
            JungleOverviewPanelView(coordinator: coordinator)
        }
        .defaultSize(width: 420, height: 280)
        .windowResizability(.contentSize)

        Window("Camera", id: JungleWindowID.camera) {
            JungleCameraPanelView(coordinator: coordinator)
        }
        .defaultSize(width: 360, height: 300)
        .windowResizability(.contentSize)

        Window("Projection", id: JungleWindowID.projection) {
            JungleProjectionPanelView(coordinator: coordinator)
        }
        .defaultSize(width: 360, height: 280)
        .windowResizability(.contentSize)

        Window("Engine", id: JungleWindowID.engine) {
            JungleEnginePanelView(coordinator: coordinator)
        }
        .defaultSize(width: 360, height: 340)
        .windowResizability(.contentSize)
    }
}

private struct JunglePanelCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Panels") {
            Button("Show Render Window") {
                openWindow(id: JungleWindowID.render)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Divider()

            Button("Show Overview Panel") {
                openWindow(id: JungleWindowID.overview)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Show Camera Panel") {
                openWindow(id: JungleWindowID.camera)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Show Projection Panel") {
                openWindow(id: JungleWindowID.projection)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Show Engine Panel") {
                openWindow(id: JungleWindowID.engine)
            }
            .keyboardShortcut("4", modifiers: [.command, .option])

            Divider()

            Button("Show All Panels") {
                openWindow(id: JungleWindowID.overview)
                openWindow(id: JungleWindowID.camera)
                openWindow(id: JungleWindowID.projection)
                openWindow(id: JungleWindowID.engine)
            }
            .keyboardShortcut("9", modifiers: [.command, .option])
        }
    }
}
