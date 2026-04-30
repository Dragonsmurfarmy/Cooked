//
//  Receipe.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: RecipeStore
    @Environment(TimerViewModel.self) private var timerViewModel
    @State private var showingSoundPicker = false
    
    @State private var showNewCategoryAlert = false
    @State private var showingSoundImporter = false
    @State private var showingImporter = false
    @State private var newCategoryName = ""
  
    
    var body: some View {
            Form {
                // --- JAZYK ---
                Section("General") {
                    Picker("Language", selection: $store.settings.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .onChange(of: store.settings.language) { store.saveSettings() }
                }
                HStack {
                        Text("Default Portions")
                        Spacer()
                        Stepper("\(store.settings.defaultPortions)", value: $store.settings.defaultPortions, in: 1...50)
                            .onChange(of: store.settings.defaultPortions) {
                                store.saveSettings()
                            }
                    }
                
                // --- BUDÍK ---
                Section("Timer & Sounds") {
                    Button {
                        showingSoundPicker = true
                    } label: {
                        HStack {
                            Text("Alarm Sound")
                            Spacer()
                            Text(timerViewModel.selectedSoundUrl?.lastPathComponent ?? "Default")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Tlačítko pro přidání zvuku
                    Button {
                        showingSoundImporter = true
                    } label: {
                        Label("Add Custom Sound", systemImage: "music.note.list")
                    }
                }
                
                // --- KATEGORIE ---
                Section("Manage Categories") {
                    ForEach(store.categories) { category in
                        Text(category.name)
                    }
                    .onDelete(perform: deleteCategory)
                    
                    Button {
                        showNewCategoryAlert = true
                    } label: {
                        Label("Add New Category", systemImage: "plus")
                    }
                }
                
                // --- DATA ---
                Section("Data Management") {
                    Button(action: exportRecipes) {
                        Label("Export Recipes (JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Recipes (JSON)", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("Settings")
            // --- VŠECHNY MODIFIKÁTORY NA KONCI (MIMO FORM) ---
            .alert("New Category", isPresented: $showNewCategoryAlert) {
                TextField("Category name", text: $newCategoryName)
                Button("Add") {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    _ = store.addCategory(trimmed)
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) { newCategoryName = "" }
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(viewModel: timerViewModel)
            }
            // Importer pro RECEPTY
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            // Importer pro ZVUKY (přesunut sem, aby fungoval)
            .fileImporter(
                isPresented: $showingSoundImporter,
                allowedContentTypes: [.mp3, .wav, .mpeg4Audio],
                allowsMultipleSelection: false
            ) { result in
                handleSoundImport(result: result)
            }
        }
    
    // --- POMOCNÉ FUNKCE ---
    
    private func deleteCategory(at offsets: IndexSet) {
        store.categories.remove(atOffsets: offsets)
        store.saveSettings()
    }
    
    private func exportRecipes() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(store.recipes) else { return }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CookedBackup.json")
        try? data.write(to: tempURL)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
            }
            rootVC.present(activityVC, animated: true)
        }
    }
    
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url),
               let importedRecipes = try? JSONDecoder().decode([Recipe].self, from: data) {
                for recipe in importedRecipes {
                    store.saveRecipe(recipe, newImageData: nil)
                }
                store.loadRecipesFromDisk()
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func handleSoundImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                print("❌ Žádný soubor nebyl vybrán")
                return
            }
            
            print("📁 Vybrán soubor: \(url.lastPathComponent)")
            
            // Cesta do Documents
            let destURL = store.documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            // Start Accessing Security Scoped Resource je u FilePickeru KLÍČOVÉ
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    // Pokud soubor už existuje, smažeme ho
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                        print("🗑️ Starý soubor smazán")
                    }
                    
                    // Kopírování dat
                    let data = try Data(contentsOf: url)
                    try data.write(to: destURL)
                    print("✅ Soubor úspěšně zkopírován do: \(destURL.lastPathComponent)")
                    
                    // Aktualizace seznamu
                    timerViewModel.refreshAvailableSounds()
                    print("🎶 Seznam zvuků v TimerViewModelu aktualizován")
                    
                } catch {
                    print("❌ Chyba při ukládání souboru: \(error.localizedDescription)")
                }
            } else {
                print("❌ Systém zamítl přístup k vybranému souboru (Security Scope)")
            }
            
        case .failure(let error):
            print("❌ Import selhal: \(error.localizedDescription)")
        }
    }
}
