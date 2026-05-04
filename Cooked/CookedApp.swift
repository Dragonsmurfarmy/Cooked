import SwiftUI
import UserNotifications

@main
struct CookedApp: App {
    @State private var timerViewModel = TimerViewModel()
    @State private var store = RecipeStore()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        UNUserNotificationCenter.current().delegate = NotificationDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(timerViewModel)
                .environment(store)
                .environment(\.locale, Locale(identifier: store.settings.language.rawValue))
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
