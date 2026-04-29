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
            }
            Button {
                showingSoundImporter = true
            } label: {
                Label("Add Custom Sound", systemImage: "music.note.list")
            }
            .fileImporter(
                isPresented: $showingSoundImporter,
                allowedContentTypes: [.mp3, .wav, .mpeg4Audio], // Povolíme audio formáty
                allowsMultipleSelection: false
            ) { result in
                handleSoundImport(result: result)
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
        // Všechny modifikátory (popupy) pohromadě na konci
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
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
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
            guard let url = urls.first else { return }
            
            // Cesta, kam zvuk uložíš (do tvé složky Documents)
            let destURL = store.documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            // Musíš mít přístup k souboru
            if url.startAccessingSecurityScopedResource() {
                try? FileManager.default.copyItem(at: url, to: destURL)
                url.stopAccessingSecurityScopedResource()
                
                // Tady bys mohl informovat TimerViewModel, že má nový zvuk
                timerViewModel.refreshAvailableSounds()
            }
        case .failure(let error):
            print(error)
        }
    }
}
