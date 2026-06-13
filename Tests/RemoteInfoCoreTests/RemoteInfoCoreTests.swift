@testable import RemoteInfoCore
import XCTest

final class RemoteInfoCoreTests: XCTestCase {
    func testAppMetadata() {
        XCTAssertEqual(RemoteInfoCore.appName, "RemoteInfo")
        XCTAssertEqual(RemoteInfoCore.bundleIdentifier, "dev.firegnu.RemoteInfo")
    }
}
