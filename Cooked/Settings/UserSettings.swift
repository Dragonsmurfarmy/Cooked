//
//  UserSettings.swift
//  Cooked
//
//  Created by Tomáš Kříž on 22.04.2026.
//
import Foundation

struct UserSettings: Codable {
    var defaultPortions: Int = 1
    var hasLaunchedBefore: Bool = false
    var language: AppLanguage = .english
    var selectedAlarmSound: String = "Default"
    var categories: [RecipeCategory] = [ // List of built-in categories
            RecipeCategory(id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!, name: "category.breakfast"),
            RecipeCategory(id: UUID(uuidString: "661f9500-f30c-52e5-b827-557766551111")!, name: "category.lunch"),
            RecipeCategory(id: UUID(uuidString: "772a1234-a123-b123-c123-998877665544")!, name: "category.dinner"),
            RecipeCategory(id: UUID(uuidString: "883b5678-b456-c456-d456-112233445566")!, name: "category.dessert")
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
