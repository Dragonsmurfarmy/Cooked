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
    
    @State private var selectedCategoryIDs: Set<UUID>? = nil
    @State private var isShowingFilterPopover = false
    
    @State private var recipeToEdit: Recipe?
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @State private var isShowingEditPage = false
    
    private var allCategoryIDs: Set<UUID> {
        Set(store.categories.map { $0.id })
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var visibleRecipes: [Recipe] {
        guard let selected = selectedCategoryIDs else { return store.recipes }
        if selected.isEmpty { return [] }
        
        return store.recipes.filter { recipe in
            recipe.categories.contains { selected.contains($0.id) }
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
        .navigationDestination(isPresented: $isShowingEditPage) {
            if let recipe = recipeToEdit {
                RecipeFormView(store: store, recipeToEdit: recipe) { _ in isShowingEditPage = false }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("main.header.title").font(.largeTitle).fontWeight(.bold)
            Text("main.header.subtitle").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 10) {
            Text("\(visibleRecipes.count)")
                .font(.subheadline.bold())
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
            
            Spacer()
            
            Menu {
                // Ensure the selection matches the Enum type
                Picker("sort", selection: $sortOption) {
                    ForEach(RecipeSortOption.allCases) { option in
                        Label(option.title, systemImage: option == .name ? "textformat" : "star.fill").tag(option)
                    }
                }
            } label: { Image(systemName: "arrow.up.arrow.down.circle").font(.title3) }
            .buttonStyle(.bordered)
            
            Button { isShowingFilterPopover = true } label: {
                let isAllActive = (selectedCategoryIDs == nil)
                
                Image(systemName: isAllActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $isShowingFilterPopover) {
                FilterPopoverView(
                    categories: store.categories,
                    selectedCategoryIDs: $selectedCategoryIDs,
                    allCategoryIDs: allCategoryIDs
                )
            }
            
            Picker("Display", selection: $displayStyle) {
                ForEach(RecipeDisplayStyle.allCases) { style in
                    Image(systemName: style == .compact ? "list.bullet" : "square.grid.2x2").tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("main.recipes.title").font(.title2).fontWeight(.semibold)
            Group {
                if displayStyle == .compact {
                    VStack(spacing: 12) { ForEach(visibleRecipes) { recipe in recipeRowWrapper(recipe: recipe, isCard: false) } }
                } else {
                    LazyVGrid(columns: columns, spacing: 16) { ForEach(visibleRecipes) { recipe in recipeRowWrapper(recipe: recipe, isCard: true) } }
                }
            }
            .animation(.default, value: visibleRecipes)
        }
    }
    
    @ViewBuilder
    private func recipeRowWrapper(recipe: Recipe, isCard: Bool) -> some View {
        NavigationLink { RecipeDetailView(recipe: recipe, store: store) } label: {
            if isCard { CardRecipeRow(recipe: recipe) { toggleFavorite(for: recipe.id) } }
            else { CompactRecipeRow(recipe: recipe, store: store) { toggleFavorite(for: recipe.id) } }
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale))
        .contextMenu {
            Button { recipeToEdit = recipe; isShowingEditPage = true } label: { Label("button.edit", systemImage: "pencil") }
            Button(role: .destructive) { recipeToDelete = recipe; showDeleteConfirmation = true } label: { Label("button.delete", systemImage: "trash") }
        }
    }

    private func toggleFavorite(for recipeID: UUID) {
        if let index = store.recipes.firstIndex(where: { $0.id == recipeID }) {
            var updated = store.recipes[index]; updated.isFavorite.toggle(); _ = store.saveRecipe(updated, newImageData: nil)
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

                RecipeMetadata(recipe: recipe)
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


private struct RecipeMetadata: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(recipe.categories.first?.name ?? "category.lunch"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label(recipe.difficulty.title, systemImage: "chart.bar.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct CardRecipeRow: View {
    let recipe: Recipe
    let onToggleFavorite: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // Set spacing to 0 to prevent internal offsets
            VStack(alignment: .leading, spacing: 0) {
                
                // ----- Image Area ----
                RecipeImage(imageData: recipe.imageData, cornerRadius: 12)
                    .frame(height: geometry.size.height * 0.65) // Upper 65%
                    .frame(maxWidth: .infinity)
                    .clipped() // Prevents the image from "peeking" into the info area
                
                // ----- Info Area -----
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(recipe.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8) // Shrinks slightly if name is long
                            
                            Spacer()
                            
                            Button(action: onToggleFavorite) {
                            Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18, weight: .semibold)) // Explicit size for better visibility
                                .foregroundStyle(recipe.isFavorite ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        RecipeMetadata(recipe: recipe)
                    }
                    .padding(.horizontal, 10)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


struct RecipeImage: View {
    let imageData: Data?
        var cornerRadius: CGFloat = 12

        var body: some View {
            Group {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill) // Force 1:1 ratio
                } else {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

enum RecipeSortOption: String, CaseIterable, Identifiable {
    case name, favorites
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .name: "main.sort_option.name"
        case .favorites: "main.sort_option.favorites"
        }
    }
}

enum RecipeDisplayStyle: String, CaseIterable, Identifiable {
    case compact, card
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .compact: "main.recipe_display.compact"
        case .card: "main.recipe_display.card"
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

private struct FilterPopoverView: View {
    let categories: [RecipeCategory]
    @Binding var selectedCategoryIDs: Set<UUID>?
    let allCategoryIDs: Set<UUID>

    private var isAllSelected: Bool { selectedCategoryIDs == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack {
                Text("filter.title")
                    .font(.headline)
                Spacer()
                Button(isAllSelected ? "filter.clear_all" : "filter.select_all") {
                    withAnimation {
                        selectedCategoryIDs = isAllSelected ? [] : nil
                    }
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // ── "All" row ────────────────────────────────────────
            Toggle(isOn: Binding(
                get: { isAllSelected },
                set: { on in withAnimation { selectedCategoryIDs = on ? nil : [] } }
            )) {
                Label("category.all", systemImage: "tray.2.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.bottom, 4)

            // ── Per-category rows ────────────────────────────────
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        Toggle(isOn: Binding(
                            get: { selectedCategoryIDs?.contains(category.id) ?? true },
                            set: { on in
                                withAnimation {
                                    var current = selectedCategoryIDs ?? allCategoryIDs
                                    if on {
                                        current.insert(category.id)
                                    } else {
                                        current.remove(category.id)
                                    }
                                    // If every category manually checked, collapse back to "All"
                                    selectedCategoryIDs = current == allCategoryIDs ? nil : current
                                }
                            }
                        )) {
                            Text(LocalizedStringKey(category.name))
                                .font(.subheadline)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
        .background(Color(.systemBackground))
        // Shrink-wrap to content on iPad popover, cap height on long lists
        .frame(maxHeight: CGFloat(categories.count) * 52 + 120)
    }
}
