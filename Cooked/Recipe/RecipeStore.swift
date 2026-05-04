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
    
    // If App launches for 1st time
    // Copies premade recipes from Recipe_bundle into the app
    private func copyBundleRecipes() {
        let launchKey = "hasLaunchedBefore"
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: launchKey)
        
        // TBD if app launches for 1st time, show some tutorial app usage window
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
    
    // Load all recipes that exist in the app
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
        
        // Give recipes to main recipes variable
        self.recipes = loadedRecipes
        
    }
    
    func saveRecipe(_ recipe: Recipe, newImageData: Data?) -> Recipe {
        var recipeToSave = recipe
        
        // Save new image name and path to the image
        if let data = newImageData {
            let imageName = "\(recipeToSave.id.uuidString).jpg"
            let destURL = documentsDirectory.appendingPathComponent(imageName)
            try? data.write(to: destURL)
            recipeToSave.imageFileName = imageName
        }
        
        // Save JSON
        if let data = try? JSONEncoder().encode(recipeToSave) {
            let fileURL = documentsDirectory.appendingPathComponent("\(recipeToSave.id.uuidString).json")
            try? data.write(to: fileURL)
        }
        
        // Update array in memory
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
    
    // Updates user settings JSON
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "user_settings_data")
        }
    }
        
    // Loads information from user settings JSON
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "user_settings_data"),
            let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
                self.settings = decoded
        }
    }

    // Creates new category and appends it to the category array
    func addCategory(_ name: String) -> RecipeCategory {
            let new = RecipeCategory(name: name)
            settings.categories.append(new)
            saveSettings()
            return new
        }
    
    
}
