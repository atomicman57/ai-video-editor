import XCTest
@testable import VX

final class SidecarConfigurationTests: XCTestCase {
    func testDefaultsToLoopbackPort8765() {
        let url = SidecarConfiguration.baseURL(environment: [:])

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:8765")
    }

    func testUsesConfiguredSidecarPort() {
        let url = SidecarConfiguration.baseURL(environment: ["VX_PORT": "18765"])

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:18765")
    }

    func testUsesConfiguredSidecarHost() {
        let url = SidecarConfiguration.baseURL(environment: [
            "VX_HOST": "localhost",
            "VX_PORT": "18765",
        ])

        XCTAssertEqual(url.absoluteString, "http://localhost:18765")
    }

    func testFallsBackWhenPortIsInvalid() {
        let url = SidecarConfiguration.baseURL(environment: ["VX_PORT": "not-a-port"])

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:8765")
    }
}
