//
//  Recipe.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import Foundation
import SwiftUI

struct RecipeCategory: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
}

struct RecipeSection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String?
    var ingredients: [Ingredient] = [Ingredient(name: "", amount: 1, unit: "")]
    var instructions: [InstructionLine] = [InstructionLine(text: "")]
    
    static func == (lhs: RecipeSection, rhs: RecipeSection) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.ingredients == rhs.ingredients &&
        lhs.instructions == rhs.instructions
    }
}

struct InstructionLine: Identifiable, Hashable, Codable {
    var id = UUID()
    var text: String
}

enum RecipeDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
            case .easy: return "difficulty.easy"
            case .intermediate: return "difficulty.intermediate"
            case .advanced: return "difficulty.advanced"
        }
    }
}

struct Ingredient: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String
    
    init(id: UUID = UUID(), name: String = "", amount: Double = 1, unit: String = "") {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try? container.decode(String.self, forKey: .id)
        
        if let idString = idString, let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.unit = try container.decode(String.self, forKey: .unit)
    }
}

struct Recipe: Identifiable, Equatable, Hashable, Codable {
    var id = UUID()
    var name: String
    var categories: [RecipeCategory]
    var recipeDescription: String
    var defaultPortions: Int
    var cookingTimeMinutes: Int
    var difficulty: RecipeDifficulty
    var isFavorite: Bool
    var imageFileName: String?
    var tips: String?
    
    // This is now the ONLY source of truth for ingredients and instructions
    var sections: [RecipeSection]

    var imageData: Data? {
        guard let imageFileName else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(imageFileName)
        return try? Data(contentsOf: url)
    }

    init(id: UUID = UUID(), name: String, categories: [RecipeCategory], recipeDescription: String, defaultPortions: Int, cookingTimeMinutes: Int, difficulty: RecipeDifficulty, isFavorite: Bool, imageFileName: String? = nil, tips: String? = nil, sections: [RecipeSection]) {
        self.id = id
        self.name = name
        self.categories = categories
        self.recipeDescription = recipeDescription
        self.defaultPortions = defaultPortions
        self.cookingTimeMinutes = cookingTimeMinutes
        self.difficulty = difficulty
        self.isFavorite = isFavorite
        self.imageFileName = imageFileName
        self.tips = tips // <-- Assigned tips parameter
        self.sections = sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        categories = try container.decode([RecipeCategory].self, forKey: .categories)
        recipeDescription = try container.decode(String.self, forKey: .recipeDescription)
        defaultPortions = try container.decode(Int.self, forKey: .defaultPortions)
        cookingTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .cookingTimeMinutes) ?? 0
        difficulty = try container.decodeIfPresent(RecipeDifficulty.self, forKey: .difficulty) ?? .easy
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        sections = try container.decode([RecipeSection].self, forKey: .sections)
        
        // Decodes the optional field. If it doesn't exist in older app saves, it falls back gracefully to nil.
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
        
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }
}

struct RecipeLink: Identifiable, Codable {
    let id: UUID
    let displayWord: String
    let targetRecipeID: UUID
}


