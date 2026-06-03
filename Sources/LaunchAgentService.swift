import Foundation

struct LaunchAgentService {
    private let fileManager = FileManager.default
    private let maxLogBytes = 131_072

    func loadAgents() throws -> [LaunchAgent] {
        let paths = LaunchAgentDomain.allCases
        var agents: [LaunchAgent] = []

        for domain in paths {
            let directory = domain.searchPath
            guard fileManager.fileExists(atPath: directory) else {
                continue
            }

            let files = try fileManager.contentsOfDirectory(atPath: directory)
                .filter { $0.hasSuffix(".plist") }
                .sorted()

            for file in files {
                let fullPath = (directory as NSString).appendingPathComponent(file)
                if let agent = try loadAgent(at: fullPath, domain: domain) {
                    agents.append(agent)
                }
            }
        }

        return agents.sorted {
            if $0.loadedState != $1.loadedState {
                return $0.loadedState.rawValue < $1.loadedState.rawValue
            }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    func perform(_ action: LaunchAgentAction, agent: LaunchAgent) throws {
        switch action {
        case .start:
            _ = try runLaunchctl([
                "bootstrap",
                agent.domain.launchctlDomain,
                agent.plistPath
            ])
        case .stop:
            _ = try runLaunchctl([
                "bootout",
                "\(agent.domain.launchctlDomain)/\(agent.label)"
            ])
        case .restart:
            _ = try runLaunchctl([
                "kickstart",
                "-k",
                "\(agent.domain.launchctlDomain)/\(agent.label)"
            ])
        }
    }

    private func loadAgent(at path: String, domain: LaunchAgentDomain) throws -> LaunchAgent? {
        guard let data = fileManager.contents(atPath: path) else {
            throw LaunchAgentError.invalidPlist(path)
        }

        let rawPlist = try prettyPrintedPlist(from: data)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let dictionary = plist as? [String: Any],
              let label = dictionary["Label"] as? String else {
            return nil
        }

        let program = dictionary["Program"] as? String
            ?? (dictionary["ProgramArguments"] as? [String])?.first
        let watchPaths = dictionary["WatchPaths"] as? [String] ?? []
        let standardOutPath = dictionary["StandardOutPath"] as? String
        let standardErrorPath = dictionary["StandardErrorPath"] as? String
        let runAtLoad = dictionary["RunAtLoad"] as? Bool ?? false
        let keepAlive = decodeKeepAlive(dictionary["KeepAlive"])
        let loadedState: LaunchAgentLoadedState = isLoaded(label: label, domain: domain) ? .loaded : .unloaded

        return LaunchAgent(
            id: "\(domain.rawValue):\(label)",
            label: label,
            plistPath: path,
            domain: domain,
            program: program,
            watchPaths: watchPaths,
            standardOutPath: standardOutPath,
            standardErrorPath: standardErrorPath,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            loadedState: loadedState,
            rawPlist: rawPlist
        )
    }

    func loadLog(at path: String) throws -> String {
        guard fileManager.fileExists(atPath: path) else {
            throw LaunchAgentError.missingLogFile(path)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let trimmedData = data.count > maxLogBytes ? data.suffix(maxLogBytes) : data[...]
        let content = String(decoding: Data(trimmedData), as: UTF8.self)
        let reversedContent = reverseLogLines(content)

        if data.count > maxLogBytes {
            return "[Showing newest lines from last \(maxLogBytes / 1024) KB of log]\n\n\(reversedContent)"
        }

        return reversedContent
    }

    func sortedLogPaths(_ paths: [String]) -> [String] {
        paths.sorted { lhs, rhs in
            let lhsDate = modificationDate(for: lhs)
            let rhsDate = modificationDate(for: rhs)

            switch (lhsDate, rhsDate) {
            case let (left?, right?):
                if left != right {
                    return left > right
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private func decodeKeepAlive(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let dictionary = value as? [String: Any] {
            return !dictionary.isEmpty
        }
        return false
    }

    private func isLoaded(label: String, domain: LaunchAgentDomain) -> Bool {
        do {
            _ = try runLaunchctl([
                "print",
                "\(domain.launchctlDomain)/\(label)"
            ])
            return true
        } catch {
            return false
        }
    }

    private func prettyPrintedPlist(from data: Data) throws -> String {
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let xmlData = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        return String(decoding: xmlData, as: UTF8.self)
    }

    private func reverseLogLines(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.reversed().joined(separator: "\n")
    }

    private func modificationDate(for path: String) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        if process.terminationStatus == 0 {
            return output
        }

        let message = error.isEmpty ? output : error
        throw LaunchAgentError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
