import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func start()
}
