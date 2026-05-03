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
    
    func saveRecipe(_ recipe: Recipe, newImageData: Data?) -> Recipe {
        var recipeToSave = recipe
        
        // 1. Uložíme obrázek a aktualizujeme jméno v objektu
        if let data = newImageData {
            let imageName = "\(recipeToSave.id.uuidString).jpg"
            let destURL = documentsDirectory.appendingPathComponent(imageName)
            try? data.write(to: destURL)
            recipeToSave.imageFileName = imageName
            print("Store: Obrázek uložen jako \(imageName)")
        }
        
        // 2. Uložíme JSON
        if let data = try? JSONEncoder().encode(recipeToSave) {
            let fileURL = documentsDirectory.appendingPathComponent("\(recipeToSave.id.uuidString).json")
            try? data.write(to: fileURL)
        }
        
        // 3. Aktualizujeme pole v paměti
        if let index = recipes.firstIndex(where: { $0.id == recipeToSave.id }) {
            recipes[index] = recipeToSave
        } else {
            recipes.append(recipeToSave)
        }
        
        return recipeToSave
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
