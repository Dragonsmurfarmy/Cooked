//
//  TimerViewModel.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class TimerViewModel {
    private(set) var totalDuration: TimeInterval
    private(set) var remainingTime: TimeInterval
    private(set) var status: TimerStatus = .ready

    private var countdownTask: Task<Void, Never>?

    init(initialDuration: TimeInterval = 10 * 60) {
        totalDuration = initialDuration
        remainingTime = initialDuration
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return remainingTime / totalDuration
    }

    var isRunning: Bool {
        status == .running
    }

    var isPaused: Bool {
        status == .paused
    }

    var formattedTime: String {
        let totalSeconds = max(Int(remainingTime.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func selectDuration(_ duration: TimeInterval) {
        stop()
        totalDuration = duration
        remainingTime = duration
        status = .ready
    }

    func start() {
        guard (status == .ready || status == .paused), remainingTime > 0 else { return }

        status = .running
        countdownTask = Task {
            let clock = ContinuousClock()

            while !Task.isCancelled, remainingTime > 0 {
                try? await clock.sleep(for: .seconds(1))

                guard !Task.isCancelled else { return }
                remainingTime = max(remainingTime - 1, 0)
            }

            if remainingTime == 0 {
                status = .finished
            }
            countdownTask = nil
        }
    }

    func pause() {
        guard status == .running else { return }
        countdownTask?.cancel()
        countdownTask = nil
        status = .paused
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        remainingTime = totalDuration
        status = .ready
    }

    private func stop() {
        countdownTask?.cancel()
        countdownTask = nil
    }
    
    
    enum TimerStatus {
        case ready
        case running
        case paused
        case finished
    }
}

