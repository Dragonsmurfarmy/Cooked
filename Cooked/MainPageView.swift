//
//  MainPageView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//
import SwiftUI

struct MainPageView: View {
    @Bindable var store: RecipeStore
    @State private var sortOption: RecipeSortOption = .name
    @State private var displayStyle: RecipeDisplayStyle = .compact
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Derive the visible list from the store by filtering by active category and selected sort order

    private var visibleRecipes: [Recipe] {
        
        let filtered = store.recipes.filter { recipe in
            if let selected = selectedCategory {
                
                return recipe.category.id == selected.id
            } else {
                
                return true
            }
        }
        
        // Options by which to sort recipes
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .favorites:
            return filtered.sorted {
                if $0.isFavorite == $1.isFavorite {
                    return $0.name.localizedCompare($1.name) == .orderedAscending
                }
                return $0.isFavorite && !$1.isFavorite
            }
        }
    }
    
    var body: some View {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        controlsSection
                        recipesSection
                    }
                    .padding(20)
                }
            }
        
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("main.header.title")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("main.header.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // recipe count, sorting, filtering, and switching between compact and card layouts
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                
                // Recipes count
                Text("\(visibleRecipes.count)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Sorting
                Menu {
                    Picker("sort", selection: $sortOption) {
                        ForEach(RecipeSortOption.allCases) { option in
                            Label(option.title, systemImage: option == .name ? "textformat" : "star.fill")
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                
                // Filtering
                Menu {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Label("category.all", systemImage: selectedCategory == nil ? "checkmark.circle.fill" : "circle")
                    }
                    
                    Divider()
                    
                    ForEach(store.categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(
                                LocalizedStringKey(category.name),
                                systemImage: selectedCategory?.id == category.id ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                
                // Card/Compact view picker
                Picker("Display", selection: $displayStyle) {
                    ForEach(RecipeDisplayStyle.allCases) { style in
                        Image(systemName: style == .compact ? "list.bullet" : "square.grid.2x2")
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }
    }

    // Show Card/Compact style from the filtered/sorted recipes
    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("main.recipes.title")
                .font(.title2)
                .fontWeight(.semibold)

            Group {
                // Compact style
                if displayStyle == .compact {
                    VStack(spacing: 12) {
                        ForEach(visibleRecipes) { recipe in
                            recipeRowWrapper(recipe: recipe, isCard: false)
                        }
                    }
                } else { // Card style
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleRecipes) { recipe in
                            recipeRowWrapper(recipe: recipe, isCard: true)
                        }
                    }
                }
            }
            // Delete confirmation Popup
            .alert("\(recipeToDelete?.name ?? "")", isPresented: $showDeleteConfirmation, presenting: recipeToDelete) { recipe in
                Button("button.delete", role: .destructive) {
                    deleteRecipe(recipe)
                }
                Button("button.cancel", role: .cancel) { }
            } message: { _ in
                Text("delete.question")
            }
        }
    }

    
    @ViewBuilder
    private func recipeRowWrapper(recipe: Recipe, isCard: Bool) -> some View {
        // Keep actions in same place for both visual styles
        NavigationLink {
            RecipeDetailView(recipe: recipe, store: store)
        } label: {
            if isCard {
                CardRecipeRow(recipe: recipe) { toggleFavorite(for: recipe.id) }
            } else {
                CompactRecipeRow(recipe: recipe, store: store) { toggleFavorite(for: recipe.id) }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                recipeToDelete = recipe
                showDeleteConfirmation = true
            } label: {
                Label("button.delete", systemImage: "trash")
            }
        }
    }

    // Set recipe favourite/non-favourite
    private func toggleFavorite(for recipeID: UUID) {
        if let index = store.recipes.firstIndex(where: { $0.id == recipeID }) {
            var updatedRecipe = store.recipes[index]
            updatedRecipe.isFavorite.toggle()
            _ = store.saveRecipe(updatedRecipe, newImageData: nil)
        }
    }
    
    
    private func deleteRecipe(_ recipe: Recipe) {
        if let index = store.recipes.firstIndex(where: { $0.id == recipe.id }) {
            store.deleteRecipe(at: IndexSet(integer: index))
        }
    }
    
}


// Compact recipe showing style
private struct CompactRecipeRow: View {
    let recipe: Recipe
    let store: RecipeStore
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.headline)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(recipe.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)

            RecipeImage(imageData: recipe.imageData)
                .frame(width: 56, height: 56)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// Card recipe showing style
private struct CardRecipeRow: View {
    let recipe: Recipe
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recipe.name)
                    .font(.headline)

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(recipe.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }

            RecipeImage(imageData: recipe.imageData)
                .frame(height: 150)
                .contentShape(Rectangle())
                .clipped()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

public struct RecipeImage: View {
    let imageData: Data?
    
    public var body: some View {
        // Match loaded photo to frame caller gives to view
        // component works for Compact and Card layout
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemFill))

                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct NavigationBarButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(titleKey)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum RecipeSortOption: String, CaseIterable, Identifiable {
    case name
    case favorites

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .name:
            "main.sort_option.name"
        case .favorites:
            "main.sort_option.favorites"
        }
    }
}

private enum RecipeDisplayStyle: String, CaseIterable, Identifiable {
    case compact
    case card

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .compact:
            "main.recipe_display.compact"
        case .card:
            "main.recipe_display.card"
        }
    }
}


struct AlarmOverlay: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.white)

                Text("timer.ring")
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    viewModel.stopAlarm()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
    }
}

#Preview {
    MainPageView(store: RecipeStore())
}
