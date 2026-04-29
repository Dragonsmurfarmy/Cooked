//
//  RecipeStore.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//
import Foundation
import Observation
import SwiftUI

@Observable class RecipeStore {
    var recipes: [Recipe] = []
    var categories: [RecipeCategory] = [
        RecipeCategory(name: "Breakfast"),
        RecipeCategory(name: "Lunch"),
        RecipeCategory(name: "Dinner")
    ]
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    init() {
        copyBundleRecipesIfNeeded()
        loadRecipesFromDisk()
    }
    
    private func copyBundleRecipesIfNeeded() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore_v1")
        
        if !hasLaunchedBefore {
            print("Copying bult-in JSON files")
            
            let bundleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
            
            if bundleJSONs.isEmpty {
                print("No JSON files found in App")
            }
            
            for fileURL in bundleJSONs {
                let destURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
                
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.copyItem(at: fileURL, to: destURL)
                    print("✅ Copied: \(fileURL.lastPathComponent)")
                }
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore_v3")
        }
    }
    
    func loadRecipesFromDisk() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) else { return }
        
        let decoder = JSONDecoder()
        self.recipes = fileURLs.filter { $0.pathExtension == "json" }.compactMap { url in
            try? decoder.decode(Recipe.self, from: Data(contentsOf: url))
        }
    }
    
    func saveRecipe(_ recipe: Recipe, newImageData: Data?) {
        var recipeToSave = recipe
        
        // Save Image if it exists
        if let data = newImageData {
            let imageName = "\(recipe.id.uuidString).jpg"
            try? data.write(to: documentsDirectory.appendingPathComponent(imageName))
            recipeToSave.imageFileName = imageName
        }
        
        // Save JSON
        if let data = try? JSONEncoder().encode(recipeToSave) {
            let fileURL = documentsDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
            try? data.write(to: fileURL)
        }
        
        // Update local array for UI
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipeToSave
        } else {
            recipes.append(recipeToSave)
        }
    }
    
    func deleteRecipe(at offsets: IndexSet) {
        offsets.map { recipes[$0] }.forEach { recipe in
            let jsonURL = documentsDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
            try? FileManager.default.removeItem(at: jsonURL)
            if let imgName = recipe.imageFileName {
                try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(imgName))
            }
        }
        recipes.remove(atOffsets: offsets)
    }

    func addCategory(_ name: String) -> RecipeCategory {
        let new = RecipeCategory(name: name)
        categories.append(new)
        return new
    }
    
    
}
