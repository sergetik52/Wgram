import Foundation
import AVFoundation
import TelegramCore

public final class WgramKeepAlive {
    public static let shared = WgramKeepAlive()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateState), name: NSNotification.Name("WgramUpdateKeepAlive"), object: nil)
    }
    
    @objc public func updateState() {
        if WgramSettings.keepAliveInBackground {
            self.start()
        } else {
            self.stop()
        }
    }
    
    public func start() {
        guard self.audioPlayer == nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
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
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } catch {
            print("WgramKeepAlive error: \(error)")
        }
    }
    
    public func stop() {
        self.audioPlayer?.stop()
        self.audioPlayer = nil
    }
}
