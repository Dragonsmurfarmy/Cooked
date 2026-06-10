//
//  CheckboxStyle.swift
//  Cooked
//
//  Created by Tomáš Kříž on 27.05.2026.
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    // Replace standard toggle switch with checkbox/like appearance
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label.foregroundStyle(.primary)
                Spacer()
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square") // Show checkmard when on, empty square when off
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
