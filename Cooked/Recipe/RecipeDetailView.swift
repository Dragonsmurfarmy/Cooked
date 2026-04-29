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
    @Bindable var store: RecipeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Large Image Header
                RecipeImage(imageData: recipe.imageData)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.category.name)
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

                // Ingredients Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ingredients", systemImage: "list.bullet")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(recipe.ingredients)
                        .font(.body)
                        .lineSpacing(4)
                }

                Divider()

                // Instructions Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Instructions", systemImage: "frying.pan")
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
                Button("Edit") {
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
}





