import Foundation
import Observation
import ActivityKit
import UserNotifications
import AVFoundation
import UIKit


@MainActor
@Observable
final class TimerViewModel {

    private(set) var totalDuration: TimeInterval
    private(set) var remainingTime: TimeInterval
    private var endDate: Date?
    private var alarmPlayer: AVAudioPlayer?
    private(set) var isAlarmActive: Bool = false
    
    private var activity: Activity<TimerActivityAttributes>?
    private(set) var status: TimerStatus = .ready

    private var countdownTask: Task<Void, Never>?
    private let notificationIdentifier = "timer-finished"
    
    var errorMessage: String? = nil
    var selectedSoundUrl: URL?
    var availableSounds: [TimerSoundFile] = [] {
        didSet {
            if selectedSoundUrl == nil {
                selectedSoundUrl = availableSounds.first?.url
            }
        }
    }

   

    init(initialDuration: TimeInterval = 0) {
        self.totalDuration = initialDuration
        self.remainingTime = initialDuration
        refreshAvailableSounds()
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
        
        if status == .finished {
            reset()
        }
        
        guard status == .ready || status == .paused else { return }

        status = .running
        // Keep one absolute end date so countdown, Live Activity, and notifications all derive from the same place
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
        
        cancelScheduledNotification()

        if let endDate {
            remainingTime = max(endDate.timeIntervalSinceNow, 0)
        }

        status = .paused
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        
        cancelScheduledNotification()
        
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
            // Recompute against the end date instead of subtracting fixed ticks so
            // the timer stays accurate even if this task is delayed.
            while !Task.isCancelled, let endDate{
                let remaining = max(endDate.timeIntervalSinceNow, 0)
                let seconds = max(Int(ceil(remaining)), 0)
                
                await MainActor.run {
                                self.remainingTime = TimeInterval(seconds)
                            }
                
                if remaining <= 0 {
                    status = .finished

                    if UIApplication.shared.applicationState == .active {
                        isAlarmActive = true
                        startAlarmSound()
                    } else {
                        isAlarmActive = false
                    }

                    await stopLiveActivity()
                    stop()
                    break
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }


    private func startLiveActivity(endDate: Date) {
        let attributes = TimerActivityAttributes(title: "Cooking Timer")
        let state = TimerActivityAttributes.ContentState(endDate: endDate)
        
        let staleDate = endDate.addingTimeInterval(1)

        do {
            activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: state, staleDate: staleDate),
                        pushType: nil
                    )
            
            Task {
                // End the Live Activity explicitly once the timer expires.
                let duration = max(endDate.timeIntervalSinceNow, 0)
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await stopLiveActivity() // Hide widget
            }
            
        } catch {
            
        }
    }

    private func stopLiveActivity() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }


    private func scheduleNotification(for endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.body = String(localized: "notification.body")
        if let url = selectedSoundUrl {
            let name = url.lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(name))
        } else {
            content.sound = .default
        }

        // Notification trigger expects a duration from now, not an absolute date.
        let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(endDate.timeIntervalSinceNow, 1),
                repeats: false
            )

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
        
    }
    
    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
    }
    
    func setCustomSound(url: URL) {
        selectedSoundUrl = url
    }
    
    public func stopAlarm() {
        isAlarmActive = false
        stopAlarmSound()
        reset()
    }
    
    func startAlarmSound() {
        let url = selectedSoundUrl ?? Bundle.main.url(forResource: "Tadadada", withExtension: "mp3")

        guard let url else { return }

        do {
            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.play()
        } catch {
            print("Alarm sound failed:", error)
        }
    }
    
    func stopAlarmSound() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }
    
    func refreshAvailableSounds() {
        let bundleExtensions = ["mp3", "wav", "m4a"]
        var allUrls: [URL] = []
        
        // Load built-in sounds from the app bundle.
        for ext in bundleExtensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                allUrls.append(contentsOf: urls)
            }
        }
        
        // Load any custom sounds the user imported into Documents.
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customFiles = (try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)) ?? []
            let customSounds = customFiles.filter { url in
                bundleExtensions.contains(url.pathExtension.lowercased())
            }
            allUrls.append(contentsOf: customSounds)
        }
        
        // Convert collected file URLs into the picker model type.
        let soundFiles = allUrls.map { url in
            TimerSoundFile(url: url)
        }
        
        // Keep sound order stable in the picker.
        self.availableSounds = soundFiles.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
        
        // If none sound was selected, select 1st on the list
        if selectedSoundUrl == nil {
            selectedSoundUrl = availableSounds.first?.url
        }
    }
    
    func deleteSound(at offsets: IndexSet) {
        for index in offsets {
            let sound = availableSounds[index]
            let url = sound.url

            if url.path.contains("/Documents/") {
                try? FileManager.default.removeItem(at: url)
                
                if selectedSoundUrl == url {
                    selectedSoundUrl = nil
                }
            } else {
                showTemporaryError(String(localized: "error.cannot_delete_builtin"))
            }
        }
        
        // Update the UI
        refreshAvailableSounds()
    }
    
    private func showTemporaryError(_ message: String) {
            errorMessage = message
            // Automatically hide after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                errorMessage = nil
            }
        }

    enum TimerStatus {
        case ready
        case running
        case paused
        case finished
    }
}
