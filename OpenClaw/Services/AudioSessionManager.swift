//
//  AudioSessionManager.swift
//  OpenClaw
//
//  Configures AVAudioSession for voice conversations
//

import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private init() {}
    
    func configureForVoiceChat() throws {
        let session = AVAudioSession.sharedInstance()
        
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )
        
        try session.setActive(true)
        
        // Force output to speaker
        try session.overrideOutputAudioPort(.speaker)
    }
    
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
