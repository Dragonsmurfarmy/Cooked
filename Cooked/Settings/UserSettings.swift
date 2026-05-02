//
//  UserSettings.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

struct UserSettings: Codable {
    var defaultPortions: Int = 1
    var hasLaunchedBefore: Bool = false
    var language: AppLanguage = .english
    var selectedAlarmSound: String = "Default"
    var categories: [RecipeCategory] = [
        RecipeCategory(name: "category.breakfast"),
        RecipeCategory(name: "category.lunch"),
        RecipeCategory(name: "category.dinner")
    ]
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case czech = "cs"
    var id: String { rawValue }
    
    var displayName: String {
            switch self {
            case .english: return "English"
            case .czech: return "Čeština"
            }
        }
}
