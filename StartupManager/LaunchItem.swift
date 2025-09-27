import Foundation

protocol LaunchItem {
    var name: String { get }
    var path: String { get }
    var isEnabled: Bool { get }
    var publisher: String? { get }
    var startupImpact: String { get }
}