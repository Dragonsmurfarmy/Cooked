//
//  RecipeDraft.swift
//  Cooked
//
//  Created by Tomáš Kříž on 14.05.2026.
//

import SwiftUI

struct RecipeDraft: Codable {
    var name = ""
    var recipeDescription = ""
    var categoryID: UUID?
    var ingredients: [Ingredient] = []
    var defaultPortions = 1
    var instructions = ""
    var imageFileName: String?
}


