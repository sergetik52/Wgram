import Foundation
import UIKit
import AVFoundation
import UserNotifications
import TelegramCore

public final class WgramKeepAlive: NSObject, AVAudioPlayerDelegate {
    public static let shared = WgramKeepAlive()
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: NSNotification.Name("WgramUpdateKeepAlive"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: NSNotification.Name("WgramKeepAliveChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: WgramSettings.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    public func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("WgramKeepAlive: notification authorization error: \(error)")
            }
        }
    }
    
    @objc public func handleEnterForeground() {
        if self.backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
        self.updateState()
    }
    
    @objc public func handleEnterBackground() {
        if WgramSettings.keepAliveInBackground {
            self.start()
            if self.backgroundTaskId == .invalid {
                self.backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "WgramKeepAlive") { [weak self] in
                    if let self = self, self.backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                        self.backgroundTaskId = .invalid
                    }
                }
            }
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && WgramSettings.keepAliveInBackground {
                    self.audioPlayer?.play()
                }
            }
        }
    }
    
    @objc public func updateState() {
        if WgramSettings.keepAliveInBackground {
            self.requestNotificationPermissionIfNeeded()
            self.start()
        } else {
            self.stop()
        }
    }
    
    public func start() {
        if let player = self.audioPlayer {
            if !player.isPlaying {
                player.play()
            }
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let sampleRate: Double = 44100.0
            let duration: Double = 1.0
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
            audioData.append(Data(count: Int(subChunk2Size)))
            
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            player.numberOfLoops = -1
            player.volume = 0.0001
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } catch {
            print("WgramKeepAlive error: \(error)")
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if WgramSettings.keepAliveInBackground {
            player.play()
        }
    }
    
    public func stop() {
        self.audioPlayer?.stop()
        self.audioPlayer = nil
        if self.backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
    }
}
