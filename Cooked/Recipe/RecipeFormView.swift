//
//  MainPage.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//
import SwiftUI
import UIKit
import PhotosUI

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: RecipeStore
    
    let recipeToEdit: Recipe?
    let onSave: (Recipe) -> Void
    
    @State private var name = ""
    @State private var category: RecipeCategory
    @State private var recipeDescription = ""
    
    // Používáme pole objektů Ingredient
    @State private var ingredients: [Ingredient]
    @State private var instructionsLines: [String] = [""]
    
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showNewCategoryAlert = false
    @State private var newCategoryName = ""

    // --- TADY MUSÍ BÝT FOCUS STATE ---
    enum Field: Hashable {
        case name(UUID)
        case amount(UUID)
        case unit(UUID)
    }
    @FocusState private var focusedField: Field?
    // ---------------------------------

    init(store: RecipeStore, recipeToEdit: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
        self.store = store
        self.recipeToEdit = recipeToEdit
        self.onSave = onSave
        
        _name = State(initialValue: recipeToEdit?.name ?? "")
        _recipeDescription = State(initialValue: recipeToEdit?.recipeDescription ?? "")
        _category = State(initialValue: recipeToEdit?.category ?? store.categories.first ?? RecipeCategory(name: "Lunch"))
        _isFavorite = State(initialValue: recipeToEdit?.isFavorite ?? false)
        _selectedImageData = State(initialValue: recipeToEdit?.imageData)
        
        // Načtení ingrediencí jako objektů
        _ingredients = State(initialValue: recipeToEdit?.ingredients ?? [Ingredient(name: "", amount: 1, unit: "")])
        
        let ins = recipeToEdit?.instructions.components(separatedBy: "\n") ?? [""]
        _instructionsLines = State(initialValue: ins)
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredients.isEmpty &&
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
                                Text("Select Image").foregroundStyle(.primary)
                                Text(selectedImageData == nil ? "Choose from gallery" : "Tap to change photo")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Recipe Name", text: $name)
                    
                    Menu {
                        ForEach(store.categories) { cat in
                            Button { category = cat } label: {
                                Label(cat.name, systemImage: category == cat ? "checkmark" : "circle")
                            }
                        }
                        Divider()
                        Button { showNewCategoryAlert = true } label: {
                            Label("New Category", systemImage: "plus")
                        }
                    } label: {
                        HStack {
                            Text(category.name)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Description", text: $recipeDescription)
                }
                
                Section {
                    ForEach($ingredients) { $ingredient in
                        HStack {
                            TextField("Name", text: $ingredient.name)
                                .focused($focusedField, equals: .name(ingredient.id))
                                .submitLabel(.next)
                            
                            TextField("Qty", value: $ingredient.amount, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .amount(ingredient.id))
                                .submitLabel(.next)
                            
                            TextField("Unit", text: $ingredient.unit)
                                .frame(width: 60)
                                .focused($focusedField, equals: .unit(ingredient.id))
                                .submitLabel(.next)
                        }
                        .onSubmit {
                            handleNextField(currentId: ingredient.id)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }

                    Button(action: {
                        let newIng = Ingredient(name: "", amount: 1, unit: "")
                        ingredients.append(newIng)
                        focusedField = .name(newIng.id)
                    }) {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                } header: {
                    Label("Ingredients", systemImage: "list.bullet")
                }

                Section {
                    SmartListEditor(lines: $instructionsLines, style: .numbered).frame(minHeight: 160)
                } header: { Label("Instructions", systemImage: "frying.pan") }
            }
            .navigationTitle(recipeToEdit == nil ? "New Recipe" : "Edit Recipe")
            .task(id: selectedPhoto) { await loadSelectedPhoto() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Filtrujeme pouze ingredience, které mají název
                        let finalIngredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                        
                        let recipe = Recipe(
                            id: recipeToEdit?.id ?? UUID(),
                            name: name,
                            category: category,
                            recipeDescription: recipeDescription,
                            ingredients: finalIngredients,
                            instructions: instructionsLines.joined(separator: "\n"),
                            isFavorite: isFavorite
                        )
                        store.saveRecipe(recipe, newImageData: selectedImageData)
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
                category = store.addCategory(trimmed)
                newCategoryName = ""
            }
            Button("Cancel", role: .cancel) { newCategoryName = "" }
        }
    }

    // Pomocná funkce pro přepínání polí
    private func handleNextField(currentId: UUID) {
        switch focusedField {
        case .name(let id):
            focusedField = .amount(id)
        case .amount(let id):
            focusedField = .unit(id)
        case .unit(let id):
            // Pokud jsme na konci řádku, vytvoříme nový nebo zrušíme focus
            let newIng = Ingredient(name: "", amount: 1, unit: "")
            ingredients.append(newIng)
            focusedField = .name(newIng.id)
        default:
            focusedField = nil
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        selectedImageData = try? await selectedPhoto.loadTransferable(type: Data.self)
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
