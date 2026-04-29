//
//  MainPageView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//
import SwiftUI

struct MainPageView: View {
    @State private var store = RecipeStore()
    @State private var sortOption: RecipeSortOption = .name
    @State private var displayStyle: RecipeDisplayStyle = .compact
    @State private var selectedCategory: RecipeCategory? = nil
    
    
    private var visibleRecipes: [Recipe] {
        
        let filtered = store.recipes.filter { recipe in
            if let selected = selectedCategory {
                
                return recipe.category.id == selected.id
            } else {
                
                return true
            }
        }
        
        // 2. Poté seřadíme
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
    
    // MARK: - Body (Tohle v tvém kódu chybělo)
    var body: some View {
        NavigationStack {
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

    // MARK: - Sections
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
            HStack(spacing: 10) {
                // Počítadlo (používáme visibleRecipes, aby odpovídalo filtru)
                Text("\(visibleRecipes.count)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Tlačítko Řazení
                Menu {
                    Picker("Sort", selection: $sortOption) {
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

                // Tlačítko Filtru
                Menu {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Label("All", systemImage: selectedCategory == nil ? "checkmark.circle.fill" : "circle")
                    }
                    
                    Divider()
                    
                    ForEach(store.categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(
                                category.name,
                                systemImage: selectedCategory?.id == category.id ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                
                // Přepínač stylu (Ikony)
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

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("main.recipes.title")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(visibleRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe, store: store)
                } label: {
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
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomNavigationBar: some View {
        HStack {
            NavigationBarButton(titleKey: "navigation.voice_regime", systemImage: "mic")
            
            NavigationLink {
                TimerView()
            } label: {
                NavigationBarButton(titleKey: "navigation.timer", systemImage: "timer")
            }
            .buttonStyle(.plain)
            
            NavigationBarButton(titleKey: "navigation.home", systemImage: "house.fill", isSelected: true)
            
            NavigationLink {
                RecipeFormView(store: store) { newRecipe in
                    // Recept se uloží do store, UI se díky @Observable samo překreslí
                    store.saveRecipe(newRecipe, newImageData: nil)
                }
            } label: {
                NavigationBarButton(titleKey: "navigation.add", systemImage: "plus")
            }
            .buttonStyle(.plain)
            
            NavigationBarButton(titleKey: "navigation.settings", systemImage: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func toggleFavorite(for recipeID: UUID) {
        if let index = store.recipes.firstIndex(where: { $0.id == recipeID }) {
            var updatedRecipe = store.recipes[index]
            updatedRecipe.isFavorite.toggle()
            store.saveRecipe(updatedRecipe, newImageData: nil)
        }
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

public struct RecipeImage: View {
    let imageData: Data?
    
    public var body: some View {
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
