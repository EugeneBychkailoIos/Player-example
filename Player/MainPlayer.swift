//
//  MainPlayer.swift
//
//  Created by jekster on 05.03.2021.
//

import AVKit

class MainPlayer: AVPlayerViewController {
    internal weak var playerDelegate: FullScreenPlayerDelegate?
    internal var state: FullScreenPlayerState = .loading
    
    fileprivate var fullMatchQueue: [Playable] = []
    fileprivate var items: [Playable] = []
    
    fileprivate var currentPlayingItem: Playable?
    
    fileprivate var progressTimeObserver: Any?
    fileprivate var itemTimeObserver: Any?
    
    fileprivate var isEpisodes = false
    
    internal var lastTime: Int = 0
    
    fileprivate func rebuildQueue(period: Int, handler: @escaping () -> Void) {
        let queue = self.fullMatchQueue.dropFirst(period)
        let urls = queue.compactMap({ URL(string: $0.url) })
        
        let assets = urls.map({ AVAsset(url: $0 )})
        let items = assets.map({ AVPlayerItem(asset: $0) })
        
        self.state = .loading
        self.playerDelegate?.playerStateDidChange(state: self.state)
        
        if let timeObserver = self.progressTimeObserver {
            self.player?.removeTimeObserver(timeObserver)
            self.progressTimeObserver = nil
        }
        
        if let itemTimeObserver = self.itemTimeObserver {
            self.player?.removeTimeObserver(itemTimeObserver)
            self.itemTimeObserver = nil
        }
        
        let player = AVQueuePlayer(items: items)
        self.player = player
        self.playerDelegate?.playerStateDidChange(state: self.state)
        
        handler()
    }
    
    @discardableResult
    func playPlayable(_ item: Playable, needRebuildQueue: Bool = false, offset: Int = 0) -> Int? {
        
        self.currentPlayingItem = item

        let block = { [weak self] in
            self?.startTimeObserver()
            
            self?.player?.pause()
            let startTime = item.rangePlaying?.startTime ?? 0
            let time = CMTime(
                seconds: Double((startTime / 1000) + (offset)),
                preferredTimescale: CMTimeScale(NSEC_PER_SEC)
            )
            self?.player?.seek(to: time, completionHandler: { (finished) in
                self?.player?.play()
            })
        }
        
        var position: Int?
        
        if let item = self.currentPlayingItem,
           let index = self.items.firstIndex(where: { $0 == item }) {
            let previousItemsTime = self.items[0..<index]
                .reduce(0, { $0 + $1.duration })
            position = previousItemsTime
        }
        
        if needRebuildQueue {
            var period = item.period - 1
            period = period >= 0 ? period : 0
            self.rebuildQueue(period: period) {
                block()
            }
            return position
        }
        
        block()
        return position
    }
    
    private var previousTime: Float64 = 0
    
    fileprivate func startTimeObserver() {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        self.progressTimeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: DispatchQueue.main, using: { [weak self] time in
                guard let self = self else { return }
//                guard !self.seekInProgress else {
//                    return
//                }
//                self.updateTime()
                
                guard self.isEpisodes else { return }
                
                guard let currentPlayable = self.currentPlayingItem else { return }
                guard let currentItem = self.player?.currentItem else { return }
                
                let seconds = CMTimeGetSeconds(currentItem.currentTime())
                
                let endTime = currentPlayable.rangePlaying?.endTime ?? 0
                
                var previousItemsDuration = 0
                
                if let _ = self.items.firstIndex(of: currentPlayable) {
                    previousItemsDuration = self.fullMatchQueue[0..<(currentPlayable.period - 1)]
                        .reduce(0, { $0 + $1.duration })
                }
                
                let matchProgress = previousItemsDuration + (Int(seconds) * 1000)

                let endEpisodeTime = previousItemsDuration + endTime//(t1 + endTime) / 1000

                if matchProgress >= endEpisodeTime {
                    self.itemDidPlayToEndTime()
                }
            })
        
