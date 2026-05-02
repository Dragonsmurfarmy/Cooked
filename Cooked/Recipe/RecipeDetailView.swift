//
//  Settings.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
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
            self._recipe = State(initialValue: recipe)
            self.store = store
        self._selectedPortions = State(initialValue: store.settings.defaultPortions)
        }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Large Image Header
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

                HStack {
                        Label("portions.count", systemImage: "person.2.fill")
                            .font(.headline)
                        Text("\(selectedPortions)")
                            .font(.title3.monospacedDigit())
                            .fontWeight(.semibold)
                            .frame(minWidth: 30)
                                    
                        Spacer()
                                    
                        Stepper("\(selectedPortions)", value: $selectedPortions, in: 1...50)
                            .labelsHidden() // Schováme label stepperu, protože máme vlastní text
                                    
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // --- UPRAVENÁ SEKCE INGREDIENCÍ ---
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
                                                
                                    // Výpočet množství: (množství / původní porce) * aktuální porce
                                    Text(calculateAmount(for: ingredient))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                                
                                    Text("ingredient.unit")
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

                // Instructions Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("instructions", systemImage: "frying.pan")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(recipe.instructions)
                        .font(.body)
                        .lineSpacing(4)
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
                    RecipeFormView(store: store, recipeToEdit: recipe) { updatedRecipe in
                        self.recipe = updatedRecipe
                    }
                }
    }
    
    // Pomocná funkce pro výpočet množství podle počtu porcí
        private func calculateAmount(for ingredient: Ingredient) -> String {
            // Výpočet: (původní množství / výchozí porce) * vybrané porce
            let baseAmount = Double(ingredient.amount) / Double(recipe.defaultPortions)
            let finalAmount = baseAmount * Double(selectedPortions)
            
            // Formátování: Pokud je to celé číslo, nepoužíváme desetinná místa
            if finalAmount.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", finalAmount)
            } else {
                // Jinak zaokrouhlíme na 1 desetinné místo (např. 1.5)
                return String(format: "%.1f", finalAmount)
            }
        }
}





