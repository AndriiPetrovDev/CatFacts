//
//  SceneDelegate.swift
//  CatFacts
//
//  Created by Kerem Gunduz on 30/03/2021.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let dependencies = AppDependencies.live()
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let navigationController = UINavigationController()
        let screenFactory = ScreenFactory(dependencies: dependencies)
        let coordinator = AppCoordinator(navigationController: navigationController, screenFactory: screenFactory)

        self.window = window
        self.coordinator = coordinator
        window.rootViewController = navigationController

        coordinator.start()
        window.makeKeyAndVisible()
    }
}