        self.itemTimeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main,
            using: { [weak self] (time) in
            
            guard let self = self else { return }
            
            guard let currentPlayable = self.currentPlayingItem else { return }
            guard let currentItem = self.player?.currentItem else { return }
            
            if !self.isEpisodes {
                let url: String? = (currentItem.asset as? AVURLAsset)?.url.absoluteString
                let playable = self.fullMatchQueue.first(where: { $0.url == url })
                self.currentPlayingItem = playable
            }
            
            var seconds = CMTimeGetSeconds(currentItem.currentTime())
            
            if self.previousTime == seconds {
                self.state = .loading
            } else {
                self.state = .loaded
            }
            
            self.playerDelegate?.playerStateDidChange(state: self.state)
            
            self.previousTime = seconds
            
            let startTime = currentPlayable.rangePlaying?.startTime ?? 0
            
            if self.isEpisodes {
                
                let currentItemTime = Int(seconds) - Int(Double(startTime / 1000))
                var previousItemsDuration = 0
                
                if let index = self.items.firstIndex(of: currentPlayable) {
                    previousItemsDuration = self.items[0..<index]
                        .reduce(0, { $0 + $1.duration }) / 1000
                }
                
                if currentItemTime > 0 {
                    self.lastTime = ((currentItemTime * 1000) + (previousItemsDuration * 1000))
                    self.playerDelegate?.playerProgressDidChange(
                        currentTime: ((currentItemTime * 1000) + (previousItemsDuration * 1000))
                    )
                }
            } else {
                var previousItemsDuration = 0
                
                if let index = self.items.firstIndex(of: currentPlayable) {
                    previousItemsDuration = self.items[0..<index]
                        .reduce(0, { $0 + $1.duration }) / 1000
                }
                
                seconds += Double(previousItemsDuration)
                seconds += Double(startTime)
                self.lastTime = Int(seconds) * 1000
                self.playerDelegate?.playerProgressDidChange(currentTime: Int(seconds) * 1000)
            }
            
        })
    }
    
    @objc private func itemDidPlayToEndTime() {
        
        guard let playable = self.currentPlayingItem else {
            fatalError()
        }
        
        guard let currentIndex = self.items.firstIndex(where: { $0 == playable }) else {
            fatalError()
        }
        
        let nextIndex = self.items.index(after: currentIndex)
        
        guard nextIndex < self.items.count,
              let nextPlayable = self.items[safe: nextIndex]
        else {
            self.player?.cancelPendingPrerolls()
            self.player?.replaceCurrentItem(with: nil)
            self.player = nil
            return
        }
        
        let needRebuildQueue = nextPlayable.period != playable.period
        
        self.player?.pause()
        
        if let time = self.playPlayable(nextPlayable, needRebuildQueue: needRebuildQueue) {
            self.playerDelegate?.playerProgressDidChange(currentTime: time)
        }
    }
}

extension MainPlayer: PlayerProtocol {
    
    var isPlaying: Bool {
        return self.player?.isPlaying ?? false
    }
    
    func setItems(items: [Playable], seek: Int) {
        self.isEpisodes = !items.isEmpty
        
        if self.isEpisodes {
            self.items = items
                .sorted(by: { $0.rangePlaying?.startTime ?? 0 < $1.rangePlaying?.startTime ?? 0 })
                .sorted(by: { $0.period < $1.period })
        } else {
            self.items = self.fullMatchQueue
        }
        
        let period = self.items.first?.period ?? 1
        
        self.rebuildQueue(period: period - 1) { [weak self] in
            if let firstItem = self?.items.first {
                self?.playPlayable(firstItem, needRebuildQueue: false)
                self?.seek(to: seek)
            }
        }
    }
    
    func currentItem() -> Int {
        return 0
    }
    
    func play() {
        self.player?.play()
    }
    
    func pause() {
        self.player?.pause()
    }
    
    func toggle() {
        guard let player = self.player else { return }
        player.isPlaying ? self.pause() : self.play()
    }
    
    func seek(to time: Int) {
        let seconds = Int(Double(time) / 1000.0)
        
        var target: Playable?
        
        var temp = seconds
        
        for item in self.items {
            
            temp -= Int(item.duration / 1000)
            
            if temp <= 0 {
                target = item
                break
            }
        }
        
        guard let targetItem = target else { return }
        guard let index = self.items.firstIndex(of: targetItem) else { return }
        
        let previousItemsDuration = self.items[0..<index]
            .reduce(0, { $0 + $1.duration }) / 1000
        
        let offset = seconds - previousItemsDuration
        
        if let _ = self.playPlayable(targetItem, needRebuildQueue: true, offset: offset) {}
    }
    
    func setOriginMatch(items: [Playable]) {
        self.fullMatchQueue = items
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return self.rate > 0
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
