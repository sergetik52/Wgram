import Foundation
import UIKit
import AVFoundation
import UserNotifications
import CoreLocation
import TelegramCore
import SwiftSignalKit

public final class WgramKeepAlive: NSObject, AVAudioPlayerDelegate, CLLocationManagerDelegate {
    public static let shared = WgramKeepAlive()
    
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var taskRenewalTimer: SwiftSignalKit.Timer?
    private var locationManager: CLLocationManager?
    private var isLocationUpdating: Bool = false
    
    public private(set) var keepAliveStartTime: Date?
    
    public var isAudioActive: Bool {
        return self.audioPlayer?.isPlaying ?? false
    }
    
    public var isLocationActive: Bool {
        return self.isLocationUpdating
    }
    
    public var uptimeString: String {
        guard let start = self.keepAliveStartTime else { return "Не активна" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else if minutes > 0 {
            return "\(minutes) мин \(seconds) сек"
        } else {
            return "\(seconds) сек"
        }
    }
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: NSNotification.Name("WgramUpdateKeepAlive"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: NSNotification.Name("WgramKeepAliveChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: WgramSettings.didChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestLocationPermission), name: NSNotification.Name("WgramRequestLocationPermission"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleMediaServicesReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("WgramTestKeepAliveNotification"), object: nil, queue: .main) { _ in
            WgramKeepAlive.scheduleTestNotification(delaySeconds: 10.0) {}
        }
    }
    
    public func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    @objc public func handleEnterForeground() {
        self.stopTaskRenewalTimer()
        if self.backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
        self.updateState()
    }
    
    @objc public func handleEnterBackground() {
        if WgramSettings.keepAliveInBackground {
            self.start()
            self.startTaskRenewalChain()
        }
    }
    
    // MARK: - Audio Interruption & Route Change Handling
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            // Another app (Spotify, Apple Music, YouTube, Phone Call, etc.) took audio control.
            // DO NOT let Wgram die! Immediately ensure location updates and background task chain are active!
            self.startLocationUpdates()
            self.startTaskRenewalChain()
        } else if type == .ended && WgramSettings.keepAliveInBackground {
            Queue.mainQueue().after(0.5) { [weak self] in
                guard let strongSelf = self, WgramSettings.keepAliveInBackground else { return }
                strongSelf.tryResumeAudio()
            }
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard WgramSettings.keepAliveInBackground else { return }
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        if reason == .oldDeviceUnavailable || reason == .categoryChange || reason == .newDeviceAvailable {
            Queue.mainQueue().after(0.5) { [weak self] in
                guard let strongSelf = self, WgramSettings.keepAliveInBackground else { return }
                strongSelf.tryResumeAudio()
            }
        }
    }
    
    @objc private func handleMediaServicesReset() {
        guard WgramSettings.keepAliveInBackground else { return }
        self.audioPlayer = nil
        self.start()
    }
    
    @objc public func updateState() {
        if WgramSettings.keepAliveInBackground {
            self.requestNotificationPermissionIfNeeded()
            self.start()
            if UIApplication.shared.applicationState != .active {
                self.startTaskRenewalChain()
            }
        } else {
            self.stop()
        }
    }
    
    // MARK: - Background Task Chaining
    private func startTaskRenewalChain() {
        self.renewBackgroundTask()
        self.stopTaskRenewalTimer()
        
        let timer = SwiftSignalKit.Timer(timeout: 20.0, repeat: true, completion: { [weak self] in
            self?.renewBackgroundTask()
        }, queue: Queue.mainQueue())
        self.taskRenewalTimer = timer
        timer.start()
    }
    
    private func stopTaskRenewalTimer() {
        self.taskRenewalTimer?.invalidate()
        self.taskRenewalTimer = nil
    }
    
    private func renewBackgroundTask() {
        guard WgramSettings.keepAliveInBackground, UIApplication.shared.applicationState != .active else { return }
        
        let oldTaskId = self.backgroundTaskId
        self.backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "WgramPersistentKeepAlive") { [weak self] in
            self?.renewBackgroundTask()
        }
        
