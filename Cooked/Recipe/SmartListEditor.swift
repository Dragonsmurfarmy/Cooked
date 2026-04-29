//
//  SmartListEditor.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

import SwiftUI

struct SmartListEditor: View {
    @Binding var lines: [String]
    let style: ListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {

                    Text(prefix(for: index))
                        .foregroundStyle(.secondary)

                    TextField("", text: Binding(
                        get: { lines[index] },
                        set: { lines[index] = $0 }
                    ))
                    .onSubmit {
                        addLine(after: index)
                    }
                    .onChange(of: lines[index]) { _, newValue in
                        if newValue.isEmpty && lines.count > 1 {
                            removeLine(at: index)
                        }
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

    private func prefix(for index: Int) -> String {
        switch style {
        case .bulleted:
            return "•"
        case .numbered:
            return "\(index + 1)."
        }
    }

    enum ListStyle {
        case bulleted
        case numbered
    }
}
