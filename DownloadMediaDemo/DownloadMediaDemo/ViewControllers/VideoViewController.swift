//
//  ViewController.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit
import AVFoundation

class VideoViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var playerView:      PlayerView!
    @IBOutlet weak var playStopButton:  UIButton!
    @IBOutlet weak var progressSlider:  UISlider!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!
    
    // MARK: - Properties
    
    fileprivate var player: MediaPlayer?
    
    // MARK: - Life Cycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.updateControlsForPlayer(readyToPlay: false)
        self.player = self.createPlayer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        _ = self.player?.stop()
        self.player = nil
    }
    
    // MARK: - IBActions
    
    @IBAction func playStopButtonPushed(_ sender: Any) {
        guard let player = self.player else {
            print("Player is nil.")
            return
        }
        
        if self.player?.isPlaying == true {
            _ = player.stop()
        } else {
            _ = player.play()
        }
        
        self.updatePlayButton()
    }
    
    @IBAction func progressSliderChanged(_ sender: UISlider) {
        guard let player = self.player else {
            print("Player is nil.")
            return
        }
        
        player.seek(toTime: TimeInterval(sender.value))
    }
    
    // MARK: - Private Methods

    func createPlayer() -> MediaPlayer {
        fatalError("Override")
    }
    
    fileprivate func updatePlayButton() {
        guard let player = self.player else {
            print("Player is nil.")
            return
        }
        
        self.playStopButton.isSelected = player.isPlaying
    }
    
    fileprivate func updateControlsForPlayer(readyToPlay ready: Bool) {
        self.playStopButton.isEnabled = ready
        self.progressSlider.isEnabled = ready
        
        if ready {
            self.loadingActivity.stopAnimating()
        }
    }
    
    fileprivate func setupSlider() {
        guard let player = self.player else {
            print("Player is nil.")
            return
        }
        
        self.progressSlider.maximumValue = Float(player.currentDuration)
    }
    
}

extension VideoViewController: MediaPlayerDelegate {
    
    func mediaPlayer(readyToPlay player: MediaPlayer) {
        self.updateControlsForPlayer(readyToPlay: true)
        self.setupSlider()
    }
    
    func mediaPlayer(didFinishPlay player: MediaPlayer) {
        self.updatePlayButton()
        self.setupSlider()
    }
    
    func mediaPlayer(_ player: MediaPlayer, didFailWithError error: Error?) {
        print("Video player failed with error: \(String(describing: error))")
    }
    
    func mediaPlayer(_ player: MediaPlayer, didChangeProgress progress: TimeInterval) {
        guard let player = self.player else {
            print("Player is nil.")
            return
        }
        
        self.progressSlider.value = Float(player.currentProgress)
    }

}
