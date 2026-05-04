//
//  TimerView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import ActivityKit
import UIKit
import AVFoundation

struct TimerView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    // Make all values start at 0
    @State private var selectedHours = 0
    @State private var selectedMinutes = 0
    @State private var selectedSeconds = 0
    
    @State private var showSoundPicker = false

    // Transform selected time to seconds
    private var selectedDuration: TimeInterval {
        TimeInterval(selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds)
    }
    
    // Dont show picker when timer is running
    private var shouldShowPicker: Bool {
        viewModel.status == .ready || viewModel.status == .finished
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // show either Picker(Selection) or Progress(timer) part
                    if shouldShowPicker {
                        pickerSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        progressSection
                            .transition(.scale.combined(with: .opacity))
                    }
                    buttonLine // Reset, Play and Sound selection buttons
                    tipsSection
                }
                .padding(20)
            }
        }
        .navigationTitle("timer.navigation.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.25), value: shouldShowPicker)
        .onChange(of: selectedDuration) { _, newValue in
            guard !viewModel.isRunning else { return }
            viewModel.selectDuration(newValue)
        }
        .onAppear {
            syncPickerSelection(with: viewModel.totalDuration)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .blue]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: 240, height: 240)
        }
        .frame(maxWidth: 240)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var buttonLine: some View {
        HStack(spacing: 16) {
            // --- RESET ---
            timerActionButton(
                titleKey: "timer.action.reset",
                systemImage: "arrow.counterclockwise",
                tint: Color(.secondarySystemBackground)
            ) {
                viewModel.reset()
                syncPickerSelection(with: viewModel.totalDuration)
            }
            .disabled(shouldShowPicker) // Disable clicking reset when no timer is active
            .opacity(shouldShowPicker ? 0.5 : 1.0) // Make the button dim when disabled
            
            // --- PAUSE/PLAY ---
            timerActionButton(
                titleKey: viewModel.isRunning ? "timer.action.pause" : "timer.action.play",
                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                tint: .blue
            ) {
                if viewModel.isRunning {
                    viewModel.pause()
                } else {
                    if viewModel.remainingTime == viewModel.totalDuration {
                        viewModel.selectDuration(selectedDuration)
                    }
                    viewModel.start()
                }
            }

            // --- SOUND ---
            timerActionButton(
                titleKey: "timer.action.sound",
                systemImage: "bell.fill",
                tint: .blue
            ) {
                showSoundPicker = true
            }
            .sheet(isPresented: $showSoundPicker) {
                SoundPickerView(viewModel: viewModel)
            }
        }
    }

    private func timerActionButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(titleKey)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint)
            .foregroundStyle(tint == Color(.secondarySystemBackground) ? Color.primary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    
    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timer.picker.title")
                .font(.headline)

            HStack(spacing: 0) {
                unitColumn(selection: $selectedHours, range: Array(0...23), label: "timer.unit.hours")
                unitColumn(selection: $selectedMinutes, range: Array(0...59), label: "timer.unit.minutes")
                unitColumn(selection: $selectedSeconds, range: Array(0...59), label: "timer.unit.seconds")
            }
            .frame(height: 180)
            .allowsHitTesting(!viewModel.isRunning)
            .opacity(viewModel.isRunning ? 0.55 : 1)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func unitColumn(selection: Binding<Int>, range: [Int], label: LocalizedStringKey) -> some View {
        GeometryReader { geometry in
                VStack(spacing: 0) {
                    LoopingTimePicker(selection: selection, range: range)
                        .frame(width: geometry.size.width - 4)
                        .clipped()
                    
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.top, -10)
                }
                .frame(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity)
        
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isRunning {
                Label("timer.tip.pause", systemImage: "pause.circle")
            } else if viewModel.isPaused {
                Label("timer.tip.resume", systemImage: "play.circle")
            } else {
                Label("timer.tip.select_duration", systemImage: "timer")
                Label("timer.tip.start", systemImage: "play")
            }
            Label("timer.tip.reset", systemImage: "gobackward")
            Label("timer.tip.sound", systemImage: "bell.fill")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: 240)
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func syncPickerSelection(with duration: TimeInterval) {
        let totalSeconds = max(Int(duration.rounded(.down)), 0)
        selectedHours = totalSeconds / 3600
        selectedMinutes = (totalSeconds % 3600) / 60
        selectedSeconds = totalSeconds % 60
    }
}


private struct LoopingTimePicker: UIViewRepresentable {
    @Binding var selection: Int
    let range: [Int]
    let repeatCount = 200

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let middleRow = (range.count * repeatCount) / 2 + selection
        picker.selectRow(middleRow, inComponent: 0, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        let currentRow = uiView.selectedRow(inComponent: 0)
        if currentRow % range.count != selection {
            let newRow = (range.count * repeatCount) / 2 + selection
            uiView.selectRow(newRow, inComponent: 0, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: LoopingTimePicker
        init(parent: LoopingTimePicker) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.range.count * parent.repeatCount
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 45 }
        
        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            let value = row % parent.range.count
            return NSAttributedString(
                string: String(format: "%02d", value),
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
            )
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let value = row % parent.range.count
            parent.selection = value
            
            // Okamžité vycentrování pro plynulý scroll (bez animace)
            let middleRow = (parent.range.count * parent.repeatCount) / 2 + value
            pickerView.selectRow(middleRow, inComponent: 0, animated: false)
        }
    }
}
