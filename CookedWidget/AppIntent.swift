//
//  AppIntent.swift
//  CookedWidget
//
//  Created by Tomáš Kříž on 23.04.2026.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
