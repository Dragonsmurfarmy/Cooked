//
//  RecipeFormView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//
import SwiftUI
import UIKit
import PhotosUI

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: RecipeStore
    
    @State private var rawSelectedImage: UIImage?
    @State private var navigateToCropper = false
    
    let recipeToEdit: Recipe?
    let onSave: (Recipe) -> Void
    
    @State private var name = ""
    @State private var category: RecipeCategory
    @State private var recipeDescription = ""
    
    @State private var ingredients: [Ingredient]
    
    @State private var instructionsLines: [InstructionLine]
   
    
    
    @FocusState private var focusedField: Field?
    
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showNewCategoryAlert = false
    @State private var newCategoryName = ""
    
    // --- ENUMS ---
    enum Field: Hashable {
        case name(UUID)
        case amount(UUID)
        case unit(UUID)
        case ingredientName(UUID)
        case ingredientAmount(UUID)
        case ingredientUnit(UUID)
        case instruction(Int)
    }
    
    

    init(store: RecipeStore, recipeToEdit: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
        self.store = store
        self.recipeToEdit = recipeToEdit
        self.onSave = onSave
        
        // If recipe exists, prefill the form for editing. Otherwise use defaults for creation.
        _name = State(initialValue: recipeToEdit?.name ?? "")
        _recipeDescription = State(initialValue: recipeToEdit?.recipeDescription ?? "")
        _category = State(initialValue: recipeToEdit?.category ?? store.categories.first ?? RecipeCategory(name: "category.lunch"))
        _isFavorite = State(initialValue: recipeToEdit?.isFavorite ?? false)
        _selectedImageData = State(initialValue: recipeToEdit?.imageData)
        
        // Load ingredients
        _ingredients = State(initialValue: recipeToEdit?.ingredients ?? [Ingredient(name: "", amount: 1, unit: "")])
        
        let ins = recipeToEdit?.instructions.components(separatedBy: "\n") ?? [""]
        _instructionsLines = State(initialValue: ins.map { InstructionLine(text: $0) })
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredients.isEmpty
    }

    var body: some View {
            Form {
                // --- BASIC INFO SECTION ---
                Section("info.basic") {
                    
                    // --- IMAGE ---
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 12) {
                            RecipeSelectedImagePreview(imageData: selectedImageData)
                                .id(selectedImageData)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("image.select").foregroundStyle(.primary)
                                Text(selectedImageData == nil ? "image.choose" : "image.change")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // --- NAME ---
                    TextField("recipe.name", text: $name)
                    
                    // --- CATEGORIES ---
                    Menu {
                        ForEach(store.categories) { cat in
                            Button { category = cat } label: {
                                Label(LocalizedStringKey(cat.name), systemImage: category == cat ? "checkmark" : "circle")
                            }
                        }
                        
                        Divider()
                        // --- ADD NEW CATEGORY ---
                        Button { showNewCategoryAlert = true } label: {
                            Label("category.new", systemImage: "plus")
                        }
                        
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(category.name))
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    // --- DESCRIPTION ---
                    TextField("recipe.description", text: $recipeDescription)
                }
                
                Section {
                    // --- INGREDIENT SECTION ---
                    ForEach($ingredients) { $ingredient in
                        HStack {
                            TextField("ingredient.name", text: $ingredient.name)
                                .focused($focusedField, equals: .name(ingredient.id))
                                
                            
                            TextField("ingredient.quantity", value: $ingredient.amount, format: .number)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .amount(ingredient.id))
                                
                            
                            TextField("ingredient.unit", text: $ingredient.unit)
                                .frame(width: 60)
                                .focused($focusedField, equals: .unit(ingredient.id))
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }

                    Button(action: {
                        let newIng = Ingredient(name: "", amount: 1, unit: "")
                        ingredients.append(newIng)
                        focusedField = .name(newIng.id)
                    }) {
                        Label("ingredient.add", systemImage: "plus.circle")
                    }
                } header: {
                    Label("ingredients", systemImage: "list.bullet")
                }

                Section {
                        // --- INSTRUCTIONS LIST ---
                        SmartListEditor(
                            focusBinding: $focusedField,
                            lines: $instructionsLines,
                            style: .numbered
                        )
                        Button(action: {
                            let newLine = InstructionLine(text: "")
                            instructionsLines.append(newLine)
                            let lastIndex = instructionsLines.count - 1
                            focusedField = .instruction(lastIndex)
                        }) {
                            Label("instruction.add", systemImage: "plus.circle")
                        }
                    
                } header: {
                    Label("instructions", systemImage: "frying.pan")
                }
            }
            .navigationTitle(recipeToEdit == nil ? "recipe.new" : "recipe.edit")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: selectedPhoto) { await loadSelectedPhoto() }
            .toolbar {
                // ---- Cancel button is in rootView  for better UX ----
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") {
                        saveAction()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("category.new", isPresented: $showNewCategoryAlert) {
                TextField("category.name", text: $newCategoryName)
                Button("button.add") {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    category = store.addCategory(trimmed)
                    newCategoryName = ""
                }
                Button("button.cancel", role: .cancel) { newCategoryName = "" }
            }
            .navigationDestination(isPresented: $navigateToCropper) {
                if let rawImage = rawSelectedImage {
                    ImageCropper(image: rawImage,
                                 visibleImageData: $selectedImageData,
                                 isShown: $navigateToCropper)
                }
            }
    }
    
    private func saveAction() {
        // Filter out empty ingredients
        let finalIngredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Convert instruction lines back into the newline-separated string stored in Recipe.
        let finalInstructions = instructionsLines
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        // Reuse the existing id while editing so the stored recipe file is updated, not duplicated.
        let recipeToSave = Recipe(
            id: recipeToEdit?.id ?? UUID(),
            name: name,
            category: category,
            recipeDescription: recipeDescription,
            ingredients: finalIngredients,
            instructions: finalInstructions, // Saved as string
            isFavorite: isFavorite
        )
        
        let savedRecipe = store.saveRecipe(recipeToSave, newImageData: selectedImageData)
        onSave(savedRecipe)
        dismiss()
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        
        if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            
            await MainActor.run {
                self.rawSelectedImage = uiImage
                self.selectedPhoto = nil
                self.navigateToCropper = true
            }
        }
    }
}

private struct RecipeSelectedImagePreview: View {
    let imageData: Data?
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
   
}
