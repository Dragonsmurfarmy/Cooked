import SwiftUI
import UserNotifications

@main
struct CookedApp: App {
    @State private var timerViewModel = TimerViewModel()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Notification permission:", settings.authorizationStatus.rawValue)
        }

        UNUserNotificationCenter.current().delegate = NotificationDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timerViewModel)
        }
    }

    final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            return [.banner, .sound]
        }
    }
}
