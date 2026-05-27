//
//  RecipeDraft.swift
//  Cooked
//
//  Created by Tomáš Kříž on 14.05.2026.
//

import SwiftUI

struct RecipeDraft: Codable, Equatable {
    var name = ""
    var recipeDescription = ""
    var categoryID: UUID?
    var sections: [RecipeSection] = [RecipeSection()] 
    var defaultPortions = 1
    var cookingTimeMinutes = 0
    var difficulty: RecipeDifficulty = .easy
    var imageFileName: String?
    var tips: String?
}

