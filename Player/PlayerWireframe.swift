//
//  PlayerWireframe.swift
//
//  Created by jekster on 04.02.2021.
//

// swiftlint:disable all

import UIKit

final class PlayerWireframe {

    public struct PlayerModule {
        let view: UIViewController
        let presenter: PlayerModulePresenter
        let interactor: PlayerModuleInteractor
        let router: PlayerModuleRouter
    }
    
    // MARK: - Private properties -

    private let storyboard = UIStoryboard(name: "Player", bundle: nil)

    // MARK: - Module setup -

    func createModule(type: PlayerType, item: MatchItem, details: MatchPopupDetails?, moments: [MatchMomentModel]) -> PlayerModule {
        let moduleViewController = storyboard.instantiateViewController(ofType: PlayerViewController.self)
        
        let playlistModule = PlaylistWireframe().createModule(model: item, details: details)
        
        let router = PlayerRouter()
        router.transitionHandler = moduleViewController

        let interactor = PlayerInteractor()
        let presenter = PlayerPresenter(
            type: type,
            model: item,
            moments: moments,
            playlistModule: playlistModule.view,
            view: moduleViewController,
            interactor: interactor,
            router: router
        )
        
        playlistModule.presenter.delegate = presenter
        
        moduleViewController.presenter = presenter
        
        return PlayerModule(view: moduleViewController, presenter: presenter, interactor: interactor, router: router)
    }
}
