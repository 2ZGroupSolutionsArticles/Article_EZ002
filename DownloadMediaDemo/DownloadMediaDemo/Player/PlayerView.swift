//
//  PlayerView.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
    
    override class var layerClass : AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
}
