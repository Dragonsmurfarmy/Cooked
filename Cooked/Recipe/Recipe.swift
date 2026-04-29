//
//  Recipe.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//
import Foundation

struct Recipe: Identifiable {
    let id: UUID
    var name: String
    var category: RecipeCategory
    var recipeDescription: String
    var ingredients: String
    var instructions: String
    var isFavorite: Bool
    var imageData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        category: RecipeCategory,
        recipeDescription: String,
        ingredients: String = "",
        instructions: String,
        isFavorite: Bool,
        imageData: Data? = nil
 
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.recipeDescription = recipeDescription
        self.ingredients = ingredients
        self.instructions = instructions
        self.isFavorite = isFavorite
        self.imageData = imageData

    }
}
