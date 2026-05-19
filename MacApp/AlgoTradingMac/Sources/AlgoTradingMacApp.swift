import AppKit
import SwiftUI

@main
struct AlgoTradingMacApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    appModel.startIfNeeded()
                }
                .onChange(of: scenePhase) { phase in
                    appModel.handleScenePhase(phase)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWorkspace.willSleepNotification
                    )
                ) { _ in
                    appModel.handleHostWillSleep()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWorkspace.didWakeNotification
                    )
                ) { _ in
                    appModel.handleHostDidWake()
                }
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}
