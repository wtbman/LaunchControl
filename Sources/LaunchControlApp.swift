import SwiftUI

@main
struct LaunchControlApp: App {
    @StateObject private var viewModel = LaunchAgentListViewModel()

    var body: some Scene {
        WindowGroup("LaunchControl") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1375, minHeight: 875)
        }
        .windowResizability(.contentSize)
    }
}
