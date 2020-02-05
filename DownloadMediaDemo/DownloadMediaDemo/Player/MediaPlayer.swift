//
//  mediaPlayer.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit
import AVFoundation

@objc
protocol MediaPlayerDelegate {
    @objc optional func mediaPlayer(readyToPlay player: MediaPlayer)
    @objc optional func mediaPlayer(didFinishPlay player: MediaPlayer)
    @objc optional func mediaPlayer(_ player: MediaPlayer, didFailWithError error: Error?)
    @objc optional func mediaPlayer(_ player: MediaPlayer, didChangeProgress progress: TimeInterval)
}

typealias ClosureVoid = () -> ()

class MediaPlayer: NSObject {
    
    struct NotificationName {
        static let ReadyToPlay          = "MediaPlayer.Notification.ReadyToPlay"
        static let DidChangeProgress    = "MediaPlayer.Notification.DidChangeProgress"
    }
    
    // MARK: - Properties
    // MARK: Public

    weak var delegate: MediaPlayerDelegate?

    var playerView: PlayerView? {
        didSet {
            self.playerView?.playerLayer.player = self.player
            self.playerView?.playerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    private(set) var isMuted                         = false
    private(set) var isPlaying                       = false
    var autoPlay                                     = false
    
    private(set) var currentDuration: TimeInterval   = 0.0
    private(set) var currentProgress: TimeInterval   = 0.0 {
        didSet {
            self.delegate?.mediaPlayer?(self, didChangeProgress: self.currentProgress)
            NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationName.DidChangeProgress), object: nil)
        }
    }
    
    private var currentPlayerItem: AVPlayerItem? {
        return self.player?.currentItem
    }
    
    private(set) var playerStatus = AVPlayer.Status.unknown {
        didSet {
            switch  playerStatus {
            case .failed:
                self.delegate?.mediaPlayer?(self, didFailWithError: self.player?.error)
            case .readyToPlay:
                self.updateCurrentVideoDuration(completion: {
                    self.delegate?.mediaPlayer?(readyToPlay: self)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: NotificationName.ReadyToPlay), object: nil)
                    if self.autoPlay {
                        self.autoPlay = false
                        _ = self.play()
                    }
                })
            default:
                print("Media player in unknown state")
                break
            }
        }
    }
    
    // MARK: Private
    
    private var player:                 AVPlayer?
    private var currentVolume: Float    = 0.0
    private let notificationCenter      = NotificationCenter.default
    private var isSeekInProgress        = false
    private var chaseTime               = CMTime.zero
    private var prevIsPlaying           = false
    private var statusObservation:      NSKeyValueObservation?
    private var progressObserver:       Any?

    // MARK: - Life Cycle Methods
    
    convenience init(withURL url: URL) {
        let playerItem = AVPlayerItem(url: url)
        self.init(playerItem: playerItem)
    }

    convenience init(withAsset asset: AVAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        self.init(playerItem: playerItem)
    }
    
    init(playerItem: AVPlayerItem) {
        super.init()
        self.setupPlayer(withItem: playerItem)
    }
    
    deinit {
        self.removeStatusObserver()
    }
    
    // MARK: - Public Methods
    
    func play() -> Bool {
        if self.playerStatus != .readyToPlay ||
           self.isPlaying { return false }
        guard let player = self.player else { return false }
        
        self.isPlaying = true
        player.play()
        self.startUpdatingProgress()
        
        return true
    }
    
    func pause() -> Bool {
        if self.playerStatus != .readyToPlay ||
           !self.isPlaying { return false }
        guard let player = self.player else { return false }
        
        self.isPlaying = false
        self.stopUpdatingProgress()
        player.pause()
        
        return true
    }
    
    func stop() -> Bool {
        if self.playerStatus != .readyToPlay { return false }
        guard let player = self.player else { return false }
        
        self.isPlaying = false
        self.stopUpdatingProgress()
        player.pause()
        player.seek(to: CMTime.zero)
        self.currentProgress = 0.0
        
        return true
    }
    
    func mute() {
        if self.playerStatus != .readyToPlay ||
          !self.isMuted { return }
        
        self.isMuted = true
        self.currentVolume = self.player?.volume ?? 0
        self.player?.volume = 0.0
    }
    
    func unmute() {
        if self.playerStatus != .readyToPlay ||
           self.isMuted { return }
        
        self.isMuted = false
        self.player?.volume = self.currentVolume
    }
    
    func seek(toTime time: TimeInterval, completion: ClosureVoid? = nil) {
        if self.playerStatus != .readyToPlay {
            completion?()
            return
        }
        
        let newChaseTime = CMTimeMakeWithSeconds(Float64(time), preferredTimescale: Int32(NSEC_PER_SEC))
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            if !self.isSeekInProgress {
                self.prevIsPlaying = self.isPlaying
                _ = self.pause()
            }
            
            self.chaseTime = newChaseTime;
            if !self.isSeekInProgress {
                self.actualSeekToTime(completion)
            } else {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPlayer(withItem item: AVPlayerItem) {
        self.player = AVPlayer(playerItem: item)
        self.player?.pause()
        self.addStatusObserver()
    }

    private func updateCurrentVideoDuration(completion: @escaping ClosureVoid) {
        guard let player = self.player else { return }
        
        DispatchQueue.global().async(execute: {
            if let asset = player.currentItem?.asset {
                let duration = TimeInterval(CMTimeGetSeconds(asset.duration))
                
                DispatchQueue.main.async(execute: {
                    self.currentDuration = duration
                    completion()
                })
            }
            
        })
    }

    
    private func actualSeekToTime(_ completion: ClosureVoid? = nil) {
        self.isSeekInProgress = true
        let seekTimeInProgress = self.chaseTime
        self.player?.seek(to: seekTimeInProgress, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { (isFinished:Bool) -> Void in
            if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                if self.prevIsPlaying {
                    _ = self.play()
                }
                self.isSeekInProgress = false
                
                completion?()
            } else {
                self.actualSeekToTime(completion)
            }
        })
    }
    
    // MARK: Progress
    
    private func startUpdatingProgress() {
        guard let p = self.player else { return }
        
        self.stopUpdatingProgress()
        self.progressObserver = p.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.1, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                          queue: DispatchQueue.main,
                                                          using: { [weak self] (cmTime) in
                                        self?.updateProgress()
        })
    }
    
    private func stopUpdatingProgress() {
        guard let p = self.player, let po = self.progressObserver else {
            return
        }
        
        p.removeTimeObserver(po)
        self.progressObserver = nil
    }
    
    private func updateProgress() {
        if !self.isPlaying { return }
        
        self.currentProgress = TimeInterval(CMTimeGetSeconds(self.player!.currentTime()))
        
        if self.currentProgress >= self.currentDuration {
            _ = self.stop()
            delegate?.mediaPlayer?(didFinishPlay: self)
        }
    }
    
    // MARK: Status
    
    private func addStatusObserver() {
        guard let player = self.player else { return }
        
        self.removeStatusObserver()
        self.statusObservation = player.observe(\.status, changeHandler: { [weak self] (player, _) in
            self?.playerStatus = player.status
        })
    }
    
    private func removeStatusObserver() {
        if let so = self.statusObservation {
            so.invalidate()
            self.statusObservation = nil
        }
    }
    
}
