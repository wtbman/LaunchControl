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
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Refresh Launch Agents") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Refresh Current Log") {
                    viewModel.refreshLog()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(viewModel.selectedAgent == nil)
            }

            CommandMenu("LaunchControl") {
                Button("Start Agent") {
                    viewModel.perform(.start)
                }
                .disabled(viewModel.selectedAgent == nil)

                Button("Stop Agent") {
                    viewModel.perform(.stop)
                }
                .disabled(viewModel.selectedAgent == nil)

                Button("Restart Agent") {
                    viewModel.perform(.restart)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(viewModel.selectedAgent == nil)
            }
        }
    }
}
