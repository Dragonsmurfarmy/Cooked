import SwiftUI
import UserNotifications

@main
struct CookedApp: App {
    // Shared across all views
    @State private var timerViewModel = TimerViewModel()
    @State private var store = RecipeStore()
    private let notificationDelegate = NotificationDelegate()

    
    init() {
        // Ask user for permission to send notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        // Use notification delegate to handle notification events
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            // Initialize Root View which hold multi-view info
            RootView(store: store)
                .environment(timerViewModel)
                .environment(store)
                .environment(\.locale, Locale(identifier: store.settings.language.rawValue))
        }
    }

    
    final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        // Function called when notification arrives while app in foreground.
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            // Show alert and play sound even when user is looking at the app
            return [.banner, .sound]
        }
    }
}
