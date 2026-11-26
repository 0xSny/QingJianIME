import AVFAudio
import UIKit

final class KeyClick {
    private var players = [AVAudioPlayer]()
    private var next = 0
    func prepare() {
        guard players.isEmpty, let url=Bundle.main.url(forResource:"tap",withExtension:"wav") else{return}
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode:.default, options:[.mixWithOthers])
            for _ in 0..<3 {
                let player=try AVAudioPlayer(contentsOf:url)
                player.prepareToPlay();players.append(player)
            }
        } catch {players.removeAll()}
    }
    func play(volume:Double) {
        guard volume>0 else{return}
        guard !players.isEmpty else{UIDevice.current.playInputClick();return}
        let p=players[next];next=(next+1)%players.count;p.volume=Float(volume);p.currentTime=0;p.play()
    }
}
