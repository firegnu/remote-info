@testable import RemoteInfoCore
import XCTest

final class HostConfigLoaderTests: XCTestCase {
    func testLoadsTwoHostsFromJSON() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "remote-info-host-a" },
                { "id": "host-b", "name": "Host B", "sshTarget": "remote-info-host-b" }
              ]
            }
            """
        )

        let hosts = try HostConfigLoader().load(from: url)

        XCTAssertEqual(
            hosts,
            [
                HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
                HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
            ]
        )
    }

    func testRejectsConfigsThatDoNotContainExactlyTwoHosts() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "remote-info-host-a" }
              ]
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(error as? HostConfigError, .expectedExactlyTwoHosts(actualCount: 1))
        }
    }

    func testRejectsEmptySSHTarget() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "remote-info-host-a" },
                { "id": "host-b", "name": "Host B", "sshTarget": "   " }
              ]
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(error as? HostConfigError, .emptyField("sshTarget"))
        }
    }

    private func writeTemporaryConfig(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("hosts.json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
