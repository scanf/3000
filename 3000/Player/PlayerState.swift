//
//  PlayerState.swift
//  3000
//
//  Created by ccscanf on 13/09/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

import AVFoundation

class PlayerState {
    
    var lastTrack: String
    var volume: Float
    var seconds: Double?
    var timescale: CMTimeScale?
    
    // TODO: save the previous index?
    var previousIndex: Int {
        get { return self.previous }
    }
    
    var currentIndex: Int {
        get { return self.index }
    }
    
    private var index: Int = 0
    private var previous: Int = 0
    
    // TODO: save the value of isLooping
    var isLooping = false

    init() {
        self.lastTrack = ""
        self.volume = PlayerManager.DefaultVolumeValue
    }
    
    func update(time: CMTime?, track: String) {
         self.seconds = time?.seconds
         self.timescale = time?.timescale
         self.lastTrack = track
    }
    
    func reset() {
        self.index = 0
        self.lastTrack = ""
    }
    
    func next() {
        self.previous = self.index
        self.index += 1
    }
    
    func back() {
        self.index = self.previousIndex
    }
    
    func random(upperBound: Int) {
        self.previous = self.index
        self.index = Int(arc4random_uniform(UInt32(upperBound)))
    }
    
    func from(_ i: Int) {
        self.previous = self.index
        self.index = i
    }
}
