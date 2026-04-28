//
//  MainPageView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI

struct MainPageView: View {
    @State private var sortOption: RecipeSortOption = .name
    @State private var displayStyle: RecipeDisplayStyle = .compact
    @State private var showCategoryFilter = false
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var recipes: [Recipe] = [
        Recipe(
            name: "Tomato Soup",
            category: .lunch,
            recipeDescription: "Classic soup with basil.",
            instructions: "Cook tomatoes, blend them, and simmer with basil.",
            isFavorite: true
        ),
        Recipe(
            name: "Pancakes",
            category: .lunch,
            recipeDescription: "Quick breakfast pancakes.",
            instructions: "Mix batter, pour into pan, and cook until golden.",
            isFavorite: true
        ),
        Recipe(
            name: "Grilled Chicken",
            category: .lunch,
            recipeDescription: "Simple grilled chicken breast.",
            instructions: "Season chicken and grill until fully cooked.",
            isFavorite: false
        ),
        Recipe(
            name: "Vegetable Salad",
            category: .lunch,
            recipeDescription: "Fresh mixed salad.",
            instructions: "Chop vegetables, mix, and serve.",
            isFavorite: false
        )
    ]
    
    private var sortedRecipes: [Recipe] {
        // Switch determining by what criteria should the recipes be sorted
        switch sortOption {
        case .name:
            recipes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .favorites:
            recipes.sorted {
                if $0.isFavorite == $1.isFavorite {
                    return $0.name.localizedCompare($1.name) == .orderedAscending
                }
                
                return $0.isFavorite && !$1.isFavorite // Put favourite recipes first, not favourite second
            }
        }
    }
    
    private var visibleRecipes: [Recipe] {
        recipes
            .filter {
                selectedCategory == nil || $0.category == selectedCategory }
            .sorted { lhs, rhs in
                if lhs.isFavorite == rhs.isFavorite {
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
                return lhs.isFavorite && !rhs.isFavorite
            }
    }
    
    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("recipe.category").font(.headline)
            
            ForEach(RecipeCategory.allCases) { category in
                HStack {
                    Image(systemName: selectedCategory == category
                          ? "checkmark.circle.fill"
                          : "circle")
                    Text(category.title)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                
            }
        }
    }
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        controlsSection
                        recipesSection
                    }
                    .padding(20)
                }
                
                bottomNavigationBar
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

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(localized: "main.controls.recipe_count_label")): \(recipes.count)")
                    .font(.headline)

                Spacer()
                
                Menu {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Label(
                            "label.all",
                            systemImage: selectedCategory == nil
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }

                    Divider()

                    ForEach(RecipeCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(
                                category.title,
                                systemImage: selectedCategory == category
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()

                Picker("main.controls.sort_by", selection: $sortOption) {
                    ForEach(RecipeSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("main.controls.display_style", selection: $displayStyle) {
                ForEach(RecipeDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("main.recipes.title")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(visibleRecipes) { recipe in
                switch displayStyle {
                case .compact:
                    CompactRecipeRow(recipe: recipe) {
                        toggleFavorite(for: recipe.id)
                    }
                case .card:
                    CardRecipeRow(recipe: recipe) {
                        toggleFavorite(for: recipe.id)
                    }
                }
            }
        }
    }

    private var bottomNavigationBar: some View {
        HStack {
            
            // Voice regime
            NavigationBarButton(titleKey: "navigation.voice_regime", systemImage: "mic")
            
            // Timer
            NavigationLink {
                TimerView()
            } label: {
                NavigationBarButton(titleKey: "navigation.timer", systemImage: "timer")
            }
            .buttonStyle(.plain)
            
            // Home
            NavigationBarButton(titleKey: "navigation.home", systemImage: "house.fill", isSelected: true)
            
            // New recipe
            NavigationLink {
                RecipeFormView { newRecipe in
                    recipes.append(newRecipe)
                }
            } label: {
                NavigationBarButton(titleKey: "navigation.add", systemImage: "plus")
            }
            .buttonStyle(.plain)
            
            // Settings
            NavigationBarButton(titleKey: "navigation.settings", systemImage: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func toggleFavorite(for recipeID: UUID) {
        guard let index = recipes.firstIndex(where: { $0.id == recipeID }) else {
            return
        }

        recipes[index].isFavorite.toggle()
    }
}

private struct CompactRecipeRow: View {
    let recipe: Recipe
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
                .frame(maxWidth: .infinity)
                .frame(height: 150)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RecipeImage: View {
    let imageData: Data?
    
    var body: some View {
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

private struct NavigationBarButton: View {
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

#Preview {
    MainPageView()
}
