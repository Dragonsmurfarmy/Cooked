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
        
        // ZStack allows us to layer the error banner OVER the NavigationStack
        ZStack(alignment: .top) {
            NavigationStack {
                List {
                    ForEach(viewModel.availableSounds) { sound in
                        Button {
                            viewModel.setCustomSound(url: sound.url)
                            playPreview(sound.url)
                        } label: {
                            HStack {
                                Text(sound.url.deletingPathExtension().lastPathComponent)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedSoundUrl == sound.url {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        // Visual hint: Disable delete for bundle sounds
                        .deleteDisabled(!sound.url.path.contains("/Documents/"))
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

                }
            }
            
            
        }
        // This makes the transition smooth
        .animation(.snappy, value: viewModel.errorMessage)
        .onAppear {
            viewModel.refreshAvailableSounds()
        }
    }

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
