//
//  PlayerRouter.swift
//
//  Created by jekster on 04.02.2021.
//

import UIKit

class PlayerRouter: PlayerModuleRouter {

    internal weak var delegate: PlayerRouterDelegate?
    
/// Controller which is used to perform presentations.
    weak var transitionHandler: UIViewController?
        
    func dismissPresented(animated: Bool, completion: (() -> Void)?) {
        transitionHandler?.dismiss(animated: animated, completion: completion)
    }
    
    func openQualityList(list: [Int]) {
        let alert = AlertView(models: list) { (model) -> (String?) in
            return model.toString()
        } subtitleMapping: { (_) -> (String?) in
            return nil
        } isModelCheked: { (_) -> (Bool) in
            return false
        }
        
        alert.style = .single

        alert.modelSelected = { [weak self] model in
            self?.delegate?.qualityDidChange(quality: model)
            alert.dismiss(animated: true, completion: nil)
        }
        
        transitionHandler?.present(alert, animated: true, completion: nil)
    }
}

