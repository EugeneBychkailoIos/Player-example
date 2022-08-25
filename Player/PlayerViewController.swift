//
//  PlayerViewController.swift
//
//  Created by jekster on 04.02.2021.
//

import UIKit
import AVKit
import MediaPlayer

final class PlayerViewController: BaseViewController {

    @IBOutlet private weak var playerView: UIView!
    
    @IBOutlet private weak var momentsView: UIView!
    
    @IBOutlet private weak var playerControls: PlayerControls! {
        didSet {
            playerControls.delegate = self
        }
    }
    @IBOutlet weak var playerControlsCenterYConstraint: NSLayoutConstraint!
    
    private weak var playlistView: UIView?
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [playerControls]
    }
    
    // MARK: - Public properties -

    var presenter: PlayerModulePresenter!
    
    private lazy var splash: UIView = {
        
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        self.playerView.addSubview($0)
        
        NSLayoutConstraint.activate([
            $0.leadingAnchor.constraint(equalTo: self.playerView.leadingAnchor),
            $0.trailingAnchor.constraint(equalTo: self.playerView.trailingAnchor),
            $0.topAnchor.constraint(equalTo: self.playerView.topAnchor),
            $0.bottomAnchor.constraint(equalTo: self.playerView.bottomAnchor)
        ])
        
        return $0
    }(UIView())
    
    private lazy var playerController: PlayerProtocol = {
        
        let player = MainPlayer()
        
        if let view = player.view {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.playerView.addSubview(view)
            view.isUserInteractionEnabled = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.playerView.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.playerView.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: self.playerView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.playerView.trailingAnchor)
            ])
        }
        
        player.playerDelegate = self
        
        player.showsPlaybackControls = false
        player.didMove(toParent: self)
    
        self.splash.isHidden = false
        
        return player as PlayerProtocol
    }()
    
    // MARK: - Lifecycle -

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.playerControls.title = self.presenter.title
        self.playerControls.subtitleText = self.presenter.subtitle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        self.playerControls.setNeedsFocusUpdate()
        
        let menuPressRecognizer = UITapGestureRecognizer()
        menuPressRecognizer.addTarget(self, action: #selector(menuPressed(gesture:)))
        menuPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.view.addGestureRecognizer(menuPressRecognizer)
        
        let selectPressRecognizer = UITapGestureRecognizer()
        selectPressRecognizer.addTarget(self, action: #selector(selectPressed(gesture:)))
        selectPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        self.view.addGestureRecognizer(selectPressRecognizer)
        
        let playPausePressRecognizer = UITapGestureRecognizer()
        playPausePressRecognizer.addTarget(self, action: #selector(self.togglePlayButton))
        playPausePressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPausePressRecognizer)
    }
    
    @objc private func menuPressed(gesture: UITapGestureRecognizer) {
        self.presenter.restartTimer()
        if !self.playerControls.isHidden {
            self.hideControls()
        } else {
            self.presenter.dismiss()
        }
    }
    
    @objc private func selectPressed(gesture: UITapGestureRecognizer) {
        self.presenter.restartTimer()
        if self.playerControls.isHidden {
            self.splash.isHidden = false
            self.playerControls.isHidden = false
            self.playlistView?.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.splash.alpha = 1.0
                self.playerControls.alpha = 1.0
                self.playlistView?.alpha = 1.0
            } completion: { (finished) in
                self.view.setNeedsFocusUpdate()
                self.view.updateFocusIfNeeded()
            }
        }
    }
    
    @objc func hideControls() {
        UIView.animate(withDuration: 0.3) {
            self.splash.alpha = 0.0
            self.playerControls.alpha = 0.0
            self.playlistView?.alpha = 0.0
        } completion: { (finished) in
            if finished {
                self.splash.isHidden = true
                self.playerControls.isHidden = true
                self.playlistView?.isHidden = true
                
                self.playerControlsCenterYConstraint.constant = 0
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        self.presenter.restartTimer()
        
        let isNextViewCell = context.nextFocusedView is PaidMatchCell
        
        if isNextViewCell {
            // swiftlint:disable:next line_length
            self.playerControlsCenterYConstraint.constant = -((self.view.frame.height / 2) + self.playerControls.frame.height / 2)
        } else {
            self.playerControlsCenterYConstraint.constant = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}

// MARK: - Extensions -

extension PlayerViewController: PlayerModuleView {
    
    func playPlayable(_ item: Playable) {
        if let time = playerController.playPlayable(item, needRebuildQueue: true, offset: 0) {
            self.playerControls.currentTime = time
        }
        self.hideControls()
    }
    
    func addSubmodule(module: UIViewController) {
        self.addChild(module)
        if let view = module.view {
            self.playlistView = view
            view.translatesAutoresizingMaskIntoConstraints = false
            self.momentsView.addSubview(view)
            view.isUserInteractionEnabled = true
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.momentsView.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.momentsView.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: self.momentsView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.momentsView.trailingAnchor)
            ])
        }
        module.didMove(toParent: self)
    }
    
    func updateView() {
        self.playerControls.duration = self.presenter.duration
        self.playerController.setOriginMatch(items: self.presenter.matchPlayableItems)
        self.playerController.setItems(items: self.presenter.playableItems, seek: self.playerControls.sliderValue)
    }
}

extension PlayerViewController: FullScreenPlayerDelegate {
    
    func playerProgressDidChange(currentTime: Int) {
        guard currentTime != 0 else { return }
        let delta = self.presenter.getDeltaTime(period: self.playerController.currentItem())
        self.playerControls.currentTime = currentTime + delta
    }
    
    func playerStateDidChange(state: FullScreenPlayerState) {
        state == .loading ? self.startLoading() : self.stopLoading()
    }
}

extension PlayerViewController: PlayerControlsDelegate {
    func changeQuality() {
        self.presenter.restartTimer()
        self.presenter.changeQuality()
    }
    
    func playerState() -> Bool {
        self.playerController.isPlaying
    }
    
    func canInteractWithPlayerButton() -> Bool {
        return self.playerController.state == .loaded
    }
    
    @objc func togglePlayButton() {
        self.playerController.toggle()
        self.playerControls.isPlaying = self.playerController.isPlaying
    }
    
    func seekTo(time: Int) {
        
        guard Int(time / 1000) != self.playerController.lastTime else {
            return
        }
        
        self.presenter.restartTimer()
        self.playerController.seek(to: time)
        self.hideControls()
    }
}
