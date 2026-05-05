//
//  RecipeStore.swift
//  Cooked
//
//  Created by Tomáš Kříž on 22.04.2026.
//
import Foundation
import Observation
import SwiftUI

@Observable class RecipeStore {
    var recipes: [Recipe] = []
    var settings: UserSettings = UserSettings()
    var categories: [RecipeCategory] {
            get { settings.categories }
            set { settings.categories = newValue }
        }
    var currentLanguageIdentifier: String {
            settings.language.rawValue
        }
    
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    init() {
        loadSettings()
        copyBundleRecipes()
        loadRecipesFromDisk()
    }
    
    // On first launch, copy bundled recipes into Documents so the app can manage
    // sample and user-created recipes through the same storage flow.
    private func copyBundleRecipes() {
        let launchKey = "hasLaunchedBefore"
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: launchKey)
        
        guard !hasLaunchedBefore else {
            return
        }
        
        let bundleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        
        // Load all premade recipes
        for fileURL in bundleJSONs {
            let destURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
            
            try? FileManager.default.copyItem(at: fileURL, to: destURL)
        }
        
        UserDefaults.standard.set(true, forKey: launchKey)
    }
    
    // Load every recipe JSON file currently stored in Documents.
    func loadRecipesFromDisk() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) else { return }
        
        let decoder = JSONDecoder()
        var loadedRecipes: [Recipe] = []
        
        for url in fileURLs where url.pathExtension == "json" {
            // Ignore settings file
            if url.lastPathComponent == "user_settings_data" { continue }
            
            do {
                let data = try Data(contentsOf: url)
                let recipe = try decoder.decode(Recipe.self, from: data)
                loadedRecipes.append(recipe)
            } catch {
                print("Error decoding JSON: \(url.lastPathComponent): \(error)")
            }
        }
        
        // Replace in-memory recipes with the on-disk version.
        self.recipes = loadedRecipes
        
    }
    
    func saveRecipe(_ recipe: Recipe, newImageData: Data?) -> Recipe {
        var recipeToSave = recipe
        
        // Save the selected image separately and keep only its filename in the recipe JSON.
        if let data = newImageData {
            let imageName = "\(recipeToSave.id.uuidString).jpg"
            let destURL = documentsDirectory.appendingPathComponent(imageName)
            try? data.write(to: destURL)
            recipeToSave.imageFileName = imageName
        }
        
        // Save the recipe metadata as JSON.
        if let data = try? JSONEncoder().encode(recipeToSave) {
            let fileURL = documentsDirectory.appendingPathComponent("\(recipeToSave.id.uuidString).json")
            try? data.write(to: fileURL)
        }
        
        // Keep in-memory state synchronized with what was written to disk.
        if let index = recipes.firstIndex(where: { $0.id == recipeToSave.id }) {
            recipes[index] = recipeToSave
        } else {
            recipes.append(recipeToSave)
        }
        
        return recipeToSave
    }
    
    func deleteRecipe(at offsets: IndexSet) {
            // Remove JSON
            offsets.map { recipes[$0] }.forEach { recipe in
                let jsonURL = documentsDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
                try? FileManager.default.removeItem(at: jsonURL)
                
                // Remove image
                if let imgName = recipe.imageFileName {
                    let imgURL = documentsDirectory.appendingPathComponent(imgName)
                    try? FileManager.default.removeItem(at: imgURL)
                }
            }
        // Remove recipe from array of recipes
            recipes.remove(atOffsets: offsets)
        }
    
    // Persist user settings in UserDefaults.
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "user_settings_data")
        }
    }
        
    // Restore previously saved settings if they exist.
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "user_settings_data"),
            let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
                self.settings = decoded
        }
    }

    // Create a new custom category and immediately persist the updated settings.
    func addCategory(_ name: String) -> RecipeCategory {
            let new = RecipeCategory(name: name)
            settings.categories.append(new)
            saveSettings()
            return new
        }
    
    
}
