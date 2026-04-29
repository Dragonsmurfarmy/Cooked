import Foundation
import Observation
import ActivityKit
import UserNotifications

@MainActor
@Observable
final class TimerViewModel {

    private(set) var totalDuration: TimeInterval
    private(set) var remainingTime: TimeInterval
    private var endDate: Date?

    private var activity: Activity<TimerActivityAttributes>?
    private(set) var status: TimerStatus = .ready

    private var countdownTask: Task<Void, Never>?

    init(initialDuration: TimeInterval = 10 * 60) {
        self.totalDuration = initialDuration
        self.remainingTime = initialDuration
    }


    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return remainingTime / totalDuration
    }

    var isRunning: Bool { status == .running }
    var isPaused: Bool { status == .paused }

    var formattedTime: String {
        let totalSeconds = max(Int(remainingTime), 0)
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
        guard status == .ready || status == .paused else { return }

        status = .running
        endDate = Date().addingTimeInterval(remainingTime)

        if let endDate {
            startLiveActivity(endDate: endDate)
            scheduleNotification(for: endDate)
        }

        startCountdown()
    }

    func pause() {
        guard status == .running else { return }
        countdownTask?.cancel()
        countdownTask = nil

        if let endDate {
            remainingTime = max(endDate.timeIntervalSinceNow, 0)
        }

        status = .paused
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil

        remainingTime = totalDuration
        endDate = nil
        status = .ready
    }

    private func stop() {
        countdownTask?.cancel()
        countdownTask = nil
    }


    private func startCountdown() {
        countdownTask?.cancel()

        countdownTask = Task {
            while !Task.isCancelled, let endDate{
                let remaining = max(endDate.timeIntervalSinceNow, 0)
                let seconds = max(Int(ceil(remaining)), 0)
                
                await MainActor.run {
                                self.remainingTime = TimeInterval(seconds)
                            }
                
                if(remaining <= 0) {
                    status = .finished
                    stopLiveActivity()
                    reset()
                    break
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }


    private func startLiveActivity(endDate: Date) {
        let attributes = TimerActivityAttributes(title: "Cooking Timer")
        let state = TimerActivityAttributes.ContentState(endDate: endDate)

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("X - Live Activity failed:", error)
        }
    }

    private func stopLiveActivity() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }


    private func scheduleNotification(for endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.body = "Your cooking timer is done."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(endDate.timeIntervalSinceNow, 1),
                repeats: false
            )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        
        UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Notification failed:", error)
                } else {
                    print("✅ Notification scheduled for", endDate)
                }
            }
        
    }


    enum TimerStatus {
        case ready
        case running
        case paused
        case finished
    }
}
