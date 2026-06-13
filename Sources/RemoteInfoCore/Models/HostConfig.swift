import Foundation

public struct HostConfig: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sshTarget: String

    public init(id: String, name: String, sshTarget: String) {
        self.id = id
        self.name = name
        self.sshTarget = sshTarget
    }
}

public struct HostConfigFile: Codable, Equatable, Sendable {
    public let hosts: [HostConfig]

    public init(hosts: [HostConfig]) {
        self.hosts = hosts
    }
}

public enum HostConfigError: Error, Equatable, LocalizedError {
    case fileMissing(URL)
    case expectedExactlyTwoHosts(actualCount: Int)
    case emptyField(String)

    public var errorDescription: String? {
        switch self {
        case .fileMissing(let url):
            "Host configuration file is missing at \(url.path)."
        case .expectedExactlyTwoHosts(let actualCount):
            "Host configuration must contain exactly two hosts; found \(actualCount)."
        case .emptyField(let field):
            "Host configuration field '\(field)' must not be empty."
        }
    }
}
