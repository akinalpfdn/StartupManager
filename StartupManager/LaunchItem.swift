import Foundation

protocol LaunchItem {
    var name: String { get }
    var path: String { get }
    var isEnabled: Bool { get }
    var publisher: String? { get }
    var startupImpact: String { get }
}

// Background Activity (macOS Background Items)
struct BackgroundActivity: LaunchItem {
    let name: String
    let path: String
    let isEnabled: Bool
    let publisher: String?
    let startupImpact: String
    let bundleIdentifier: String?
    let type: BackgroundActivityType

    enum BackgroundActivityType: String {
        case loginItem = "Login Item"
        case backgroundItem = "Background Item"
        case agent = "Agent"
    }
}