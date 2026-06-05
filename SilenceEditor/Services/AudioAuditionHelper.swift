import Foundation
import AVFoundation

/// Manages AVPlayer boundary monitoring to audition silence regions in their vocal contexts.
/// Runs entirely on the `@MainActor` to safely coordinate playback controls.
@MainActor
public final class AudioAuditionHelper {
    private var timeObserverToken: Any?
    
    public init() {}
    
    /// Auditions the context around a given silence region (2 seconds before and 2 seconds after).
    /// - Parameters:
    ///   - silence: The target silence region.
    ///   - player: The active media player reference.
    ///   - videoDuration: Total duration of the active asset.
    public func audition(silence: SilenceRegion, in player: AVPlayer, videoDuration: Double) {
        // Clear any previous time observation tokens
        removeActiveObserver(from: player)
        
        let auditionStart = max(0.0, silence.start - 2.0)
        let auditionEnd = min(videoDuration, silence.end + 2.0)
        
        let startTime = CMTime(seconds: auditionStart, preferredTimescale: 60000)
        let endTime = CMTime(seconds: auditionEnd, preferredTimescale: 60000)
        
        player.pause()
        
        // Seek to the start boundary of the audition segment
        player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] finished in
            Task { @MainActor in
                guard finished, let self = self, let player = player else { return }
                
                let nsEndTime = NSValue(time: endTime)
                
                // Set up boundary observer to trigger exactly at the end of the context segment
                self.timeObserverToken = player.addBoundaryTimeObserver(forTimes: [nsEndTime], queue: .main) { [weak self, weak player] in
                    Task { @MainActor in
                        player?.pause()
                        if let self, let player = player {
                            self.removeActiveObserver(from: player)
                        }
                    }
                }
                
                player.play()
            }
        }
    }
    
    /// Disconnects any active boundary time observers from the player.
    public func removeActiveObserver(from player: AVPlayer) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
