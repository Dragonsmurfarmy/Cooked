//
//  Settings.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import SwiftUI
import UIKit
import PhotosUI

struct RecipeDetailView: View {
    @State var recipe: Recipe
    @State private var isShowingEditSheet = false
    @State private var selectedPortions: Int
    @Bindable var store: RecipeStore
    
    init(recipe: Recipe, store: RecipeStore) {
            // Keep local copy so the detail screen can reflect edits after saving
            self._recipe = State(initialValue: recipe)
            self.store = store
            self._selectedPortions = State(initialValue: store.settings.defaultPortions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // --- IMAGE SECTION ---
                RecipeImage(imageData: recipe.imageData)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(recipe.category.name))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())

                    Text(recipe.name)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                }

                if !recipe.recipeDescription.isEmpty {
                    Text(recipe.recipeDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Divider()
                
                // --- PORTIONS SECTION ---
                HStack {
                        Label("portions.count", systemImage: "person.2.fill")
                            .font(.headline)
                        Text("\(selectedPortions)")
                            .font(.title3.monospacedDigit())
                            .fontWeight(.semibold)
                            .frame(minWidth: 30)
                                    
                        Spacer()
                                    
                        Stepper("\(selectedPortions)", value: $selectedPortions, in: 1...50)
                            .labelsHidden() // Hide stepper label since we use our own
                                    
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // --- INGREDIENT SECTION ---
                    VStack(alignment: .leading, spacing: 16) {
                        Label("ingredients", systemImage: "list.bullet")
                            .font(.title3)
                            .fontWeight(.bold)
                                    
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients) { ingredient in
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(.tint)
                                        .padding(.bottom, 4)
                                                
                                    Text(ingredient.name)
                                        .font(.body)
                                                
                                    Spacer()
                                                
                                    // Show ingredient amount scaled to currently selected portion count
                                    Text(calculateAmount(for: ingredient))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                                
                                    Text(ingredient.unit)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                            
                                if ingredient != recipe.ingredients.last {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                    }

                Divider()

                // --- INSTRUCTION SECTION ---
                VStack(alignment: .leading, spacing: 12) {
                    Label("instructions", systemImage: "frying.pan")
                        .font(.title3)
                        .fontWeight(.bold)

                    let steps = recipe.instructions.components(separatedBy: "\n").filter { !$0.isEmpty }
                        
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .fontWeight(.bold)
                                .foregroundStyle(.tint)
                                
                            Text(steps[index])
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("button.edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            NavigationStack {
                RecipeFormView(store: store, recipeToEdit: recipe) { updatedRecipe in
                    self.recipe = updatedRecipe
                    isShowingEditSheet = false // Close sheet
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("button.cancel") {
                            isShowingEditSheet = false // Close sheet
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to scale ingredient amounts from recipe default portions to the selected amount.
        private func calculateAmount(for ingredient: Ingredient) -> String {
            // Base amount for one portion.
            let baseAmount = Double(ingredient.amount) / Double(recipe.defaultPortions)
            // Final amount for the currently selected portion count.
            let finalAmount = baseAmount * Double(selectedPortions)
            
            
            let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 3 // Up to 3 decimals for doubles
                formatter.minimumFractionDigits = 0 // 0 digits for ints
                
                return formatter.string(from: NSNumber(value: finalAmount)) ?? "\(finalAmount)"
        }
}





