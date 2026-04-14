import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var deviceToken: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastErrorMessage: String?
    @Published var pendingThreadId: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    func requestAuthorizationIfNeeded() async {
        let currentSettings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = currentSettings.authorizationStatus

        if currentSettings.authorizationStatus == .notDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                let refreshedSettings = await UNUserNotificationCenter.current().notificationSettings()
                authorizationStatus = refreshedSettings.authorizationStatus

                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            return
        }

        if currentSettings.authorizationStatus == .authorized || currentSettings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        deviceToken = tokenData.map { String(format: "%02x", $0) }.joined()
        lastErrorMessage = nil
    }

    func handleRegistrationFailure(_ error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        if let threadId = userInfo["target_thread_id"] as? String {
            pendingThreadId = threadId
            return
        }

        if let data = userInfo["data"] as? [String: Any], let threadId = data["target_thread_id"] as? String {
            pendingThreadId = threadId
        }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            handleNotificationPayload(notification.request.content.userInfo)
        }
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            handleNotificationPayload(response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}

final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationFailure(error)
        }
    }
}
