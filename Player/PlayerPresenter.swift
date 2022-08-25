//
//  PlayerPresenter.swift
//
//  Created by jekster on 04.02.2021.
//

import Foundation
import AVKit

final class PlayerPresenter {

    // MARK: - Private properties -

    private weak var view: PlayerModuleView?
    private let interactor: PlayerModuleInteractor
    private let router: PlayerModuleRouter
    private let model: MatchItem
    private var items: [PlayerItem] = []
    private var moments: [MatchMomentModel] = []
    private var type: PlayerType = .full
    // MARK: - Lifecycle -

    private(set) var qualityList: [Int] = []
    private(set) var playableItems: [Playable] = []
    private(set) var matchPlayableItems: [Playable] = []
    private(set) var currentQuality: Int = 0
    private(set) var duration: Int = 0
    private(set) var title: String
    private(set) var subtitle: String
    
    private var timerItem: DispatchWorkItem?
    
    private let timerTimeout: DispatchTimeInterval = DispatchTimeInterval.seconds(10)
    
    init(
        type: PlayerType,
        model: MatchItem,
        moments: [MatchMomentModel],
        playlistModule: UIViewController,
        view: PlayerModuleView,
        interactor: PlayerModuleInteractor,
        router: PlayerModuleRouter
    ) {
        self.type = type
        self.model = model
        self.moments = moments
        self.view = view
        self.interactor = interactor
        self.router = router
        
        self.view?.startLoading()
        
        self.view?.addSubmodule(module: playlistModule)

        self.type = .episode
        
        let titles = [
            model.firstTeamName?.getValue(
                language: self.interactor.languageId
            ),
            model.secondTeamName?.getValue(
                language: self.interactor.languageId
            )
        ]
            .compactMap({ $0 })
        
        self.title = titles.joined(separator: " : ")
        
        let sport = self.interactor.getSportName(id: model.sportType)
        let country = self.interactor.getCountryNameByTournament(id: model.tournamentId)
        let tournamentName = model.tournamentName?.getValue(language: self.interactor.languageId)
        
        self.subtitle = [sport, country, tournamentName].compactMap({ $0 }).joined(separator: " | ")
        
        self.interactor.delegate = self
        self.router.delegate = self
        
        self.interactor
            .getMatchDetails(match: model)
    }
}

// MARK: - Extensions -

extension PlayerPresenter: PlayerModulePresenter {
    
    var isEpisodes: Bool {
        return self.type == .episode
    }
    
    func restartTimer() {
        self.timerItem?.cancel()
        self.timerItem = nil
        
        self.timerItem = DispatchWorkItem(block: { [weak self] in
            self?.view?.hideControls()
        })
        
        guard let item = self.timerItem else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + self.timerTimeout, execute: item)
    }
    
    func dismiss() {
        self.router.dismissPresented(animated: true, completion: nil)
    }
    
    func changeQuality() {
        self.router.openQualityList(list: self.items.map({ $0.quality }))
    }
}

extension PlayerPresenter: PlayerModuleInteractorDelegate {
    
    func getDeltaTime(period: Int) -> Int {
        
        guard self.type == .full else {
            return 0
        }
        
        guard let item = items.first(where: { $0.quality == self.currentQuality }) else {
            return 0
        }
        
        var delta: Int = 0
        
        guard period > 0 else {
            return delta
        }
        
        for i in (0...(period - 1)).reversed() {
            let video = item.videos[i]
            delta += video.duration
        }
        
        return delta
    }
    
    func didPlayVideos(items: [PlayerItem]) {
        self.items = items
        self.qualityList = self.items.map({ $0.quality })
        self.currentQuality = self.currentQuality == 0 ? self.qualityList.first ?? 0 : self.currentQuality
        
        let allDuration = self.items.first?.videos.map({ $0.duration }).reduce(0, { $0 + $1 }) ?? 0
        self.duration = allDuration

        guard let item = self.items.first(where: { $0.quality == self.currentQuality }) else {
            return
        }
        
        self.matchPlayableItems = item.videos
        
        var episodes = [Playable]()
        
        self.moments = self.moments.filter({ $0.startSecond != $0.endSecond })
        
        for moment in self.moments {
            if let video = item.videos.first(where: { $0.period == moment.period }) {
                let playable = Playable(
                    url: video.url,
                    period: video.period,
                    duration: video.duration,
                    rangePlaying: (moment.startSecond * 1000, moment.endSecond * 1000)
                )
                episodes.append(playable)
            }
        }
        
        if !episodes.isEmpty {
            self.duration = episodes.map({ $0.duration }).reduce(0, { $0 + $1 })
            self.playableItems = episodes
        }
        
        self.view?.updateView()
        self.view?.stopLoading()
    }
}

extension PlayerPresenter: PlayerRouterDelegate {
    func qualityDidChange(quality: Int) {
        self.currentQuality = quality
        self.didPlayVideos(items: self.items)
    }
}

extension PlayerPresenter: PlaylistModulePresenterDelegate {
    func didPlayItem(item: MatchMomentModel, origin: [MatchMomentModel]) {
        self.type = .episode
        self.moments = origin
        self.didPlayVideos(items: self.items)
        
        if let video = self.matchPlayableItems.first(where: { $0.period == item.period }) {
            let playable = Playable(
                url: video.url,
                period: video.period,
                duration: video.duration,
                rangePlaying: (item.startSecond * 1000, item.endSecond * 1000)
            )
            self.view?.playPlayable(playable)
        }
    }
}
