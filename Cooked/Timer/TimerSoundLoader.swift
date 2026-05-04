//
//  TimerSoundLoader.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

import Foundation

struct TimerSoundFile: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
    var displayName: String {
        url.deletingPathExtension()
            .lastPathComponent
            // Format the name of the file so it doesnt look as unnatural to the user
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct SoundLoader {
    static func loadSounds() -> [TimerSoundFile] {
        let exts = ["caf", "mp3", "wav", "aiff", "m4a"]
        
        // Create single array with all sound files present
        return exts.flatMap { ext in
            Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }
        .map { TimerSoundFile(url: $0) }
       }
}
