import Foundation

@MainActor
final class LaunchAgentListViewModel: ObservableObject {
    @Published private(set) var agents: [LaunchAgent] = []
    @Published var selectedAgentID: LaunchAgent.ID?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage = "Ready"
    @Published var searchText = ""
    @Published var selectedDomain: LaunchAgentDomain?

    private let service = LaunchAgentService()

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
        isLoading = true
        errorMessage = nil
        statusMessage = "Refreshing launch agents..."

        Task {
            do {
                let loadedAgents = try service.loadAgents()
                agents = loadedAgents
                if selectedAgent == nil {
                    selectedAgentID = loadedAgents.first?.id
                }
                statusMessage = "Loaded \(loadedAgents.count) launch agents"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Refresh failed"
            }
            isLoading = false
        }
    }

    func perform(_ action: LaunchAgentAction) {
        guard let agent = selectedAgent else {
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = "\(action.rawValue) \(agent.label)..."

        Task {
            do {
                try service.perform(action, agent: agent)
                statusMessage = "\(action.rawValue) finished for \(agent.label)"
                let loadedAgents = try service.loadAgents()
                agents = loadedAgents
                selectedAgentID = agent.id
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "\(action.rawValue) failed"
            }
            isLoading = false
        }
    }
}
