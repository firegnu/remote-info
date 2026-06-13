@testable import RemoteInfoCore
import XCTest

final class HostConfigLoaderTests: XCTestCase {
    func testLoadsHostsFromJSON() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "test-host-a" },
                { "id": "host-b", "name": "Host B", "sshTarget": "test-host-b" },
                { "id": "host-c", "name": "Host C", "sshTarget": "test-host-c" }
              ]
            }
            """
        )

        let hosts = try HostConfigLoader().load(from: url)

        XCTAssertEqual(
            hosts,
            [
                HostConfig(id: "host-a", name: "Host A", sshTarget: "test-host-a"),
                HostConfig(id: "host-b", name: "Host B", sshTarget: "test-host-b"),
                HostConfig(id: "host-c", name: "Host C", sshTarget: "test-host-c")
            ]
        )
    }

    func testRejectsConfigsThatDoNotContainAnyHosts() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": []
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(error as? HostConfigError, .expectedAtLeastOneHost)
        }
    }

    func testRejectsEmptySSHTarget() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "test-host-a" },
                { "id": "host-b", "name": "Host B", "sshTarget": "   " }
              ]
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(error as? HostConfigError, .emptyField("sshTarget"))
        }
    }

    func testRejectsPlaceholderSSHTargets() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "CHANGE_ME_HOST_A" },
                { "id": "host-b", "name": "Host B", "sshTarget": "test-host-b" }
              ]
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(
                error as? HostConfigError,
                .placeholderField(field: "sshTarget", value: "CHANGE_ME_HOST_A")
            )
        }
    }

    func testRejectsDuplicateHostIDs() throws {
        let url = try writeTemporaryConfig(
            """
            {
              "hosts": [
                { "id": "host-a", "name": "Host A", "sshTarget": "test-host-a" },
                { "id": "host-a", "name": "Host B", "sshTarget": "test-host-b" }
              ]
            }
            """
        )

        XCTAssertThrowsError(try HostConfigLoader().load(from: url)) { error in
            XCTAssertEqual(error as? HostConfigError, .duplicateHostID("host-a"))
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