        if oldTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(oldTaskId)
        }
    }
    
    // MARK: - Core Execution
    public func start() {
        if self.keepAliveStartTime == nil {
            self.keepAliveStartTime = Date()
        }
        
        self.setupLocationKeepAlive()
        self.tryResumeAudio()
    }
    
    private func tryResumeAudio() {
        guard WgramSettings.keepAliveInBackground else { return }
        
        if let player = self.audioPlayer {
            if !player.isPlaying {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    player.play()
                } catch {
                    // Another app is playing audio exclusively. Location updates keep Wgram alive.
                    self.startLocationUpdates()
                }
            }
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay, .defaultToSpeaker])
            try session.setActive(true)
            
            // 10 seconds of PCM audio with inaudible micro-dither to keep CoreAudio engine continuously active
            let sampleRate: Double = 44100.0
            let duration: Double = 10.0
            let numSamples = Int(sampleRate * duration)
            var audioData = Data()
            
            let subChunk2Size = UInt32(numSamples * 2)
            let chunkSize = UInt32(36 + subChunk2Size)
            
            audioData.append(contentsOf: "RIFF".utf8)
            audioData.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
            audioData.append(contentsOf: "WAVEfmt ".utf8)
            let subChunk1Size: UInt32 = 16
            audioData.append(contentsOf: withUnsafeBytes(of: subChunk1Size.littleEndian) { Array($0) })
            let audioFormat: UInt16 = 1
            audioData.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
            let numChannels: UInt16 = 1
            audioData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
            let sRate: UInt32 = UInt32(sampleRate)
            audioData.append(contentsOf: withUnsafeBytes(of: sRate.littleEndian) { Array($0) })
            let byteRate: UInt32 = sRate * 2
            audioData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
            let blockAlign: UInt16 = 2
            audioData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
            let bitsPerSample: UInt16 = 16
            audioData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
            audioData.append(contentsOf: "data".utf8)
            audioData.append(contentsOf: withUnsafeBytes(of: subChunk2Size.littleEndian) { Array($0) })
            
            // Micro-dither samples: non-zero PCM values (-90 dBFS) every 1000 samples
            var samples = [Int16](repeating: 0, count: numSamples)
            for i in stride(from: 0, to: numSamples, by: 1000) {
                samples[i] = (i % 2000 == 0) ? 1 : -1
            }
            samples.withUnsafeBufferPointer { buffer in
                audioData.append(Data(buffer: buffer))
            }
            
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            player.numberOfLoops = -1
            player.volume = 0.001
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } catch {
            // Another app is playing audio exclusively. Location updates keep Wgram alive.
            self.startLocationUpdates()
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if WgramSettings.keepAliveInBackground {
            self.tryResumeAudio()
        }
    }
    
    // MARK: - Location Keep-Alive (Bulletproof Fallback for Music & Sound in Other Apps)
    @objc public func requestLocationPermission() {
        if self.locationManager == nil {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            manager.distanceFilter = 999999
            manager.pausesLocationUpdatesAutomatically = false
            self.locationManager = manager
        }
        self.locationManager?.requestAlwaysAuthorization()
    }
    
    private func setupLocationKeepAlive() {
        guard WgramSettings.keepAliveInBackground else { return }
        if self.locationManager == nil {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            manager.distanceFilter = 999999
            manager.pausesLocationUpdatesAutomatically = false
            self.locationManager = manager
        }
        
        guard let manager = self.locationManager else { return }
        
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            self.startLocationUpdates()
        }
    }
    
    private func startLocationUpdates() {
        guard let manager = self.locationManager, WgramSettings.keepAliveInBackground else { return }
        if !self.isLocationUpdating {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            if #available(iOS 11.0, *) {
                manager.showsBackgroundLocationIndicator = false
            }
            manager.startUpdatingLocation()
            self.isLocationUpdating = true
        }
    }
    
    private func stopLocationUpdates() {
        self.locationManager?.stopUpdatingLocation()
        self.locationManager?.stopMonitoringSignificantLocationChanges()
        self.isLocationUpdating = false
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && WgramSettings.keepAliveInBackground {
            self.startLocationUpdates()
        }
    }
    
    @available(iOS 14.0, *)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && WgramSettings.keepAliveInBackground {
            self.startLocationUpdates()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Keeps background runloop and network active
        if WgramSettings.keepAliveInBackground {
            if self.audioPlayer == nil || !(self.audioPlayer?.isPlaying ?? false) {
                self.tryResumeAudio()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Process is kept awake by iOS even if location is unavailable
    }
    
    // MARK: - Stop
    public func stop() {
        self.keepAliveStartTime = nil
        self.stopTaskRenewalTimer()
        self.audioPlayer?.stop()
        self.audioPlayer = nil
        self.stopLocationUpdates()
        if self.backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
    }
    
    // MARK: - Immediate Verification Helper
    public static func scheduleTestNotification(delaySeconds: Double = 10.0, completion: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "⚡ Wgram Keep-Alive"
        content.body = "Фоновая служба активна! Соединение с Telegram поддерживается без задержек."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "0.m4a"))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        let request = UNNotificationRequest(identifier: "wgram_test_keepalive_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
