//
//  SmartListEditor.swift
//  Cooked
//
//  Created by Tomáš Kříž on 22.04.2026.
//

import SwiftUI

struct SmartListEditor: View {
    // Bind the continuous lines array from the section
    @Binding var lines: [InstructionLine]
    
    // Track which section this editor represents for exact FocusState matching
    let sectionIndex: Int
    
    var focusBinding: FocusState<RecipeFormView.Field?>.Binding
    let style: ListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Loop cleanly via dynamic bindings indices to prevent SwiftUI timeout crashes
            ForEach($lines.indices, id: \.self) { index in
                HStack(spacing: 8) {

                    // --- PREFIX ---
                    Text(prefix(for: index))
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .frame(width: 25, alignment: .trailing)

                    // --- TEXT FIELD ---
                    TextField("recipe.step_placeholder", text: $lines[index].text, axis: .vertical)
                        .focused(focusBinding, equals: .instruction(section: sectionIndex, row: index))
                }
            }
        }
    }

    private func addLine(after index: Int) {
        lines.insert(InstructionLine(text: ""), at: index + 1)
    }

    private func prefix(for index: Int) -> String {
        switch style {
        case .bulleted: return "•"
        case .numbered: return "\(index + 1)."
        }
    }

    enum ListStyle {
        case bulleted
        case numbered
    }
}
