//
//  MainPage.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import UIKit
import PhotosUI

struct RecipeCategory: Identifiable, Equatable {
    var id = UUID()
    var name: String
}
struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 1. We use the store passed from the parent
    @Bindable var store: RecipeStore
    
    @State private var name = ""
    @State private var category: RecipeCategory
    @State private var recipeDescription = ""
    @State private var ingredientsLines: [String] = [""]
    @State private var instructionsLines: [String] = [""]
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showNewCategoryAlert = false
    @State private var newCategoryName = ""

    let onSave: (Recipe) -> Void

    init(store: RecipeStore, recipeToEdit: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
            self.store = store
            self.onSave = onSave
            
            // If editing, use the recipe's data. If new, use defaults.
            _name = State(initialValue: recipeToEdit?.name ?? "")
            _recipeDescription = State(initialValue: recipeToEdit?.recipeDescription ?? "")
            _category = State(initialValue: recipeToEdit?.category ?? store.categories.first ?? RecipeCategory(name: "Lunch"))
            _isFavorite = State(initialValue: recipeToEdit?.isFavorite ?? false)
            _selectedImageData = State(initialValue: recipeToEdit?.imageData)
            
            // Break strings back into lines for the SmartListEditor
            let ing = recipeToEdit?.ingredients.components(separatedBy: "\n") ?? [""]
            _ingredientsLines = State(initialValue: ing)
            
            let ins = recipeToEdit?.instructions.components(separatedBy: "\n") ?? [""]
            _instructionsLines = State(initialValue: ins)
        }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredientsLines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instructionsLines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 12) {
                            RecipeSelectedImagePreview(imageData: selectedImageData)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Image")
                                    .foregroundStyle(.primary)
                                Text(selectedImageData == nil ? "Choose from gallery" : "Tap to change photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Recipe Name", text: $name)
                    
                    Menu {
                        // 3. Loop over categories in the STORE, not local state
                        ForEach(store.categories) { cat in
                            Button {
                                category = cat
                            } label: {
                                Label(
                                    cat.name,
                                    systemImage: category == cat ? "checkmark" : "circle"
                                )
                            }
                        }

                        Divider()

                        Button {
                            showNewCategoryAlert = true
                        } label: {
                            Label("New Category", systemImage: "plus")
                        }

                    } label: {
                        HStack {
                            Text(category.name)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    TextField("Description", text: $recipeDescription)
                }
                
                Section("Ingredients") {
                    SmartListEditor(lines: $ingredientsLines, style: .bulleted)
                        .frame(minHeight: 160)
                }

                Section("Instructions") {
                    SmartListEditor(lines: $instructionsLines, style: .bulleted)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("New Recipe")
            .task(id: selectedPhoto) {
                await loadSelectedPhoto()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let recipe = Recipe(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            recipeDescription: recipeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                            ingredients: ingredientsLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: instructionsLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                            isFavorite: isFavorite,
                            imageData: selectedImageData
                        )
                        onSave(recipe)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("New Category", isPresented: $showNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)

            Button("Add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                // 4. Add to the STORE so it persists everywhere
                let newCat = store.addCategory(trimmed)
                category = newCat // Auto-select the one we just made

                newCategoryName = ""
            }

            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
        } message: {
            Text("Create a custom category for your recipe.")
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            selectedImageData = try await selectedPhoto.loadTransferable(type: Data.self)
        } catch {
            selectedImageData = nil
        }
    }
}

private struct RecipeSelectedImagePreview: View {
    let imageData: Data?

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
