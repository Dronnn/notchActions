//
//  StepperField.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - StepperField

/// a compact "[−] N [+]" control: minus/plus buttons that step the bound int within a range and a
/// narrow text field that lets the value be typed; a typed value is clamped into range on commit, so it
/// never crashes or escapes the bounds. the −/+ buttons disable at the range bounds.
struct StepperField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    /// mirrors the bound value as text so the field is freely typable; committed back (clamped) on change.
    @State private var text = ""

    /// tracks the text field's keyboard focus so a typed value is committed when focus leaves (e.g. on Done).
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                Button("Decrease", systemImage: "minus") { step(-1) }
                    .disabled(value <= range.lowerBound)

                TextField(title, text: $text)
                    .labelsHidden()
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { commit() }

                Button("Increase", systemImage: "plus") { step(1) }
                    .disabled(value >= range.upperBound)
            }
            .labelStyle(.iconOnly)
            .buttonRepeatBehavior(.enabled)
        }
        .onAppear { syncText() }
        .onChange(of: value) { syncText() }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
    }

    // MARK: - Helpers

    private func step(_ delta: Int) {
        value = clamp(value + delta)
    }

    /// parse the typed text, clamp into range, and reflect the result back into the field.
    private func commit() {
        if let typed = Int(text) {
            value = clamp(typed)
        }
        syncText()
    }

    private func syncText() {
        text = String(value)
    }

    private func clamp(_ raw: Int) -> Int {
        min(max(raw, range.lowerBound), range.upperBound)
    }
}
