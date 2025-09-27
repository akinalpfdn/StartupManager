import Foundation

struct LaunchAgent: LaunchItem {
    let name: String
    let path: String
    let isEnabled: Bool
    let publisher: String?
    let startupImpact: String
    let label: String?
}