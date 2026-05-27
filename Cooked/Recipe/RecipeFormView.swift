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
    @State private var selectedCategories: [RecipeCategory]
    @State private var cookingTimeMinutes: Double = 0
    @State private var selectedDifficulty: RecipeDifficulty
    @State private var hasManuallySelectedDifficulty = false
    @State private var recipeDescription = ""
    @State private var showNewUnitAlert = false
    @State private var newUnitName = ""
    
    // Unified array representing synchronized layout groupings
    @State private var sections: [RecipeSection]
    
    @FocusState private var focusedField: Field?
    
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showNewCategoryAlert = false
    @State private var newCategoryName = ""

    private static let maxCookingTimeMinutes = 240 // Slider has maximum of 4 hours
    
    // --- ENUMS ---
    enum Field: Hashable {
        case name
        case recipeDescription
        case sectionName(Int)
        case ingredientName(section: Int, row: Int)
        case ingredientAmount(section: Int, row: Int)
        case instruction(section: Int, row: Int)
    }

    init(store: RecipeStore, recipeToEdit: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
        self.store = store
        self.recipeToEdit = recipeToEdit
        self.onSave = onSave

        let draft = store.draftRecipe
        let draftCategory = draft.categoryID.flatMap { categoryID in
            store.categories.first { $0.id == categoryID }
        }
        
        _name = State(initialValue: recipeToEdit?.name ?? draft.name)
        _recipeDescription = State(initialValue: recipeToEdit?.recipeDescription ?? draft.recipeDescription)
        _selectedCategories = State(initialValue: recipeToEdit?.categories ?? [draftCategory ?? store.categories.first ?? RecipeCategory(name: "category.lunch")])
        let initialCookingTime = max(0, recipeToEdit?.cookingTimeMinutes ?? draft.cookingTimeMinutes)
        _cookingTimeMinutes = State(initialValue: Double(initialCookingTime))
        _selectedDifficulty = State(initialValue: recipeToEdit?.difficulty ?? draft.difficulty)
        _isFavorite = State(initialValue: recipeToEdit?.isFavorite ?? false)
        _selectedImageData = State(initialValue: recipeToEdit?.imageData ?? store.loadDraftImageData())
        
        
        _sections = State(initialValue: recipeToEdit?.sections ?? (draft.sections.isEmpty ? [RecipeSection()] : draft.sections))
    }

    private var isEditing: Bool {
        recipeToEdit != nil
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isChanged: Bool {
        let original = recipeToEdit
        return  name != original?.name ||
                selectedCategories != original?.categories ||
                Int(cookingTimeMinutes) != original?.cookingTimeMinutes ||
                selectedDifficulty != original?.difficulty ||
                recipeDescription != original?.recipeDescription ||
                isFavorite != original?.isFavorite ||
                selectedImageData != original?.imageData ||
                sections != original?.sections
    }

    @ViewBuilder
    private var categorySummary: some View {
        if selectedCategories.isEmpty {
            Text("category.none")
        } else if selectedCategories.count == 1, let category = selectedCategories.first {
            Text(LocalizedStringKey(category.name))
        } else {
            Text("\(selectedCategories.count) categories")
        }
    }

    private func categoryBinding(for category: RecipeCategory) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains { $0.id == category.id } },
            set: { isSelected in
                if isSelected {
                    if !selectedCategories.contains(where: { $0.id == category.id }) {
                        selectedCategories.append(category)
                    }
                } else {
                    selectedCategories.removeAll { $0.id == category.id }
                }
            }
        )
    }

    private var cookingHoursBinding: Binding<Int> {
        Binding(
            get: { Int(cookingTimeMinutes) / 60 },
            set: { setCookingTime(hours: $0, minutes: Int(cookingTimeMinutes) % 60) }
        )
    }

    private var cookingMinutesBinding: Binding<Int> {
        Binding(
            get: { Int(cookingTimeMinutes) % 60 },
            set: { setCookingTime(hours: Int(cookingTimeMinutes) / 60, minutes: $0) }
        )
    }

    private var cookingTimeSliderBinding: Binding<Double> {
        Binding(
            get: { cookingTimeMinutes },
            set: { cookingTimeMinutes = $0 }
        )
    }

    private var shouldShowCookingTimeSlider: Bool {
        cookingTimeMinutes <= Double(Self.maxCookingTimeMinutes)
    }

    private var difficultyBinding: Binding<RecipeDifficulty> {
        Binding(
            get: { selectedDifficulty },
            set: { newDifficulty in
                hasManuallySelectedDifficulty = true
                selectedDifficulty = newDifficulty
            }
        )
    }

    private func setCookingTime(hours: Int, minutes: Int) {
        let clampedHours = max(0, hours)
        let clampedMinutes = max(0, min(59, minutes))
        let totalMinutes = (clampedHours * 60) + clampedMinutes
        cookingTimeMinutes = Double(totalMinutes)
    }

    private func autoCalculatedDifficulty() -> RecipeDifficulty {
        let textSteps = sections.flatMap { $0.instructions.map(\.text) }
        let flatIngredients = sections.flatMap { $0.ingredients }
        return Self.calculateDifficulty(
            name: name,
            ingredients: flatIngredients,
            instructions: textSteps,
            cookingTimeMinutes: Int(cookingTimeMinutes)
        )
    }

    private func updateDifficultyIfNeeded() {
        guard !isEditing, !hasManuallySelectedDifficulty else { return }
        selectedDifficulty = autoCalculatedDifficulty()
    }

    private static func calculateDifficulty(
        name: String,
        ingredients: [Ingredient],
        instructions: [String],
        cookingTimeMinutes: Int
    ) -> RecipeDifficulty {
        let joinedText = ([name] + instructions).joined(separator: " ").lowercased()

        var score = Double(instructions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)

        let filledIngredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        score += Double(filledIngredients.count) * 0.5

        let sectionCount = filledIngredients.filter { ingredient in
            let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return name.hasPrefix("for ") || name.hasSuffix(":")
        }
        .count
        
        if sectionCount >= 3 {
            score += 6
        } else if sectionCount == 2 {
            score += 3
        }

        score += Double(max(0, cookingTimeMinutes)) / 15

        if score <= 12 {
            return .easy
        } else if score <= 28 {
            return .intermediate
        } else {
            return .advanced
        }
    }

    var body: some View {
        Form {
            basicInfoSection
            ingredientsPartSection
            instructionsPartSection
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                Color.clear.frame(height: 200)
            }
        }
        .navigationTitle(recipeToEdit == nil ? "recipe.new" : "recipe.edit")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhoto) { await loadSelectedPhoto() }
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.reset") { resetFormToOriginalRecipe() }
                        .disabled(!isChanged)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("button.save") { saveAction() }
                    .disabled(!isFormValid)
            }
        }
        .alert("category.new", isPresented: $showNewCategoryAlert) {
            TextField("category.name", text: $newCategoryName)
            Button("button.add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                selectedCategories.append(store.addCategory(trimmed))
                newCategoryName = ""
            }
            Button("button.cancel", role: .cancel) { newCategoryName = "" }
        }
        .alert("unit.new.name", isPresented: $showNewUnitAlert) {
            TextField("unit.new.name", text: $newUnitName)
            Button("button.add") {
                let trimmed = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                store.addUnit(trimmed)
                newUnitName = ""
            }
            Button("button.cancel", role: .cancel) { newUnitName = "" }
        }
        .navigationDestination(isPresented: $navigateToCropper) {
            if let rawImage = rawSelectedImage {
                ImageCropper(image: rawImage, visibleImageData: $selectedImageData, isShown: $navigateToCropper)
            }
        }
        .onChange(of: name) { _, _ in
            updateDifficultyIfNeeded()
            saveDraftIfNeeded()
        }
        .onChange(of: recipeDescription) { _, _ in saveDraftIfNeeded() }
        .onChange(of: selectedCategories) { _, _ in saveDraftIfNeeded() }
        .onChange(of: cookingTimeMinutes) { _, _ in
            updateDifficultyIfNeeded()
            saveDraftIfNeeded()
        }
        .onChange(of: selectedDifficulty) { _, _ in saveDraftIfNeeded() }
        .onChange(of: sections) { _, _ in
            updateDifficultyIfNeeded()
            saveDraftIfNeeded()
        }
        .onChange(of: selectedImageData) { _, _ in
            guard !isEditing else { return }
            store.saveDraftImageData(selectedImageData)
        }
    }
    
    // --- EXTRACTED VIEWS ---
    
    private var basicInfoSection: some View {
        Section("info.basic") {
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
            
            TextField("recipe.name", text: $name)
                .focused($focusedField, equals: .name)
            
            DisclosureGroup {
                ForEach(store.categories) { cat in
                    Toggle(isOn: categoryBinding(for: cat)) {
                        Text(LocalizedStringKey(cat.name))
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
                Button { showNewCategoryAlert = true } label: {
                    Label("category.new", systemImage: "plus")
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("categories").foregroundStyle(.primary)
                    categorySummary.font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("difficulty", systemImage: "chart.bar.fill")
                Picker("difficulty", selection: difficultyBinding) {
                    ForEach(RecipeDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("recipe.time", systemImage: "clock")
                HStack(spacing: 8) {
                    TextField("0", value: cookingHoursBinding, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 44)
                    Text("h").foregroundStyle(.secondary)
                    TextField("0", value: cookingMinutesBinding, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 44)
                    Text("min").foregroundStyle(.secondary)
                }
                
                Slider(value: cookingTimeSliderBinding, in: 0...Double(Self.maxCookingTimeMinutes), step: 5)
                    .frame(height: shouldShowCookingTimeSlider ? nil : 0)
                    .opacity(shouldShowCookingTimeSlider ? 1 : 0)
                    .clipped()
                    .allowsHitTesting(shouldShowCookingTimeSlider)
            }
            .animation(.easeInOut(duration: 0.25), value: shouldShowCookingTimeSlider)

            TextField("recipe.description", text: $recipeDescription)
                .focused($focusedField, equals: .recipeDescription)
        }
    }
    
    // ---  INGREDIENTS SECTION ---
    @ViewBuilder
    private var ingredientsPartSection: some View {
        ForEach(sections) { section in
            IngredientSectionRowView(
                sections: $sections,
                sectionID: section.id,
                availableUnits: store.availableUnits,
                focusedField: $focusedField,
                onRemove: {
                    if let idx = sections.firstIndex(where: { $0.id == section.id }) {
                        removeSection(at: idx)
                    }
                },
                showNewUnitAlert: $showNewUnitAlert
            )
        }
        
        Section {
            Button(action: addNewSection) {
                Label("section.add", systemImage: "folder.badge.plus")
            }
        }
    }

    // ---  INSTRUCTIONS SECTION ---
    @ViewBuilder
    private var instructionsPartSection: some View {
        ForEach(sections) { section in
            InstructionSectionRowView(
                sections: $sections,
                sectionID: section.id,
                focusedField: $focusedField
            )
        }
        
    }
    
    // --- HELPER LOGIC FUNCTIONS ---
    private func addNewSection() {
        withAnimation {
            let newIndex = sections.count
            let defaultSectionName = String(localized: "section.default \(newIndex + 1)")
            
            let newGroup = RecipeSection(
                name: defaultSectionName,
                ingredients: [Ingredient(name: "", amount: 1, unit: "")],
                instructions: [InstructionLine(text: "")]
            )
            
            sections.append(newGroup)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.focusedField = .sectionName(newIndex)
            }
        }
    }

    private func removeSection(at index: Int) {
        withAnimation {
            guard sections.count > 1 else { return }
            sections.remove(at: index)
            
            if sections.count == 1 {
                sections[0].name = nil
            }
        }
    }

    private func saveAction() {
        // Explicitly type-cast and break down the section sanitization logic
        let finalRecipeSections: [RecipeSection] = sections.map { currentSection in
            var sanitized = currentSection
            sanitized.ingredients = currentSection.ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            sanitized.instructions = currentSection.instructions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return sanitized
        }.filter { !$0.ingredients.isEmpty || !$0.instructions.isEmpty }
        
        // Separate out the flattened ingredients sequence
        let flatIngredients: [Ingredient] = finalRecipeSections.flatMap { $0.ingredients }
        
        // Separate out the string serialization sequence
        let mappedLines: [[String]] = finalRecipeSections.map { section in
            let header = section.name.map { ["[\($0)]"] } ?? []
            let steps = section.instructions.map(\.text)
            return header + steps
        }
        let serializedInstructionsText: String = mappedLines.flatMap { $0 }.joined(separator: "\n")
        
        // Resolve IDs and configuration parameters cleanly upfront
        let recipeId: UUID = recipeToEdit?.id ?? UUID()
        let defaultPortions: Int = recipeToEdit?.defaultPortions ?? store.settings.defaultPortions
        let computedCookingTime: Int = max(0, Int(cookingTimeMinutes))
        let existingImageName: String? = recipeToEdit?.imageFileName

        // Construct the Recipe struct using pre-checked values
        let recipeToSave = Recipe(
            id: recipeId,
            name: name,
            categories: selectedCategories,
            recipeDescription: recipeDescription,
            defaultPortions: defaultPortions,
            cookingTimeMinutes: computedCookingTime,
            difficulty: selectedDifficulty,
            isFavorite: isFavorite,
            imageFileName: existingImageName,
            sections: finalRecipeSections
        )
        
        // Complete storage actions
        let savedRecipe = store.saveRecipe(recipeToSave, newImageData: selectedImageData)
        if !isEditing { store.clearDraft() }
        onSave(savedRecipe)
        if !isEditing { dismiss() }
    }

    private func saveDraftIfNeeded() {
        guard !isEditing else { return }
        store.draftRecipe.name = name
        store.draftRecipe.recipeDescription = recipeDescription
        store.draftRecipe.categoryID = selectedCategories.first?.id
        store.draftRecipe.cookingTimeMinutes = max(0, Int(cookingTimeMinutes))
        store.draftRecipe.difficulty = selectedDifficulty
        store.draftRecipe.sections = sections
    }

    private func resetFormToOriginalRecipe() {
        guard let recipeToEdit else { return }
        name = recipeToEdit.name
        selectedCategories = recipeToEdit.categories
        cookingTimeMinutes = Double(max(0, recipeToEdit.cookingTimeMinutes))
        selectedDifficulty = recipeToEdit.difficulty
        recipeDescription = recipeToEdit.recipeDescription
        sections = recipeToEdit.sections.isEmpty ? [RecipeSection()] : recipeToEdit.sections
        isFavorite = recipeToEdit.isFavorite
        selectedImageData = recipeToEdit.imageData
        rawSelectedImage = nil
        selectedPhoto = nil
        navigateToCropper = false
        focusedField = nil
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

// --- SUB-VIEWS ---

private struct IngredientSectionRowView: View {
    @Binding var sections: [RecipeSection]
    let sectionID: UUID // Track cleanly via stable UUID
    let availableUnits: [String]
    let focusedField: FocusState<RecipeFormView.Field?>.Binding
    var onRemove: () -> Void
    @Binding var showNewUnitAlert: Bool
    
    // Pure functional lookup to always get the live section instance
    private var currentSectionIndex: Int? {
        sections.firstIndex(where: { $0.id == sectionID })
    }
    
    var body: some View {
        if let sIdx = currentSectionIndex {
            let sectionNameBinding = Binding<String>(
                get: {
                    
                    guard let sIdx = currentSectionIndex, sIdx < sections.count else { return "" }
                    return sections[sIdx].name ?? ""
                },
                set: { newValue in
                    
                    guard let sIdx = currentSectionIndex, sIdx < sections.count else { return }
                    sections[sIdx].name = newValue.isEmpty ? nil : newValue
                }
            )
            
            Section(header:
                TextField(LocalizedStringKey("section.default \(sIdx + 1)"), text: sectionNameBinding)
                    .font(.headline)
                    .textCase(nil)
                    .focused(focusedField, equals: .sectionName(sIdx))
            ) {
                // Loop over ingredients elements directly using their stable identities
                ForEach($sections[sIdx].ingredients) { $ingredient in
                    let rIdx = sections[sIdx].ingredients.firstIndex(where: { $0.id == ingredient.id }) ?? 0
                    
                    HStack(spacing: 8) {
                        TextField("ingredient.name", text: $ingredient.name)
                            .focused(focusedField, equals: .ingredientName(section: sIdx, row: rIdx))
                        
                        TextField("0", value: $ingredient.amount, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                        
                        Menu {
                            // Show available units
                            ForEach(availableUnits, id: \.self) { unit in
                                Button {
                                    ingredient.unit = unit
                                } label: {
                                    Text(LocalizedStringKey(unit))
                                }
                            }
                            Button { // Add new unit button
                                showNewUnitAlert = true
                            } label: {
                                Label("settings.add.unit", systemImage: "plus")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                let currentUnit = ingredient.unit
                                
                                if currentUnit.isEmpty {
                                    Text("unit")
                                } else {
                                    Text(LocalizedStringKey(currentUnit))
                                        .foregroundStyle(.primary)
                                }
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 65, alignment: .trailing)
                        }
                    }
                }
                .onDelete { offsets in
                    sections[sIdx].ingredients.remove(atOffsets: offsets)
                }

                HStack {
                    Button(action: {
                        sections[sIdx].ingredients.append(Ingredient(name: "", amount: 1, unit: ""))
                    }) {
                        Label("ingredient.add", systemImage: "plus.circle")
                    }
                    
                    Spacer()
                    
                    if sections.count > 1 {
                        Button(role: .destructive, action: onRemove) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }
}

private struct InstructionSectionRowView: View {
    @Binding var sections: [RecipeSection]
    let sectionID: UUID // Track cleanly via stable UUID
    let focusedField: FocusState<RecipeFormView.Field?>.Binding
    
    private var currentSectionIndex: Int? {
        sections.firstIndex(where: { $0.id == sectionID })
    }
    
    var body: some View {
        if let sIdx = currentSectionIndex {
            let sectionNameBinding = Binding<String>(
                get: {
                    guard let sIdx = currentSectionIndex, sIdx < sections.count else { return "" }
                    return sections[sIdx].name ?? ""
                },
                set: { newValue in
                    guard let sIdx = currentSectionIndex, sIdx < sections.count else { return }
                    sections[sIdx].name = newValue.isEmpty ? nil : newValue
                }
            )

            Section(header:
                TextField(LocalizedStringKey("section.default \(sIdx + 1)"), text: sectionNameBinding)
                    .font(.headline)
                    .textCase(nil)
                    .focused(focusedField, equals: .sectionName(sIdx))
            ) {
                // FIX: Loop cleanly over indices to prevent the SwiftUI compiler from timing out
                ForEach(sections[sIdx].instructions.indices, id: \.self) { rIdx in
                    let instructionTextBinding = Binding<String>(
                        get: {
                            guard sIdx < sections.count, rIdx < sections[sIdx].instructions.count else { return "" }
                            return sections[sIdx].instructions[rIdx].text
                        },
                        set: { sections[sIdx].instructions[rIdx].text = $0 }
                    )
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(rIdx + 1).")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, 8)
                        
                        TextField("Step description...", text: instructionTextBinding, axis: .vertical)
                            .lineLimit(1...5)
                            .focused(focusedField, equals: .instruction(section: sIdx, row: rIdx))
                    }
                }
                .onDelete { offsets in
                    sections[sIdx].instructions.remove(atOffsets: offsets)
                }
                
                Button(action: {
                    sections[sIdx].instructions.append(InstructionLine(text: ""))
                }) {
                    Label("instruction.add", systemImage: "plus.circle")
                }
            }
        }
    }
}

// --- STANDARD PRIVATELY SCOPED COMPONENT VIEWS ---

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label.foregroundStyle(.primary)
                Spacer()
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
