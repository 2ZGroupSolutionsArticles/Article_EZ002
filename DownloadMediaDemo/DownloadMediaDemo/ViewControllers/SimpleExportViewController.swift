//
//  FastExportViewController.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit
import AVFoundation

class SimpleExportViewController: VideoViewController {
    
    // MARK: - Properties
    
    private var exporter: AVAssetExportSession?
    
    // MARK: - Life Cycle Methods
    
    deinit {
        self.exporter?.cancelExport()
    }
    
    // MARK: - Private Methods
    
    override func createPlayer() -> MediaPlayer {
        guard let url = URL(string: "https://www.radiantmediaplayer.com/media/bbb-360p.mp4") else {
            fatalError("Wrong video url.")
        }
        
        let videoAsset = AVURLAsset(url: url)
        self.exportSession(forAsset: videoAsset)
        
        let player = MediaPlayer(withAsset: videoAsset)
        player.delegate = self
        player.playerView = self.playerView
        
        return player
    }
    
    private func exportSession(forAsset asset: AVURLAsset) {
        if !asset.isExportable { return }
        
        // --- https://stackoverflow.com/a/41545559/1065334
        let composition = AVMutableComposition()

        if let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)),
           let sourceVideoTrack = asset.tracks(withMediaType: .video).first {
            do {
                try compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: sourceVideoTrack, at: CMTime.zero)
            } catch {
                print("Failed to compose video")
                return
            }
        }
        if let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)),
           let sourceAudioTrack = asset.tracks(withMediaType: .audio).first {
            do {
                try compositionAudioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: sourceAudioTrack, at: CMTime.zero)
            } catch {
                print("Failed to compose audio")
                return
            }
        }
        // ---
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Failed to create export session")
            return
        }
        
        self.exporter = exporter
        let fileName = asset.url.lastPathComponent
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let outputURL = documentsDirectory.appendingPathComponent(fileName)
        print("File path: \(outputURL)")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch let error {
                print("Failed to delete file with error: \(error)")
            }
        }
        
        exporter.outputURL = outputURL
        exporter.outputFileType = AVFileType.mp4
        
        exporter.exportAsynchronously {
            print("Exporter did finish")
            if let error = exporter.error {
                print("Error \(error)")
            }
        }
    }
    
}
