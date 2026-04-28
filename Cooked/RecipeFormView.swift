//
//  MainPage.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import UIKit
import PhotosUI

enum RecipeCategory: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case dessert
    case drink
    case cake

    var id: Self { self }
    
    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .dessert: 3
        case .drink: 4
        case .cake: 5
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .breakfast: "category.breakfast"
        case .lunch: "category.lunch"
        case .dinner: "category.dinner"
        case .dessert: "category.dessert"
        case .drink: "category.drink"
        case .cake: "category.cake"
        }
    }
}


struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var category: RecipeCategory = .dinner
    @State private var recipeDescription = ""
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    
    let onSave: (Recipe) -> Void // Saving behaviour will be handled elsewhere

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 12) {
                            RecipeSelectedImagePreview(imageData: selectedImageData)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Image")
                                    .foregroundStyle(.primary)
                                Text(selectedImageData == nil ? "Choose from gallery" : "Tap to change photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    TextField("recipe.name", text: $name)
                    Picker("recipe.category", selection: $category) {
                        ForEach(RecipeCategory.allCases) { cat in
                            Text(cat.title)
                                .tag(cat)
                        }
                    }
                    TextField("recipe.description", text: $recipeDescription)

                }
                
                Section("recipe.ingredients") {
                    AutoListTextView(text: $ingredients, listStyle: .bulleted)
                        .frame(minHeight: 160)
                }

                Section("recipe.instructions") {
                    AutoListTextView(text: $instructions, listStyle: .numbered)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("label.new")
            .task(id: selectedPhoto) {
                await loadSelectedPhoto()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") {
                        let recipe = Recipe(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            recipeDescription: recipeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                            ingredients: ingredients.trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                            isFavorite: isFavorite ? true : false,
                            imageData: selectedImageData
                        )
                        onSave(recipe)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }

        do {
            selectedImageData = try await selectedPhoto.loadTransferable(type: Data.self)
        } catch {
            selectedImageData = nil
        }
    }
}

private struct RecipeSelectedImagePreview: View {
    let imageData: Data?

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AutoListTextView: UIViewRepresentable {
    @Binding var text: String
    let listStyle: ListStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, listStyle: listStyle)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.text = $text

        if uiView.text != text {
            uiView.text = text
        }
    }

    enum ListStyle {
        case bulleted
        case numbered

        var initialPrefix: String {
            switch self {
            case .bulleted:
                return "• "
            case .numbered:
                return "1. "
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        let listStyle: ListStyle

        init(text: Binding<String>, listStyle: ListStyle) {
            self.text = text
            self.listStyle = listStyle
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard textView.text.isEmpty else { return }
            textView.text = listStyle.initialPrefix
            text.wrappedValue = textView.text
            moveCursorToEnd(of: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard replacement == "\n" else { return true }

            let currentText = textView.text ?? ""
            guard let textRange = Range(range, in: currentText) else { return true }
            let paragraphRange = currentText.lineRange(for: textRange.lowerBound..<textRange.lowerBound)
            let currentLine = String(currentText[paragraphRange])
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.isEmpty || trimmedLine == listStyle.initialPrefix.trimmingCharacters(in: .whitespaces) {
                return true
            }

            let nextPrefix = nextPrefix(for: trimmedLine)
            let updatedText = (currentText as NSString).replacingCharacters(in: range, with: "\n\(nextPrefix)")
            textView.text = updatedText
            text.wrappedValue = updatedText

            let newCursorLocation = range.location + 1 + nextPrefix.count
            if let position = textView.position(from: textView.beginningOfDocument, offset: newCursorLocation) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
            }

            return false
        }

        private func nextPrefix(for currentLine: String) -> String {
            switch listStyle {
            case .bulleted:
                return "• "
            case .numbered:
                let number = currentLine
                    .split(separator: ".", maxSplits: 1)
                    .first
                    .flatMap { Int($0) } ?? 1
                return "\(number + 1). "
            }
        }

        private func moveCursorToEnd(of textView: UITextView) {
            let end = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: end, to: end)
        }

    }
}
