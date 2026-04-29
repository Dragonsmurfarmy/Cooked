//
//  SoundPickerView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

import SwiftUI
import AVFoundation

struct SoundPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TimerViewModel

    @State private var sounds: [TimerSoundFile] = []
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            List {
                ForEach(sounds) { sound in
                    Button {
                        viewModel.setCustomSound(url: sound.url)
                        playPreview(sound.url)
                    } label: {
                        HStack {
                            Text(sound.displayName)
                            Spacer()

                            if viewModel.selectedSoundUrl == sound.url {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Sound")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                let loaded = SoundLoader.loadSounds()
                sounds = loaded
                viewModel.availableSounds = loaded
            }
        }
    }

    private func playPreview(_ url: URL) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
