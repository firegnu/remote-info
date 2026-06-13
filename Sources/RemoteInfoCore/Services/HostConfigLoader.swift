import Foundation

public struct HostConfigLoader: Sendable {
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
        guard hosts.count == 2 else {
            throw HostConfigError.expectedExactlyTwoHosts(actualCount: hosts.count)
        }

        for host in hosts {
            try validateNonEmpty(host.id, field: "id")
            try validateNonEmpty(host.name, field: "name")
            try validateNonEmpty(host.sshTarget, field: "sshTarget")
        }
    }

    private func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw HostConfigError.emptyField(field)
        }
    }
}
