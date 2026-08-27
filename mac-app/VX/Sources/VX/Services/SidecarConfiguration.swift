import Foundation

enum SidecarConfiguration {
    static let defaultHost = "127.0.0.1"
    static let defaultPort = 8765

    static func baseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let host = environment["VX_HOST"] ?? defaultHost
        let port = Int(environment["VX_PORT"] ?? "") ?? defaultPort
        return URL(string: "http://\(host):\(port)")!
    }
}
