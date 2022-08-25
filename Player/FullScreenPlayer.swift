//
//  FullScreenPlayer.swift
//
//  Created by jekster on 04.02.2021.
//

import AVKit

protocol PlayerProtocol {
    var playerDelegate: FullScreenPlayerDelegate? { get set }
    var state: FullScreenPlayerState { get }
    var isPlaying: Bool { get }
    func setItems(items: [Playable], seek: Int)
    func currentItem() -> Int
    func toggle()
    func seek(to time: Int)
    func setOriginMatch(items: [Playable])
    func playPlayable(_ item: Playable, needRebuildQueue: Bool, offset: Int) -> Int?
    var lastTime: Int { get set }
}

protocol FullScreenPlayerDelegate: class {
    func playerStateDidChange(state: FullScreenPlayerState)
    func playerProgressDidChange(currentTime: Int)
}

enum FullScreenPlayerState {
    case loading
    case loaded
}
