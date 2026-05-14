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
    
    private let firstNotificationIdentifier = "timer-finished-first"
    private let secondNotificationIdentifier = "timer-finished-second" // second notification in case user didnt hear the first one
    private let secondNotificationDelay: TimeInterval = 60
    private let liveActivityDisplayOffset: TimeInterval = 1
    private var liveActivityEndTask: Task<Void, Never>?
    
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
        let secondsToRun = wholeSeconds(from: remainingTime)
        remainingTime = secondsToRun
        // Keep one absolute end date so countdown, Live Activity, and notifications all derive from the same place
        endDate = Date().addingTimeInterval(secondsToRun)

        if let endDate {
            startLiveActivity(endDate: endDate)
            scheduleNotifications(for: endDate)
        }

        startCountdown()
    }

    func pause() {
        guard status == .running else { return }
        countdownTask?.cancel()
        countdownTask = nil
        
        cancelScheduledNotifications()
        
        Task {
            await stopLiveActivity()
        }

        if let endDate {
            remainingTime = wholeSeconds(from: endDate.timeIntervalSinceNow)
        }

        status = .paused
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        
        cancelScheduledNotifications()
        
        Task {
            await stopLiveActivity()
        }
        
        remainingTime = totalDuration
        endDate = nil
        status = .ready
    }

    private func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        
        
    }

    private func wholeSeconds(from duration: TimeInterval) -> TimeInterval {
        TimeInterval(max(Int(ceil(duration)), 0))
    }


    private func startCountdown() {
        countdownTask?.cancel()

        countdownTask = Task {
            // Recompute against end date so timer stays accurate even if this task is delayed
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
        let displayEndDate = endDate.addingTimeInterval(liveActivityDisplayOffset) // Make sure timer doesnt end at 00:00
        let state = TimerActivityAttributes.ContentState(endDate: displayEndDate)
        
        let staleDate = displayEndDate.addingTimeInterval(1)

        do {
            activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: state, staleDate: staleDate),
                        pushType: nil
                    )
            
            liveActivityEndTask?.cancel()
            liveActivityEndTask = Task {
                // End Live Activity explicitly when timer expires
                let duration = max(displayEndDate.timeIntervalSinceNow, 0)
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await stopLiveActivity()
            }
            
        } catch {
            
        }
    }

    private func stopLiveActivity() async {
        liveActivityEndTask?.cancel()
        liveActivityEndTask = nil
        
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }


    private func scheduleNotifications(for endDate: Date) {
        cancelScheduledNotifications()

        scheduleNotification(
            identifier: firstNotificationIdentifier,
            timeInterval: max(endDate.timeIntervalSinceNow, 1)
        )

        scheduleNotification(
            identifier: secondNotificationIdentifier,
            timeInterval: max(endDate.timeIntervalSinceNow + secondNotificationDelay, 1)
        )
    }

    private func scheduleNotification(identifier: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.body = String(localized: "notification.body")
        content.threadIdentifier = "timer-finished"

        if let url = selectedSoundUrl {
            let name = url.lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(name))
        } else {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeInterval,
                repeats: false
            )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Notification scheduling failed:", error.localizedDescription)
            }
        }
        
    }
    
    private func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                firstNotificationIdentifier,
                secondNotificationIdentifier
            ]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [
                firstNotificationIdentifier,
                secondNotificationIdentifier
            ]
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
        
        // Load built-in sounds from the app bundle
        for ext in bundleExtensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                allUrls.append(contentsOf: urls)
            }
        }
        
        // Load custom sounds from the folder iOS also searches for notification sounds
        let fileManager = FileManager.default
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let soundsURL = libraryURL.appendingPathComponent("Sounds", isDirectory: true)
            let customFiles = (try? fileManager.contentsOfDirectory(at: soundsURL, includingPropertiesForKeys: nil)) ?? []
            let customSounds = customFiles.filter { url in
                bundleExtensions.contains(url.pathExtension.lowercased())
            }
            allUrls.append(contentsOf: customSounds)
        }
        
        // Convert collected file URLs into picker model type
        let soundFiles = allUrls.map { url in
            TimerSoundFile(url: url)
        }
        
        // Keep sound order stable in the picker
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

            if url.path.contains("/Library/Sounds/") {
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
    
    // Warns user he cannot delete built-in timer sounds
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
