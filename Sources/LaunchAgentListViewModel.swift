import Foundation

@MainActor
final class LaunchAgentListViewModel: ObservableObject {
    @Published private(set) var agents: [LaunchAgent] = []
    @Published var selectedAgentID: LaunchAgent.ID?
    @Published private(set) var isRefreshingAgents = false
    @Published private(set) var isPerformingAction = false
    @Published private(set) var isRefreshingLog = false
    @Published var errorMessage: String?
    @Published var statusMessage = "Ready"
    @Published var searchText = ""
    @Published var selectedDomain: LaunchAgentDomain?
    @Published var selectedLogPath: String?
    @Published private(set) var logContent = ""
    @Published private(set) var logStatusMessage = "Select an agent to inspect logs."

    private let service = LaunchAgentService()

    var isLoading: Bool {
        isRefreshingAgents || isPerformingAction
    }

    var isInitialLoad: Bool {
        isRefreshingAgents && agents.isEmpty
    }

    var filteredAgents: [LaunchAgent] {
        agents.filter { agent in
            let matchesSearch = searchText.isEmpty
                || agent.label.localizedCaseInsensitiveContains(searchText)
                || agent.fileName.localizedCaseInsensitiveContains(searchText)
                || agent.plistPath.localizedCaseInsensitiveContains(searchText)
            let matchesDomain = selectedDomain == nil || agent.domain == selectedDomain
            return matchesSearch && matchesDomain
        }
    }

    var selectedAgent: LaunchAgent? {
        filteredAgents.first { $0.id == selectedAgentID } ?? agents.first { $0.id == selectedAgentID }
    }

    func refresh() {
        isRefreshingAgents = true
        errorMessage = nil
        statusMessage = "Refreshing launch agents..."

        Task.detached(priority: .userInitiated) {
            do {
                let loadedAgents = try LaunchAgentService().loadAgents()
                await MainActor.run {
                    self.agents = loadedAgents
                    self.statusMessage = "Loaded \(loadedAgents.count) launch agents"
                    self.isRefreshingAgents = false
                    let selectedID = self.selectedAgentID
                    DispatchQueue.main.async {
                        if self.agents.contains(where: { $0.id == selectedID }) {
                            self.selectedAgentID = selectedID
                        } else {
                            self.selectedAgentID = nil
                        }
                        self.syncSelectedLogPath()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "Refresh failed"
                    self.isRefreshingAgents = false
                }
            }
        }
    }

    func perform(_ action: LaunchAgentAction) {
        guard let agent = selectedAgent else {
            return
        }

        isPerformingAction = true
        errorMessage = nil
        statusMessage = "\(action.rawValue) \(agent.label)..."

        Task.detached(priority: .userInitiated) {
            do {
                let service = LaunchAgentService()
                try service.perform(action, agent: agent)
                let loadedAgents = try service.loadAgents()
                await MainActor.run {
                    self.statusMessage = "\(action.rawValue) finished for \(agent.label)"
                    self.agents = loadedAgents
                    self.isPerformingAction = false
                    DispatchQueue.main.async {
                        if self.agents.contains(where: { $0.id == agent.id }) {
                            self.selectedAgentID = agent.id
                        } else {
                            self.selectedAgentID = nil
                        }
                        self.syncSelectedLogPath()
                    }
                }
                await self.refreshLogsAfterAction()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "\(action.rawValue) failed"
                    self.isPerformingAction = false
                }
            }
        }
    }

    func refreshLog() {
        guard let agent = selectedAgent else {
            logContent = ""
            logStatusMessage = "Select an agent to inspect logs."
            return
        }

        guard let path = selectedLogPath ?? agent.availableLogPaths.first else {
            selectedLogPath = nil
            logContent = ""
            logStatusMessage = "No log files declared in this plist."
            return
        }

        selectedLogPath = path
        isRefreshingLog = true
        logStatusMessage = "Refreshing log..."

        Task.detached(priority: .utility) {
            do {
                let logContent = try LaunchAgentService().loadLog(at: path)
                await MainActor.run {
                    self.logContent = logContent.isEmpty ? "[Log file is empty]" : logContent
                    self.logStatusMessage = URL(fileURLWithPath: path).lastPathComponent
                    self.isRefreshingLog = false
                }
            } catch {
                await MainActor.run {
                    self.logContent = ""
                    self.logStatusMessage = error.localizedDescription
                    self.isRefreshingLog = false
                }
            }
        }
    }

    func selectionDidChange() {
        syncSelectedLogPath()
        refreshLog()
    }

    private func syncSelectedLogPath() {
        guard let agent = selectedAgent else {
            selectedLogPath = nil
            return
        }

        if let currentPath = selectedLogPath, agent.availableLogPaths.contains(currentPath) {
            return
        }

        selectedLogPath = agent.availableLogPaths.first
    }

    private func refreshLogsAfterAction() async {
        await MainActor.run {
            self.refreshLog()
        }
    }
}
