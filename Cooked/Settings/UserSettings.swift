//
//  UserSettings.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

struct UserSettings: Codable {
    var hasLaunchedBefore: Bool = false
    var language: AppLanguage = .english
    var selectedAlarmSound: String = "Default"
    var categories: [RecipeCategory] = [
        RecipeCategory(name: "Breakfast"),
        RecipeCategory(name: "Lunch"),
        RecipeCategory(name: "Dinner")
    ]
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "English"
    case czech = "Čeština"
    var id: String { rawValue }
}
