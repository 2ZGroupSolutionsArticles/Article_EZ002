//
//  ResourceLoaderViewController.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit
import AVFoundation

class SimpleResourceLoaderViewController: VideoViewController {

    // MARK: - Properties
    
    private var loaderDelegate: SimpleResourceLoaderDelegate?
    
    // MARK: - Life Cycle Methods
    
    deinit {
        self.loaderDelegate?.invalidate()
    }
    
    // MARK: - Private Methods
    
    override func createPlayer() -> MediaPlayer {
        guard let url = URL(string: "https://www.radiantmediaplayer.com/media/bbb-360p.mp4") else {
            fatalError("Wrong video url.")
        }
        
        self.loaderDelegate = SimpleResourceLoaderDelegate(withURL: url)
        let videoAsset = AVURLAsset(url: self.loaderDelegate!.streamingAssetURL)
        videoAsset.resourceLoader.setDelegate(self.loaderDelegate, queue: DispatchQueue.main)
        self.loaderDelegate?.completion = { localFileURL in
            if let localFileURL = localFileURL {
                print("Media file saved to: \(localFileURL)")
            } else {
                print("Failed to download media file.")
            }
        }
        
        let player = MediaPlayer(withAsset: videoAsset)
        player.delegate = self
        player.playerView = self.playerView
        
        return player
    }

}
