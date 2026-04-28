//
//  TimerView.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import SwiftUI
import UIKit

struct TimerView: View {
    @Environment(TimerViewModel.self) private var viewModel // To make sure timer persists even when user leaves screen
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHours = 0
    @State private var selectedMinutes = 10
    @State private var selectedSeconds = 0

    private var selectedDuration: TimeInterval {
        TimeInterval(selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds)
    }

    private var shouldShowPicker: Bool {
        viewModel.status == .ready || viewModel.status == .finished
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    if shouldShowPicker {
                        pickerSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        progressSection
                            .transition(.scale.combined(with: .opacity))
                    }
                    buttonLine
                    tipsSection
                }
                .padding(20)
            }

            bottomNavigationBar
        }
        .navigationTitle("timer.navigation.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.25), value: shouldShowPicker)
        .onAppear {
            syncPickerSelection(with: viewModel.totalDuration)
        }
        .onChange(of: selectedDuration) { _, newValue in
            guard !viewModel.isRunning else { return }
            viewModel.selectDuration(newValue)
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
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var buttonLine: some View {
        HStack(spacing: 16) {
            timerActionButton(
                titleKey: "timer.action.reset",
                systemImage: "arrow.counterclockwise",
                tint: Color(.secondarySystemBackground)
            ) {
                viewModel.reset()
            }

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

            timerActionButton(
                titleKey: "timer.action.sound",
                systemImage: "bell.fill",
                tint: .blue
            ) {
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

    private var bottomNavigationBar: some View {
        HStack {
            TimerNavigationBarButton(titleKey: "navigation.voice_regime", systemImage: "mic")
            TimerNavigationBarButton(titleKey: "navigation.timer", systemImage: "timer", isSelected: true)
            TimerNavigationBarButton(titleKey: "navigation.home", systemImage: "house.fill") {
                dismiss()
            }
            TimerNavigationBarButton(titleKey: "navigation.add", systemImage: "plus.circle")
            TimerNavigationBarButton(titleKey: "navigation.settings", systemImage: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timer.picker.title")
                .font(.headline)

            LoopingTimePicker(
                hours: $selectedHours,
                minutes: $selectedMinutes,
                seconds: $selectedSeconds
            )
            .frame(height: 180)
            .clipped()
            .allowsHitTesting(!viewModel.isRunning)
            .opacity(viewModel.isRunning ? 0.55 : 1)

            HStack {
                Text("timer.unit.hours")
                    .frame(maxWidth: .infinity)
                Text("timer.unit.minutes")
                    .frame(maxWidth: .infinity)
                Text("timer.unit.seconds")
                    .frame(maxWidth: .infinity)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct TimerNavigationBarButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
    }
}

private struct LoopingTimePicker: UIViewRepresentable {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    private let hourRange = Array(0...99)
    private let minuteSecondRange = Array(0...59)
    private let repeatCount = 200

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        context.coordinator.selectCurrentValues(in: picker, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncSelectionIfNeeded(in: uiView)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: LoopingTimePicker

        init(parent: LoopingTimePicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            3
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0:
                parent.hourRange.count * parent.repeatCount
            case 1, 2:
                parent.minuteSecondRange.count * parent.repeatCount
            default:
                0
            }
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            96
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            40
        }

        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            let value = valueForRow(row, component: component)
            return NSAttributedString(
                string: String(format: "%02d", value),
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
            )
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let value = valueForRow(row, component: component)

            switch component {
            case 0:
                parent.hours = value
            case 1:
                parent.minutes = value
            case 2:
                parent.seconds = value
            default:
                break
            }

            recenterIfNeeded(in: pickerView, component: component, value: value)
        }

        func selectCurrentValues(in pickerView: UIPickerView, animated: Bool) {
            pickerView.selectRow(centeredRow(for: parent.hours, component: 0), inComponent: 0, animated: animated)
            pickerView.selectRow(centeredRow(for: parent.minutes, component: 1), inComponent: 1, animated: animated)
            pickerView.selectRow(centeredRow(for: parent.seconds, component: 2), inComponent: 2, animated: animated)
        }

        func syncSelectionIfNeeded(in pickerView: UIPickerView) {
            let expectedHourRow = centeredRow(for: parent.hours, component: 0)
            let expectedMinuteRow = centeredRow(for: parent.minutes, component: 1)
            let expectedSecondRow = centeredRow(for: parent.seconds, component: 2)

            if pickerView.selectedRow(inComponent: 0) != expectedHourRow {
                pickerView.selectRow(expectedHourRow, inComponent: 0, animated: false)
            }

            if pickerView.selectedRow(inComponent: 1) != expectedMinuteRow {
                pickerView.selectRow(expectedMinuteRow, inComponent: 1, animated: false)
            }

            if pickerView.selectedRow(inComponent: 2) != expectedSecondRow {
                pickerView.selectRow(expectedSecondRow, inComponent: 2, animated: false)
            }
        }

        private func valueForRow(_ row: Int, component: Int) -> Int {
            switch component {
            case 0:
                row % parent.hourRange.count
            case 1, 2:
                row % parent.minuteSecondRange.count
            default:
                0
            }
        }

        private func centeredRow(for value: Int, component: Int) -> Int {
            let itemCount = component == 0 ? parent.hourRange.count : parent.minuteSecondRange.count
            let middle = itemCount * parent.repeatCount / 2
            return middle + value
        }

        private func recenterIfNeeded(in pickerView: UIPickerView, component: Int, value: Int) {
            let centered = centeredRow(for: value, component: component)
            if pickerView.selectedRow(inComponent: component) != centered {
                pickerView.selectRow(centered, inComponent: component, animated: false)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimerView()
    }
    .environment(TimerViewModel())
}
