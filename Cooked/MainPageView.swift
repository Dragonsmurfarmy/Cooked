//  MainPageView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import SwiftUI

struct MainPageView: View {
    @Bindable var store: RecipeStore
    @State private var sortOption: RecipeSortOption = .name
    
    @State private var selectedCategoryIDs: Set<UUID>? = nil
    @State private var isShowingFilterPopover = false
    
    @State private var recipeToEdit: Recipe?
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @State private var isShowingEditPage = false
    @State var icn: String = "" // sorting icon
    
    private var allCategoryIDs: Set<UUID> {
        Set(store.categories.map { $0.id })
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var visibleRecipes: [Recipe] {
        
        let filtered: [Recipe]
        if let selected = selectedCategoryIDs {
                if selected.isEmpty { return [] }
                filtered = store.recipes.filter { recipe in
                    recipe.categories.contains { selected.contains($0.id) }
                }
            } else {
                filtered = store.recipes
            }
        
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .favorites:
            return filtered.sorted { $0.isFavorite && !$1.isFavorite }
        case .short:
            return filtered.sorted { $0.cookingTimeMinutes < $1.cookingTimeMinutes }
        case .long:
            return filtered.sorted { $0.cookingTimeMinutes > $1.cookingTimeMinutes }
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
                Picker("sort", selection: $sortOption) {
                    ForEach(RecipeSortOption.allCases) { option in
                        let icn: String = {
                                switch option {
                                case .name:
                                    return "textformat"
                                case .favorites:
                                    return "star.fill"
                                case .short:
                                    return "hourglass.tophalf.filled"
                                case .long:
                                    return "hourglass.bottomhalf.filled"
                                }
                            }()
                        Label(option.title, systemImage: icn).tag(option)
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
            

        }
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("main.recipes.title").font(.title2).fontWeight(.semibold)
            Group {
                VStack(spacing: 12) { ForEach(visibleRecipes) { recipe in recipeRowWrapper(recipe: recipe, isCard: false) } }
            }
            .animation(.default, value: visibleRecipes)
        }
    }
    
    @ViewBuilder
    private func recipeRowWrapper(recipe: Recipe, isCard: Bool) -> some View {
        NavigationLink { RecipeDetailView(recipe: recipe, store: store) } label: {
            CompactRecipeRow(recipe: recipe, store: store) { toggleFavorite(for: recipe.id) }
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
    @Environment(\.locale) private var locale
    
    @ViewBuilder
    private var categoriesView: some View {
        if recipe.categories.isEmpty {
            Text("category.lunch")
        } else if recipe.categories.count > 3 {
            Text("category.count_format \(recipe.categories.count)")
        } else {
            recipe.categories
                        .map { Text(LocalizedStringKey($0.name)) }
                        .reduce(nil as Text?) { acc, next in
                            acc.map { $0 + Text(", ") + next } ?? next
                        } ?? Text("")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            categoriesView
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Label(recipe.difficulty.title, systemImage: "chart.bar.fill")

                Label(formatCookingTime(recipe.cookingTimeMinutes), systemImage: "clock")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func formatCookingTime(_ minutes: Int) -> String {
        if minutes < 5 {
            return "<5 min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }

        if remainingMinutes == 0 {
            return "\(hours) h"
        }

        return "\(hours) h \(remainingMinutes) min"
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
    case name, favorites, short, long
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .name: "main.sort_option.name"
        case .favorites: "main.sort_option.favorites"
        case .long: "main.sort_option.long"
        case .short: "main.sort_option.short"   
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
