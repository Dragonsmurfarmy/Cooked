//
//  SmartListEditor.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

import SwiftUI

struct SmartListEditor: View {
    // --- PROPERTIES ---
    var focusBinding: FocusState<RecipeFormView.Field?>.Binding
    @Binding var lines: [String]
    let style: ListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {

                    // --- PREFIX ---
                    Text(prefix(for: index))
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .frame(width: 25, alignment: .trailing)

                    // --- TEXT FIELD FOR STEP ---
                    TextField("recipe.step_placeholder", text: Binding(
                        get: { lines[index] },
                        set: { lines[index] = $0 }
                    ), axis: .vertical)
                    .focused(focusBinding, equals: .instruction(index))
                    .submitLabel(.next)
                    .onSubmit {
                        addLine(after: index) // Adds new line on submit
                        focusBinding.wrappedValue = .instruction(index + 1)
                    }
                }
            }
        }
    }

    
    private func addLine(after index: Int) {
        lines.insert("", at: index + 1)
    }

    private func removeLine(at index: Int) {
        lines.remove(at: index)
    }

    // --- Adds dot or number as prefix ---
    private func prefix(for index: Int) -> String {
        switch style {
        case .bulleted:
            return "•"
        case .numbered:
            return "\(index + 1)."
        }
    }

    // --- ENUMS ---
    enum ListStyle {
        case bulleted
        case numbered
    }
}
