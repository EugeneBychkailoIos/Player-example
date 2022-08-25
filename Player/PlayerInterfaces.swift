//
//  PlayerInterfaces.swift
//
//  Created by jekster on 04.02.2021.
//

import UIKit
import AVKit

enum PlayerType {
    case full
    case episode
}

protocol MatchMomentModel {
    var startSecond: Int { get }
    var endSecond: Int { get }
    var period: Int { get }
}

extension MatchPopupRequest.TimeMomentMatchPopupResult: MatchMomentModel {}
extension MatchPlayerPlaylistRequest.TimeMomentMatchPlayerPlaylistItem: MatchMomentModel {}

struct Playable {
    let url: String
    let period: Int
    let duration: Int
    let rangePlaying: (startTime: Int, endTime: Int)?
    
    init(
        url: String,
        period: Int,
        duration: Int,
        rangePlaying: (startTime: Int, endTime: Int)? = nil
    ) {
        self.url = url
        self.period = period
        self.rangePlaying = rangePlaying
        
        if let range = self.rangePlaying {
            self.duration = range.endTime - range.startTime
        } else {
            self.duration = duration
        }
    }
}

extension Playable: Equatable {
    static func == (lhs: Playable, rhs: Playable) -> Bool {
        return lhs.url == rhs.url &&
            lhs.period == rhs.period &&
            lhs.duration == rhs.duration &&
            lhs.rangePlaying?.startTime == rhs.rangePlaying?.startTime &&
            lhs.rangePlaying?.endTime == rhs.rangePlaying?.endTime
    }
}

struct PlayerItem {
    let quality: Int
    let videos: [Playable]
}

protocol PlayerRouterDelegate: class {
    func qualityDidChange(quality: Int)
}

protocol PlayerModuleRouter: class {
    
    var delegate: PlayerRouterDelegate? { get set }
    
    /// Dismiss presented screen.
    func dismissPresented(animated: Bool, completion: (() -> Void)?)
    
    func openQualityList(list: [Int])
}

protocol PlayerModuleView: class {
    func startLoading()
    func stopLoading()
    func updateView()
    func hideControls()
    func addSubmodule(module: UIViewController)
    func playPlayable(_ item: Playable)
}

protocol PlayerModulePresenter: class {
    var qualityList: [Int] { get }
    var matchPlayableItems: [Playable] { get }
    var playableItems: [Playable] { get }
    var currentQuality: Int { get }
    var duration: Int { get }
    
    var isEpisodes: Bool { get }
    
    func getDeltaTime(period: Int) -> Int
    
    var title: String { get }
    var subtitle: String { get }
    
    func changeQuality()
    
    func restartTimer()
    
    func dismiss()
}

protocol PlayerModuleInteractorDelegate: class {
    func didPlayVideos(items: [PlayerItem])
}

protocol PlayerModuleInteractor: class {
    var delegate: PlayerModuleInteractorDelegate? { get set }
    
    var languageId: String { get }
    
    func getMatchDetails(match: MatchItem)
    
    func getSportName(id: Int) -> String?
    
    func getCountryNameByTournament(id: Int) -> String?
}
