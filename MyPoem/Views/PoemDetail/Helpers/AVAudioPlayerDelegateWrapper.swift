import AVFoundation

// Helper class for AVAudioPlayerDelegate
class AVAudioPlayerDelegateWrapper: NSObject, AVAudioPlayerDelegate {
    let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
}