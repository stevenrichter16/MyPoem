import SwiftUI
import AVFoundation
import Observation

@Observable
@MainActor
class PoemAudioPlayer {
    // MARK: - Observable Properties
    var isPlaying = false
    var playbackProgress: Double = 0
    var isDraggingScrubber = false
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // MARK: - Playback Functions
    func playRecording(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AVAudioPlayerDelegateWrapper { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                    self?.playbackProgress = 0
                    self?.playbackTimer?.invalidate()
                    self?.playbackTimer = nil
                }
            }
            audioPlayer?.play()
            isPlaying = true
            playbackProgress = 0
            
            // Start timer to update progress with higher frequency for smooth animation
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                if !self.isDraggingScrubber, let player = self.audioPlayer, player.duration > 0 {
                    withAnimation(.linear(duration: 0.03)) {
                        self.playbackProgress = player.currentTime / player.duration
                    }
                }
            }
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func seekAudio(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let newTime = player.currentTime + seconds
        let clampedTime = min(max(0, newTime), player.duration)
        player.currentTime = clampedTime
        
        // Update progress immediately
        if player.duration > 0 {
            playbackProgress = clampedTime / player.duration
        }
    }
    
    func scrubToPosition(_ progress: Double) {
        guard let player = audioPlayer else { return }
        
        let newTime = player.duration * progress
        player.currentTime = newTime
        // Don't update playbackProgress here - let the timer do it or it's already set by drag
    }
    
    // MARK: - Helper Functions
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func cleanup() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
