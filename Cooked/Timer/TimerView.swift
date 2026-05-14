//
//  TimerView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
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
                    // Show either Picker(Selection) or Progress(timer) part
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
                tint: Color(.secondarySystemBackground),
                hasOutline: true
            ) {
                viewModel.reset()
                syncPickerSelection(with: viewModel.totalDuration)
            }
            .disabled(shouldShowPicker) // Disable clicking reset when no timer is active
            .opacity(shouldShowPicker ? 0.5 : 1.0) // Make the button dim when disabled
            
            // --- PAUSE/PLAY ---
            timerActionButton(
                // Choose either Play or Pause visual, depending whether timer is running or not
                titleKey: viewModel.isAlarmActive
                    ? "timer.action.stop"
                    : (viewModel.isRunning ? "timer.action.pause" : "timer.action.play"),

                systemImage: viewModel.isAlarmActive
                    ? "stop.fill"
                    : (viewModel.isRunning ? "pause.fill" : "play.fill"),

                tint: .blue
            ) {
                if viewModel.isAlarmActive { // When alarm is ringing, make button stop it
                    viewModel.stopAlarm()
                } else if viewModel.isRunning { // If timer is running, pause it
                    viewModel.pause()
                } else { // Start timer logic
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
                tint: Color(.secondarySystemBackground),
                hasOutline: true
            ) {
                // Show sound selection menu
                showSoundPicker = true
            }
            .sheet(isPresented: $showSoundPicker) {
                SoundPickerView(viewModel: viewModel)
            }
        }
    }

    // Timer Buttons factory
    private func timerActionButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        hasOutline: Bool = false,
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
            .overlay {
                if hasOutline {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // Timer time choosing section
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

    // Factory for the rotating wheel picker columns
    private func unitColumn(selection: Binding<Int>, range: [Int], label: LocalizedStringKey) -> some View {
        GeometryReader { geometry in
                VStack(spacing: 0) {
                    LoopingTimePicker(selection: selection, range: range)
                        .frame(width: geometry.size.width - 4, height: 150)
                        .clipped()
                    
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .frame(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity)
    }

    // Factory for the tips section text
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
                    Group {
                        if viewModel.isRunning {
                            tipRow(title: "timer.tip.pause", icon: "pause.circle")
                        } else if viewModel.isPaused {
                            tipRow(title: "timer.tip.resume", icon: "play.circle")
                        } else {
                            tipRow(title: "timer.tip.select_duration", icon: "timer")
                            tipRow(title: "timer.tip.start", icon: "play")
                        }
                        tipRow(title: "timer.tip.reset", icon: "gobackward")
                        tipRow(title: "timer.tip.sound", icon: "bell.fill")
                        tipRow(title: "timer.tip.notification", icon: "bell.slash")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // Synces clock with remaining time
    private func syncPickerSelection(with duration: TimeInterval) {
        let totalSeconds = max(Int(duration.rounded(.down)), 0)
        selectedHours = totalSeconds / 3600
        selectedMinutes = (totalSeconds % 3600) / 60
        selectedSeconds = totalSeconds % 60
    }
    
    private func tipRow(title: LocalizedStringKey, icon: String) -> some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20, alignment: .center) // Fixed size for text alignment
                Text(title)
            }
        }
}

private struct LoopingTimePicker: UIViewRepresentable {
    @Binding var selection: Int
    let range: [Int]
    let repeatCount = 200
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // Create UIPickerView, link it with Coordinator and set Picker to start in middle of the picking list for illusion of infinite scrolling
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let middleRow = (range.count * repeatCount) / 2 + selection
        picker.selectRow(middleRow, inComponent: 0, animated: false)
        return picker
    }
    
    // Synces UI and data
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        let currentRow = uiView.selectedRow(inComponent: 0)
        if currentRow % range.count != selection {
            let newRow = (range.count * repeatCount) / 2 + selection
            uiView.selectRow(newRow, inComponent: 0, animated: false)
        }
    }
    
    // Adapter between SwiftUI and UIKit
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
            
            // Centering for continuous animation
            let middleRow = (parent.range.count * parent.repeatCount) / 2 + value
            pickerView.selectRow(middleRow, inComponent: 0, animated: false)
        }
    }
    
}

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        VStack {
            Text(message)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Capsule().fill(.red))
                .shadow(radius: 8)
                .padding(.top, 20) 
            
            Spacer()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)

        .allowsHitTesting(false)
    }
}
