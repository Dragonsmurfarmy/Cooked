//
//  SettingsView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: RecipeStore
    @Environment(TimerViewModel.self) private var timerViewModel
    @State private var showingSoundPicker = false
    @State private var didLongPressDecrement = false
    @State private var didLongPressIncrement = false
    
    @State private var showNewCategoryAlert = false
    @State private var showingSoundImporter = false
    @State private var showingImporter = false
    @State private var newCategoryName = ""
    private let minPortions = 1
    private let maxPortions = 50
  
    
    var body: some View {
            Form {
                // --- LANGUAGE ---
                Section("settings.general") {
                    Picker("settings.language", selection: $store.settings.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .onChange(of: store.settings.language) { store.saveSettings() }
                }
                HStack {
                        Text("settings.portions")
                    
                        Text("\(store.settings.defaultPortions)")
                            .font(.title3.monospacedDigit())
                            .fontWeight(.semibold)
                            .frame(minWidth: 30)
                    
                        Spacer()
                    
                        Button {
                            handleDecrementTap()
                        } label: {
                            Image(systemName: "minus")
                                .font(.headline)
                                .frame(width: 34, height: 34)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    didLongPressDecrement = true
                                    store.settings.defaultPortions = minPortions
                                    store.saveSettings()
                                }
                        )

                        Button {
                            handleIncrementTap()
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .frame(width: 34, height: 34)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    didLongPressIncrement = true
                                    store.settings.defaultPortions = maxPortions
                                    store.saveSettings()
                                }
                        )
                    }
                
                // --- TIMER ---
                Section("settings.timer") {
                    Button {
                        showingSoundPicker = true
                    } label: {
                        HStack {
                            Text("settings.alarm.sound")
                            Spacer()
                            Text(LocalizedStringKey(timerViewModel.selectedSoundUrl?.lastPathComponent ?? "label.default"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Add sound button
                    Button {
                        showingSoundImporter = true
                    } label: {
                        Label("settings.custom.sound", systemImage: "music.note.list")
                    }
                }
                
                // --- CATEGORIES ---
                Section("settings.manage.categories") {
                    ForEach(store.categories) { category in
                        Text(LocalizedStringKey(category.name))
                    }
                    .onDelete(perform: deleteCategory)
                    
                    Button {
                        showNewCategoryAlert = true
                    } label: {
                        Label("settings.add.category", systemImage: "plus")
                    }
                }
                
                // --- DATA ---
                Section("settings.data") {
                    Button(action: exportRecipes) {
                        Label("settings.export", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        showingImporter = true
                    } label: {
                        Label("settings.import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("settings")
            .alert("category.new.name", isPresented: $showNewCategoryAlert) {
                TextField("category.new.name", text: $newCategoryName)
                Button("button.add") {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    _ = store.addCategory(trimmed)
                    newCategoryName = ""
                }
                Button("button.cancel", role: .cancel) { newCategoryName = "" }
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(viewModel: timerViewModel)
            }
            // Recipe Importer
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            // Sound Importer
            .fileImporter(
                isPresented: $showingSoundImporter,
                allowedContentTypes: [.mp3, .wav, .mpeg4Audio],
                allowsMultipleSelection: false
            ) { result in
                handleSoundImport(result: result)
            }
        }
    
    // --- HELPER FUNCTIONS ---

    private func handleDecrementTap() {
        if didLongPressDecrement {
            didLongPressDecrement = false
            return
        }

        store.settings.defaultPortions = max(minPortions, store.settings.defaultPortions - 1)
        store.saveSettings()
    }

    private func handleIncrementTap() {
        if didLongPressIncrement {
            didLongPressIncrement = false
            return
        }

        store.settings.defaultPortions = min(maxPortions, store.settings.defaultPortions + 1)
        store.saveSettings()
    }
    
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
                   _ = store.saveRecipe(recipe, newImageData: nil)
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
            
            // Build app-container path
            let soundsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Sounds", isDirectory: true)
            // Create folder if it doesnt exist yet
            do {
                try FileManager.default.createDirectory(
                    at: soundsDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                print("Failed creating sound folder: \(error.localizedDescription)")
            }
            
            // Create final destination part
            let destURL = soundsDirectory.appendingPathComponent(url.lastPathComponent)
            
            // Ask for permission to use selected file
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    // If file already exists, remove old one
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    
                    // Copy data
                    let data = try Data(contentsOf: url)
                    try data.write(to: destURL)
                    
                    // Refresh sound list
                    timerViewModel.refreshAvailableSounds()
                    
                } catch {
                    print(" Error saving file: \(error.localizedDescription)")
                }
            } else {
                print("Acces to chosen file has been denied by system")
            }
            
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
}
