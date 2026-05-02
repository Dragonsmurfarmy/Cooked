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
        copyBundleRecipesIfNeeded()
        loadRecipesFromDisk()
    }
    
    private func copyBundleRecipesIfNeeded() {
        
        let launchKey = "hasLaunchedBefore_v4"
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: launchKey)
        
        guard !hasLaunchedBefore else { return }
        
        print("First launch: Copying built-in JSON files")
        
        let bundleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        
        for fileURL in bundleJSONs {
            let destURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
            
            try? FileManager.default.copyItem(at: fileURL, to: destURL)
        }
        
        UserDefaults.standard.set(true, forKey: launchKey)
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
                    let imgURL = documentsDirectory.appendingPathComponent(imgName)
                    try? FileManager.default.removeItem(at: imgURL)
                }
            }
            recipes.remove(atOffsets: offsets)
        }
    
    func saveSettings() {
            if let encoded = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(encoded, forKey: "user_settings_data")
            }
        }
        
        private func loadSettings() {
            if let data = UserDefaults.standard.data(forKey: "user_settings_data"),
               let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
                self.settings = decoded
            }
        }

    func addCategory(_ name: String) -> RecipeCategory {
            let new = RecipeCategory(name: name)
            settings.categories.append(new)
            saveSettings()
            return new
        }
    
    
}
