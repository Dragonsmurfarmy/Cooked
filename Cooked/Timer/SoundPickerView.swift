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

    @State private var player: AVAudioPlayer?

    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            // --- AVAILABLE SOUNDS SECTION ---
            List {
                ForEach(viewModel.availableSounds) { sound in
                    Button {
                        viewModel.setCustomSound(url: sound.url)
                        playPreview(sound.url) // Play the sound when user selects it
                    } label: {
                        HStack {
                            Text(sound.url.deletingPathExtension().lastPathComponent)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            // Show checkmark by selected sound
                            if viewModel.selectedSoundUrl == sound.url {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteSound(at: offsets)
                }
            }
            .navigationTitle("sound.choose")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") { dismiss() }
                }
            }
            .onAppear {
                viewModel.refreshAvailableSounds()
            }
        }
    }

    // Plays selected sound preview
    private func playPreview(_ url: URL) {
        player?.stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Preview failed: \(error)")
        }
    }
}
