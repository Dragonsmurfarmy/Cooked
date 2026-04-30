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
    let viewModel: TimerViewModel // Necháme let, bindable vytvoříme v body

    @State private var player: AVAudioPlayer?

    var body: some View {
        // Tímto vyřešíme chybu "Referencing subscript"
        @Bindable var viewModel = viewModel
        
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
                }
                // Voláme metodu přímo na viewModelu
                .onDelete { offsets in
                    viewModel.deleteSound(at: offsets)
                }
            }
            .navigationTitle("Choose Sound")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton() // Umožní pohodlné mazání
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                viewModel.refreshAvailableSounds()
            }
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
