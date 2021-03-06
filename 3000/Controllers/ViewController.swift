//
//  ViewController.swift
//  3000
//
//  Created by Alexander Alemayhu on 26/08/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

import Cocoa
import AVFoundation
import Foundation
import Dispatch

class ViewController: NSViewController {
    
    // Views
    @IBOutlet weak var trackInfoLabel: NSTextField!
    @IBOutlet weak var trackArtistLabel: NSTextField!
    @IBOutlet weak var imageView: ArtworkImageView!
    var mainView: MainView? {
        get {
            return self.view as? MainView
        }
    }
    
    // Controllers
    var tracksViewController: TracksViewController?
    var isTracksViewVisible = false
    
    // Player
    var pm: PlayerManager = PlayerManager()
    
    // Application state
    var shouldWeShowNotifications = true
    var sizeBeforeFullscreen: NSRect?
    
    // View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.aspectRatio = NSSize(width: 1, height: 1)
    }
    
    // View changes
    
    @objc func updateView() {
        guard let index = pm.getIndex() else {
            self.updateViewForEmptyPlaylist()
            return
        }
        
        let track = self.pm.metadata(for: index)
        let title = track.title ?? ""
        let artist = track.artist ?? ""
        
        // Album image
        loadArtwork(for: index, track: track)
        
        // Track info
        let textColor = track.artwork?.areaAverage().contrast()
        self.trackInfoLabel.stringValue = "\(title)"
        self.trackArtistLabel.stringValue = "\(artist)"
        self.trackInfoLabel.textColor = textColor
        self.trackArtistLabel.textColor = textColor
    }
    
    func updateViewForEmptyPlaylist() {
        self.trackInfoLabel.stringValue = ""
        self.trackArtistLabel.stringValue = "Drag a folder with mp3\n and / or m4a files"
        self.trackArtistLabel.textColor = NSColor.white
        self.toggleTrackInfo(hidden: true)
        self.imageView.configure(with: NSImage(named: "Placeholder"))        
    }
    
    func updateArtwork(with artwork: NSImage?) {
        guard let artwork = artwork else { return }
        self.imageView.configure(with: artwork)
    }
    
    func loadArtwork(for index: Int, track: TrackMetadata) {
        // Prevent excessive calls to NSImage
        guard !track.isLoaded else { return }
        
        let op = MetadataLoader(asset: self.pm.asset(for: index), track: track, completionBlock: {
            DispatchQueue.main.sync {[unowned self] in
                self.updateArtwork(with: track.artwork)
            }
        })
        op.start()
    }
    
    // ---
    
    func configure () {
        registerNotificationObservers()
        registerLocalMonitoringKeyboardEvents()
        loadDefaults()
        
        toggleTrackInfo(hidden: true)
        
        self.mainView?.setupDragEvents(dragNotifier: self)
        self.imageView?.setupDragEvents(dragNotifier: self)
    }
    
    func registerLocalMonitoringKeyboardEvents() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {[unowned self] in
            // Only use supported keybindings
            if let key = $0.characters, let k = Keybinding(rawValue: key) {
                self.keyDown(with: k)
                return nil
            }
            // Allow system to handle all other defaults, like CMD+O, etc.
            return $0
        }
    }
    
    func registerNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(openedDirectory),
                                               name: Notification.Name.OpenedFolder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateView),
                                               name: Notification.Name.StartPlaylist, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(note:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidStart(note:)),
                                               name: NSNotification.Name.StartPlayingItem, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenResize),
                                               name: NSWindow.didResizeNotification, object: nil)
    }
    
    func loadDefaults() {
        if let folder = self.pm.securityScopedUrlForPlaylist(), self.usePlaylist(folder) {
            // Found a playable playlist
            self.updateView()
            return
        }
        // No playlist show placeholder values
        self.updateViewForEmptyPlaylist()
    }
    
    func keyDown(with key: Keybinding) {
        debug_print("\(#function)")
        switch key {
        case Keybinding.PlayOrPause:
            self.playOrPause()
        case Keybinding.VolumeUp:
            self.pm.changeVolume(change: 0.01)
        case Keybinding.VolumeDown:
            self.pm.changeVolume(change: -0.01)
        case Keybinding.Loop:
            self.toggleLoop()
        case Keybinding.Random:
            self.pm.playRandomTrack()
        case Keybinding.Previous:
            self.pm.playPreviousTrack()
        case Keybinding.Next:
            self.pm.playNextTrack()
        case Keybinding.Mute:
            self.pm.mute()
        case Keybinding.Tracks:
            self.showTracksView()
        case Keybinding.Esc:
            self.hideTracksView()
        case Keybinding.Obs:
            self.showObsFilePath()
        }
    }    
    
    func usePlaylist(_ folder: URL) -> Bool{
        let p = Playlist(folder: folder)
        if let error = self.pm.useCache(playlist: p), p.size() == 0 {
            debug_print(error.localizedDescription)
            return false
        }
        return true
    }
    
    
    func hideTracksView() {
        guard self.isTracksViewVisible else { return }
        self.isTracksViewVisible = false
        self.tracksViewController?.view.animator().removeFromSuperview()
        self.tracksViewController = nil
    }
    
    func showObsFilePath() {
        let alert = NSAlert.init()
        alert.addButton(withTitle: "OK")
        alert.messageText = "\(NSTemporaryDirectory())file-for-obs.txt"
        alert.runModal()
        alert.alertStyle = .informational
    }
    
    // Directory management
    
    @objc func openedDirectory() {
        guard let selectedFolder = self.pm.securityScopedUrlForPlaylist() else {
            debug_print("\(#function): selectedFolder is nil")
            return
        }
        self.pm.resetPlayerState()       
        guard self.usePlaylist(selectedFolder) else {
            debug_print("\(#function): failed to use playlist")
            return
        }
        self.pm.startPlaylist()
    }
    
    // Notification handlers
    
    @objc func screenResize() {
        debug_print("\(#function)")
        let fontSize = max(self.imageView.frame.size.width/28, 13)
        self.trackArtistLabel.font = NSFont(name: "Helvetica Neue Bold", size: fontSize)
        self.trackInfoLabel.font = NSFont(name: "Helvetica Neue Light", size: fontSize)
        self.tracksViewController?.view.frame = self.view.frame
        self.tracksViewController?.view.needsDisplay = true
        self.imageView.resize(frame: self.view.frame)
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification){
        self.pm.playNextTrack()
    }
    
    @objc func playerDidStart(note: NSNotification){
        self.updateView()
        writeOutTrackInfoForOBS()

        guard let window = self.view.window, window.level != .floating else { return }
        guard !shouldWeShowNotifications else { return }
        showPlayingNextNotification()
    }
    
    func showPlayingNextNotification() {
        guard let index = pm.getIndex() else { return }
        let track = self.pm.metadata(for: index)
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()

        // Prevent excessive calls to NSImage
        if track.isLoaded {
            self.presentNotification(for: track)
            return
        }
        
        let op = MetadataLoader(asset: self.pm.asset(for: index), track: track, completionBlock: {
            DispatchQueue.main.sync {[unowned self] in
                self.presentNotification(for: track)
            }
        })
        op.start()
    }
    
    func presentNotification(for track: TrackMetadata) {
        let notification = NSUserNotification()
        notification.title = track.artist
        notification.subtitle = track.title
        notification.contentImage = track.artwork
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func writeOutTrackInfoForOBS() {
        guard let index = pm.getIndex() else { return }
        let track = self.pm.metadata(for: index)
        do {
            let filePath = "\(NSTemporaryDirectory())file-for-obs.txt"
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = track.obsData()
            try data?.write(to: fileUrl)
        } catch {
            debug_print(error.localizedDescription)
        }
    }


    // Blur handling
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.imageView?.blur()
        self.toggleTrackInfo(hidden: false)

    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.imageView?.unblur()
        self.toggleTrackInfo(hidden: true)
    }
    
    func toggleTrackInfo(hidden: Bool) {
        trackInfoLabel.isHidden = hidden
        trackArtistLabel.isHidden = hidden
    }
}
