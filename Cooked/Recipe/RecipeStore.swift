//
//  RecipeStore.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//
import Foundation
import Observation

@Observable class RecipeStore {
    var categories: [RecipeCategory] = [
        RecipeCategory(name: "Breakfast"),
        RecipeCategory(name: "Lunch"),
        RecipeCategory(name: "Dinner")
    ]
    
    func addCategory(_ name: String) -> RecipeCategory {
        let new = RecipeCategory(name: name)
        categories.append(new)
        return new
    }
}
