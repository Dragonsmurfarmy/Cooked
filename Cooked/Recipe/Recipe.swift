//
//  Recipe.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//
import Foundation

struct RecipeCategory: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
}

struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: RecipeCategory
    var recipeDescription: String
    var ingredients: String
    var instructions: String
    var isFavorite: Bool
    var imageFileName: String? // Store just the name of the file

    // Computed property to load the image from the disk only when needed
    var imageData: Data? {
        guard let filename = imageFileName else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    init(id: UUID = UUID(), name: String, category: RecipeCategory, recipeDescription: String, ingredients: String = "", instructions: String, isFavorite: Bool, imageFileName: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.recipeDescription = recipeDescription
        self.ingredients = ingredients
        self.instructions = instructions
        self.isFavorite = isFavorite
        self.imageFileName = imageFileName
    }
}
