//
//  RecipeDetailView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import SwiftUI
import UIKit
import PhotosUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var recipe: Recipe
    @State private var recipeToEdit: Recipe?
    @State private var isShowingEditPage = false
    @State private var selectedPortions: Int
    @State private var didLongPressDecrement = false
    @State private var didLongPressIncrement = false
    @State private var showDeleteConfirmation = false
    @Bindable var store: RecipeStore
    private let minPortions = 1
    private let maxPortions = 50
    
    // MARK: Voice
    @State private var voice = VoiceController()
    // Flat list of all non-empty instruction steps across all sections, built once.
    private var allSteps: [(sectionIndex: Int, stepIndex: Int, line: InstructionLine)] {
        var result: [(Int, Int, InstructionLine)] = []
        for (si, section) in recipe.sections.enumerated() {
            let nonEmpty = section.instructions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for (li, line) in nonEmpty.enumerated() {
                result.append((si, li, line))
            }
        }
        return result
    }
    // Index into allSteps that voice commands navigate
    @State private var currentStepIndex: Int = 0
    // Scroll anchor IDs — each step gets "step-\(line.id)"
    private func stepAnchorID(_ line: InstructionLine) -> String { "step-\(line.id.uuidString)" }
    private let topAnchorID = "recipe-top"
 
    init(recipe: Recipe, store: RecipeStore) {
        self._recipe = State(initialValue: recipe)
        self.store = store
        self._selectedPortions = State(initialValue: store.settings.defaultPortions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // --- IMAGE SECTION ---
                RecipeImage(imageData: recipe.imageData)
                    .id(recipe.imageData)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(recipe.categories.first?.name ?? "category.lunch"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())

                        Label(recipe.difficulty.title, systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(recipe.name)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)

                    Label(formatCookingTime(recipe.cookingTimeMinutes), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

                    Button {
                        handleDecrementTap()
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                didLongPressDecrement = true
                                jumpDecrementPortions()
                            }
                    )

                    Button {
                        handleIncrementTap()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                didLongPressIncrement = true
                                jumpIncrementPortions()
                            }
                    )
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // --- INGREDIENT SECTION ---
                VStack(alignment: .leading, spacing: 20) {
                    Label("ingredients", systemImage: "list.bullet")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    ForEach(recipe.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if let sectionName = section.name, !sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(sectionName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.top, 4)
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(section.ingredients) { ingredient in
                                    HStack(alignment: .firstTextBaseline) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundStyle(.tint)
                                            .padding(.bottom, 4)
                                                                
                                        Text(ingredient.name)
                                            .font(.body)
                                                                
                                        Spacer()
                                                                
                                        Text(calculateAmount(for: ingredient))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                                                
                                        Text(LocalizedStringKey(ingredient.unit))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if ingredient != section.ingredients.last {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                }

                Divider()

                // --- INSTRUCTION SECTION ---
                VStack(alignment: .leading, spacing: 20) {
                    Label("instructions", systemImage: "frying.pan")
                        .font(.title3)
                        .fontWeight(.bold)

                    ForEach(recipe.sections) { section in
                        let sectionInstructions = section.instructions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        
                        if !sectionInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                if let sectionName = section.name, !sectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(sectionName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .padding(.top, 4)
                                }
                                
                                ForEach(sectionInstructions) { instructionLine in
                                    if let localIndex = sectionInstructions.firstIndex(where: { $0.id == instructionLine.id }) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(localIndex + 1).")
                                                .fontWeight(.bold)
                                                .foregroundStyle(.tint)
                                                
                                            Text(instructionLine.text)
                                                .font(.body)
                                                .lineSpacing(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // --- TIPS SECTION ---
                if let tips = recipe.tips, !tips.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()

                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            Text("tips.title")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)

                        LinkedTipsText(tips: tips, store: store)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 120)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button() {
                    showDeleteConfirmation = true
                } label: {
                    Label("button.delete", systemImage: "trash")
                    .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.1))
                .labelStyle(.titleAndIcon)
                
                Button() {
                    isShowingEditPage = true
                } label: {
                    Label("button.edit", systemImage: "pencil")
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                .fixedSize()
            }
        }
        .alert("delete.question", isPresented: $showDeleteConfirmation) {
            Button("button.delete", role: .destructive) {
                if let index = store.recipes.firstIndex(where: { $0.id == recipe.id }) {
                    store.deleteRecipe(at: IndexSet(integer: index))
                    dismiss()
                }
            }
            Button("button.cancel", role: .cancel) {
            }
        } message: {
            Text("delete.question")
        }
        .navigationDestination(isPresented: $isShowingEditPage) {
            RecipeFormView(store: store, recipeToEdit: recipe) { updatedRecipe in
                self.recipe = updatedRecipe
                isShowingEditPage = false
            }
        }
    }
    
    // MARK: - Voice status bar
 
    private var voiceStatusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(Color.accentColor)
 
            VStack(alignment: .leading, spacing: 1) {
                Text("voice.listening")
                    .font(.caption.weight(.semibold))
                if !voice.lastTranscript.isEmpty {
                    Text(voice.lastTranscript)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
 
            Spacer()
 
            if let stepInfo = currentStepInfo {
                Text(stepInfo)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
 
    private var currentStepInfo: String? {
        let steps = allSteps
        guard !steps.isEmpty else { return nil }
        return "\(currentStepIndex + 1) / \(steps.count)"
    }
 
    // MARK: - Voice setup
 
    private func setupVoice(proxy: ScrollViewProxy) {
        voice.onCommand = { [self] command in
            handleVoiceCommand(command, proxy: proxy)
        }
    }
 
    private func handleVoiceCommand(_ command: VoiceCommand, proxy: ScrollViewProxy) {
        let steps = allSteps
        guard !steps.isEmpty else { return }
 
        switch command {
        case .nextStep:
            let next = min(currentStepIndex + 1, steps.count - 1)
            currentStepIndex = next
            withAnimation {
                proxy.scrollTo(stepAnchorID(steps[next].line), anchor: .top)
            }
 
        case .previousStep:
            let prev = max(currentStepIndex - 1, 0)
            currentStepIndex = prev
            withAnimation {
                proxy.scrollTo(stepAnchorID(steps[prev].line), anchor: .top)
            }
 
        case .repeatStep:
            withAnimation {
                proxy.scrollTo(stepAnchorID(steps[currentStepIndex].line), anchor: .top)
            }
 
        case .scrollTop:
            currentStepIndex = 0
            withAnimation {
                proxy.scrollTo(topAnchorID, anchor: .top)
            }
        
        case .scrollBottom:
                currentStepIndex = 0
                withAnimation {
                    proxy.scrollTo(topAnchorID, anchor: .top)
                }
        case .scrollUp:
            currentStepIndex = 0
            withAnimation {
                proxy.scrollTo(topAnchorID, anchor: .top)
            }
            
        case .scrollDown:
            currentStepIndex = 0
            withAnimation {
                proxy.scrollTo(topAnchorID, anchor: .top)
            }
 
        case .unknown:
            break
        }
    }
 
    private func isCurrentVoiceStep(_ line: InstructionLine) -> Bool {
        guard voice.isListening else { return false }
        let steps = allSteps
        guard currentStepIndex < steps.count else { return false }
        return steps[currentStepIndex].line.id == line.id
    }

    
    // MARK: - Helper Functions
    
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

    private func handleDecrementTap() {
        if didLongPressDecrement {
            didLongPressDecrement = false
            return
        }
        selectedPortions = max(minPortions, selectedPortions - 1)
    }

    private func handleIncrementTap() {
        if didLongPressIncrement {
            didLongPressIncrement = false
            return
        }
        selectedPortions = min(maxPortions, selectedPortions + 1)
    }

    private func jumpDecrementPortions() {
        if selectedPortions > recipe.defaultPortions {
            selectedPortions = recipe.defaultPortions
        } else {
            selectedPortions = minPortions
        }
    }

    private func jumpIncrementPortions() {
        if selectedPortions < recipe.defaultPortions {
            selectedPortions = recipe.defaultPortions
        } else {
            selectedPortions = maxPortions
        }
    }

    private func calculateAmount(for ingredient: Ingredient) -> String {
        let baseAmount = Double(ingredient.amount) / Double(recipe.defaultPortions)
        let finalAmount = baseAmount * Double(selectedPortions)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
            
        return formatter.string(from: NSNumber(value: finalAmount)) ?? "\(finalAmount)"
    }
}

// MARK: - Linked Tips Renderer

// Parses [[word|uuid]] tokens in tips text and renders linked words as tappable accent-coloured text that navigates to the target recipe.
private struct LinkedTipsText: View {
    let tips: String
    let store: RecipeStore
    @State private var linkedRecipe: Recipe?

    var body: some View {
        Text(buildAttributedString())
            .italic()
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { url in
                guard
                    url.scheme == "cooked",
                    url.host == "recipe",
                    let uuidStr = url.pathComponents.last,
                    let uuid = UUID(uuidString: uuidStr),
                    let target = store.recipes.first(where: { $0.id == uuid })
                else { return .discarded }
                linkedRecipe = target
                return .handled
            })
            .navigationDestination(item: $linkedRecipe) { target in
                RecipeDetailView(recipe: target, store: store)
            }
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        // Matches [[display word|uuid-string]]
        let pattern = /\[\[([^\|]+)\|([^\]]+)\]\]/
        var remaining = tips[...]

        while let match = remaining.firstMatch(of: pattern) {
            // Plain text segment before this match
            let prefix = String(remaining[remaining.startIndex..<match.range.lowerBound])
            if !prefix.isEmpty {
                result += AttributedString(prefix)
            }

            let word = String(match.output.1)
            let uuidStr = String(match.output.2)

            if let uuid = UUID(uuidString: uuidStr),
               store.recipes.contains(where: { $0.id == uuid }) {
                // Valid link — style as tappable
                var seg = AttributedString(word)
                seg.link = URL(string: "cooked://recipe/\(uuidStr)")
                // .link attribute automatically renders in accent colour + underline
                result += seg
            } else {
                // Broken link (recipe was deleted) — show word as plain secondary text
                var seg = AttributedString(word)
                seg.foregroundColor = .secondary
                result += seg
            }

            remaining = remaining[match.range.upperBound...]
        }

        // Any trailing plain text
        if !remaining.isEmpty {
            result += AttributedString(String(remaining))
        }

        return result
    }
}
