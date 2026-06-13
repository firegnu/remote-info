import Foundation

public protocol HostConfigLoading {
    func loadDefault() throws -> [HostConfig]
}

public struct HostConfigLoader: HostConfigLoading, Sendable {
    public init() {}

    public func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("remote-info")
            .appendingPathComponent("hosts.json")
    }

    public func loadDefault() throws -> [HostConfig] {
        try load(from: defaultConfigURL())
    }

    public func load(from url: URL) throws -> [HostConfig] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HostConfigError.fileMissing(url)
        }

        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(HostConfigFile.self, from: data)
        try validate(config.hosts)
        return config.hosts
    }

    private func validate(_ hosts: [HostConfig]) throws {
        guard !hosts.isEmpty else {
            throw HostConfigError.expectedAtLeastOneHost
        }

        var seenIDs: Set<String> = []
        for host in hosts {
            try validateNonEmpty(host.id, field: "id")
            try validateNonEmpty(host.name, field: "name")
            try validateNonEmpty(host.sshTarget, field: "sshTarget")

            let id = host.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard seenIDs.insert(id).inserted else {
                throw HostConfigError.duplicateHostID(id)
            }
            try validateNotPlaceholder(host.sshTarget, field: "sshTarget")
        }
    }

    private func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw HostConfigError.emptyField(field)
        }
    }

    private func validateNotPlaceholder(_ value: String, field: String) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.hasPrefix("CHANGE_ME") || trimmedValue.hasPrefix("remote-info-host-") {
            throw HostConfigError.placeholderField(field: field, value: trimmedValue)
        }
    }
}
