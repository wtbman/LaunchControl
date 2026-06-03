import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: LaunchAgentListViewModel
    @State private var logPaneFraction: CGFloat = 0.3
    @State private var dragStartLogPaneFraction: CGFloat?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .searchable(text: $viewModel.searchText, placement: .sidebar, prompt: "Search labels, files, paths")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload launch agents from disk")

                Menu {
                    Button("All Domains") {
                        viewModel.selectedDomain = nil
                    }
                    Divider()
                    ForEach(LaunchAgentDomain.allCases, id: \.self) { domain in
                        Button(domain.rawValue) {
                            viewModel.selectedDomain = domain
                        }
                    }
                } label: {
                    Label(viewModel.selectedDomain?.rawValue ?? "All Domains", systemImage: "line.3.horizontal.decrease.circle")
                }
                .help("Filter launch agents by domain")
            }
        }
        .overlay(alignment: .bottom) {
            statusBar
        }
        .overlay {
            if viewModel.isInitialLoad {
                loadingOverlay
            }
        }
        .task {
            viewModel.refresh()
        }
        .onChange(of: viewModel.selectedAgentID) { _ in
            DispatchQueue.main.async {
                viewModel.selectionDidChange()
            }
        }
        .alert("Launchctl Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedAgentID) {
            ForEach(viewModel.filteredAgents) { agent in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(agent.label)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text(agent.loadedState.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(agent.loadedState == .loaded ? .green : .secondary)
                    }
                    Text(agent.fileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(agent.domain.displayPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .tag(agent.id)
            }
        }
        .navigationTitle("LaunchControl")
        .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 520)
    }

    @ViewBuilder
    private var detail: some View {
        if let agent = viewModel.selectedAgent {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header(agent)
                            properties(agent)
                            plistViewer(agent)
                        }
                        .padding(24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    resizeHandle(totalHeight: geometry.size.height)

                    logViewer(agent)
                        .frame(height: logPaneHeight(totalHeight: geometry.size.height))
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "switch.2")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No Launch Agent Selected")
                    .font(.title3.weight(.semibold))
                Text("Pick a launch agent from the sidebar to inspect or control it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(_ agent: LaunchAgent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(agent.label)
                        .font(.largeTitle.weight(.semibold))
                    Text(agent.plistPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(agent.loadedState.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(agent.loadedState == .loaded ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.perform(.start)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }

                Button {
                    viewModel.perform(.stop)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }

                Button {
                    viewModel.perform(.restart)
                } label: {
                    Label("Restart", systemImage: "arrow.triangle.2.circlepath")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func properties(_ agent: LaunchAgent) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                keyValue("Domain", agent.domain.rawValue)
                keyValue("Run At Load", agent.runAtLoad ? "Yes" : "No")
            }
            GridRow {
                keyValue("Program", agent.program ?? "Not set")
                keyValue("Keep Alive", agent.keepAlive ? "Yes" : "No")
            }
            GridRow {
                keyValue("Watch Paths", agent.watchPaths.isEmpty ? "None" : agent.watchPaths.joined(separator: "\n"))
                keyValue("Plist File", agent.fileName)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func plistViewer(_ agent: LaunchAgent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plist")
                .font(.title3.weight(.semibold))
            TextEditor(text: .constant(agent.rawPlist))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func logViewer(_ agent: LaunchAgent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Logs")
                    .font(.title3.weight(.semibold))
                Text("Newest lines first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.orderedLogPaths.count > 1 {
                    Picker("Log File", selection: $viewModel.selectedLogPath) {
                        ForEach(viewModel.orderedLogPaths, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent).tag(Optional(path))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedLogPath) { _ in
                        viewModel.refreshLog()
                    }
                }
                Button {
                    viewModel.refreshLog()
                } label: {
                    Label("Refresh Log", systemImage: "arrow.clockwise")
                }
                .help("Reload the selected log file")
            }

            Text(viewModel.logStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))

                TextEditor(text: .constant(viewModel.logContent))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                if viewModel.isRefreshingLog {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading log...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private func logPaneHeight(totalHeight: CGFloat) -> CGFloat {
        max(220, min(totalHeight * 0.75, totalHeight * logPaneFraction))
    }

    private func resizeHandle(totalHeight: CGFloat) -> some View {
        ZStack {
            Divider()
            Capsule()
                .fill(.tertiary)
                .frame(width: 48, height: 6)
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStartLogPaneFraction == nil {
                        dragStartLogPaneFraction = logPaneFraction
                    }

                    let baseFraction = dragStartLogPaneFraction ?? logPaneFraction
                    let deltaFraction = -(value.translation.height / max(totalHeight, 1))
                    let proposedFraction = baseFraction + deltaFraction
                    logPaneFraction = min(max(proposedFraction, 0.2), 0.75)
                }
                .onEnded { _ in
                    dragStartLogPaneFraction = nil
                }
        )
    }

    private func keyValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.filteredAgents.count) shown")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var loadingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading launch agents...")
                    .font(.headline)
                Text("Scanning installed plists and checking loaded services.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
