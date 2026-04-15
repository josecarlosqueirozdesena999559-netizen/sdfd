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
    @Published var pendingSectionRawValue: String?

    private let notificationCenter = UNUserNotificationCenter.current()
    private let deliveredDashboardKey = "requisiPlus.deliveredDashboardNotificationIds"
    private var deliveredDashboardNotificationIds: Set<String>
    private var hasRemoteBaseline = false
    private var knownRemoteNotificationIds: Set<String> = []

    private override init() {
        let storedIds = UserDefaults.standard.stringArray(forKey: deliveredDashboardKey) ?? []
        deliveredDashboardNotificationIds = Set(storedIds)
        super.init()
        notificationCenter.delegate = self
    }

    var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    func requestAuthorizationIfNeeded() async {
        let currentSettings = await notificationCenter.notificationSettings()
        authorizationStatus = currentSettings.authorizationStatus

        if currentSettings.authorizationStatus == .notDetermined {
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                let refreshedSettings = await notificationCenter.notificationSettings()
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

        if let targetSection = userInfo["target_section"] as? String {
            pendingSectionRawValue = targetSection
            return
        }

        if let data = userInfo["data"] as? [String: Any], let threadId = data["target_thread_id"] as? String {
            pendingThreadId = threadId
            return
        }

        if let data = userInfo["data"] as? [String: Any], let targetSection = data["target_section"] as? String {
            pendingSectionRawValue = targetSection
        }
    }

    func synchronizeVisibleNotifications(_ notifications: [NotificationItem]) async {
        await requestAuthorizationIfNeeded()

        let systemNotifications = notifications.filter(\.isSystemNotification)
        let activeDashboardIds = Set(systemNotifications.map(\.id))
        deliveredDashboardNotificationIds.formIntersection(activeDashboardIds)
        persistDeliveredDashboardNotificationIds()

        for notification in systemNotifications where deliveredDashboardNotificationIds.contains(notification.id) == false {
            await scheduleLocalNotification(for: notification)
            deliveredDashboardNotificationIds.insert(notification.id)
        }
        persistDeliveredDashboardNotificationIds()

        let unreadRemoteIds = Set(
            notifications
                .filter { $0.isSystemNotification == false && $0.isRead == false }
                .map(\.id)
        )

        guard hasRemoteBaseline else {
            knownRemoteNotificationIds = unreadRemoteIds
            hasRemoteBaseline = true
            return
        }

        let newRemoteIds = unreadRemoteIds.subtracting(knownRemoteNotificationIds)
        for notification in notifications where newRemoteIds.contains(notification.id) {
            await scheduleLocalNotification(for: notification)
        }

        knownRemoteNotificationIds = unreadRemoteIds
    }

    private func persistDeliveredDashboardNotificationIds() {
        UserDefaults.standard.set(Array(deliveredDashboardNotificationIds).sorted(), forKey: deliveredDashboardKey)
    }

    private func scheduleLocalNotification(for notification: NotificationItem) async {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        if let threadId = notification.targetThreadId {
            content.userInfo["target_thread_id"] = threadId
        }

        if let targetSection = notification.targetSection {
            content.userInfo["target_section"] = targetSection
        }

        let request = UNNotificationRequest(
            identifier: "requisiPlus.local.\(notification.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            lastErrorMessage = error.localizedDescription
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
