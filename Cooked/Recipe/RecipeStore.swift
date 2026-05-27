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
    var availableUnits: [String] = [
        "g",
        "kg",
        "ml",
        "l",
        "unit.pcs"
    ]
    
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
    
    var draftRecipe = RecipeDraft() {
        didSet {
            saveDraft()
        }
    }
    
    init() {
        copyBundleRecipes()
        
        loadSettings()
        loadUnits()
        
        loadRecipesFromDisk()
        loadDraft()
    }
    
    // On first launch, copy bundled recipes into Documents so app can manage sample and user-created recipes through same storage flow
    private func copyBundleRecipes() {
        
        let launchKey = "hasLaunchedBefore"
        // Commented out to ensure it processes every launch until we fix it
        // if UserDefaults.standard.bool(forKey: launchKey) { return }
        
        let decoder = JSONDecoder()
        let bundleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        
        for fileURL in bundleJSONs {
            
            guard let data = try? Data(contentsOf: fileURL) else {
                continue
            }
            
            var decodedRecipe: Recipe? = nil
            
            
            do {
                decodedRecipe = try decoder.decode(Recipe.self, from: data)
            } catch let singleError {
                
                do {
                    let recipeArray = try decoder.decode([Recipe].self, from: data)
                    decodedRecipe = recipeArray.first
                } catch let arrayError {
                    
                }
            }
            
            
            if let recipe = decodedRecipe {
                let destURL = documentsDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
                
                
                if let cleanData = try? JSONEncoder().encode(recipe) {
                    do {
                        try cleanData.write(to: destURL)
                        
                    } catch {
                        
                    }
                }
            }
        }
        
        UserDefaults.standard.set(true, forKey: launchKey)
    }
    
    // Load every recipe JSON file currently stored in Documents
    func loadRecipesFromDisk() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) else { return }
        
        let decoder = JSONDecoder()
        var loadedRecipes: [Recipe] = []
        
        for url in fileURLs where url.pathExtension == "json" {
            
            // Ignore settings and draft files
            if url.lastPathComponent == "user_settings_data" { continue }
            if url.lastPathComponent == "RecipeDraft.json" { continue }
            
            do {
                let data = try Data(contentsOf: url)
                let recipe = try decoder.decode(Recipe.self, from: data)
                loadedRecipes.append(recipe)
            } catch {
                print("Error decoding JSON: \(url.lastPathComponent): \(error)")
            }
        }
        
        // Replace in-memory recipes with the on-disk version
        self.recipes = loadedRecipes
        
    }
    
    func saveRecipe(_ recipe: Recipe, newImageData: Data?) -> Recipe {
        var recipeToSave = recipe
        
        // Save the selected image separately and keep only its filename in the recipe JSON
        if let data = newImageData {
            let imageName = "\(recipeToSave.id.uuidString).jpg"
            let destURL = documentsDirectory.appendingPathComponent(imageName)
            try? data.write(to: destURL)
            recipeToSave.imageFileName = imageName
        }
        
        // Save the recipe metadata as JSON
        if let data = try? JSONEncoder().encode(recipeToSave) {
            let fileURL = documentsDirectory.appendingPathComponent("\(recipeToSave.id.uuidString).json")
            try? data.write(to: fileURL)
        }
        
        // Keep in-memory state synchronized with what was written to disk
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
    
    // Persist user settings in UserDefaults
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "user_settings_data")
        }
    }
        
    // Restore previously saved settings if they exist
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "user_settings_data"),
            let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
                self.settings = decoded
        }
    }

    // Create a new custom category and immediately persist the updated settings
    func addCategory(_ name: String) -> RecipeCategory {
        let new = RecipeCategory(name: name)
        settings.categories.append(new)
        saveSettings()
        return new
    }
    
    // loads Built-in and user-defined units
    func loadUnits() {
        
        if let savedUnits = UserDefaults.standard.stringArray(forKey: "saved_recipe_units") {
            self.availableUnits = savedUnits
        }
    }
    
    func addUnit(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Prevent duplicate units from entering the array
        guard !availableUnits.contains(where: { $0.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            return
        }
            
        // Append to the active array tracking the state
        availableUnits.append(trimmedName)
            
        // Persist the updated array to UserDefaults
        UserDefaults.standard.set(availableUnits, forKey: "saved_recipe_units")
    }
    
    func removeUnit(_ unit: String) {
        // Remove all strings that match given unit
        availableUnits.removeAll { $0 == unit }
        
        // Synchronize
        UserDefaults.standard.set(availableUnits, forKey: "saved_recipe_units")
    }
    
    
    // ------ Draft operations ----------
    
    private var draftURL: URL {
        documentsDirectory.appendingPathComponent("RecipeDraft.json")
    }

    func saveDraft() {
        guard let data = try? JSONEncoder().encode(draftRecipe) else { return }
        try? data.write(to: draftURL)
    }

    func loadDraft() {
        guard let data = try? Data(contentsOf: draftURL),
              let draft = try? JSONDecoder().decode(RecipeDraft.self, from: data) else {
            return
        }

        draftRecipe = draft
    }

    func saveDraftImageData(_ data: Data?) {
        guard let data else {
            if let imageFileName = draftRecipe.imageFileName {
                let imageURL = documentsDirectory.appendingPathComponent(imageFileName)
                try? FileManager.default.removeItem(at: imageURL)
            }
            draftRecipe.imageFileName = nil
            return
        }

        let imageFileName = "RecipeDraftImage.jpg"
        let imageURL = documentsDirectory.appendingPathComponent(imageFileName)
        try? data.write(to: imageURL)
        draftRecipe.imageFileName = imageFileName
    }

    func loadDraftImageData() -> Data? {
        guard let imageFileName = draftRecipe.imageFileName else { return nil }
        let imageURL = documentsDirectory.appendingPathComponent(imageFileName)
        return try? Data(contentsOf: imageURL)
    }

    func clearDraft() {
        saveDraftImageData(nil)
        draftRecipe = RecipeDraft()
    }
    
}
