//
//  NotificationService.swift
//  SayDo
//

import Foundation
import UserNotifications

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let calendar: Calendar = .current

    // MARK: - Auth

    /// Запрашивает доступ, если нужно. Возвращает true, если можно показывать уведомления.
    func requestAuthIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                debugPrint("Notification auth request failed:", error)
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Планирует локальное уведомление. Возвращает true, если успешно добавлено.
    @discardableResult
    func schedule(
        id: String,
        title: String,
        body: String? = nil,
        subtitle: String? = nil,
        fireDate: Date,
        userInfo: [AnyHashable: Any] = [:],
        threadId: String? = "tasks",
        skipIfPast: Bool = true
    ) async -> Bool {

        // 1) Проверяем разрешение
        guard await requestAuthIfNeeded() else {
            debugPrint("Notifications not authorized → skip schedule id=\(id)")
            return false
        }

        // 2) В прошлое не планируем
        let now = Date()
        if fireDate <= now {
            if skipIfPast {
                debugPrint("Notification in the past → skip id=\(id), fireDate=\(fireDate)")
                return false
            } else {
                // Показать сразу (без триггера)
                let content = makeContent(
                    title: title,
                    body: body,
                    subtitle: subtitle,
                    userInfo: userInfo,
                    threadId: threadId
                )
                let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
                do {
                     center.removePendingNotificationRequests(withIdentifiers: [id])
                    try await center.add(req)
                    return true
                } catch {
                    debugPrint("Failed to schedule immediate notification id=\(id):", error)
                    return false
                }
            }
        }

        // 3) Удаляем старый pending
     center.removePendingNotificationRequests(withIdentifiers: [id])

        // 4) Контент
        let content = makeContent(
            title: title,
            body: body,
            subtitle: subtitle,
            userInfo: userInfo,
            threadId: threadId
        )

        // 5) Триггер (с точностью до минуты; секунды можно добавить при желании)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        // 6) Реквест
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(req)
            return true
        } catch {
            debugPrint("Failed to schedule notification id=\(id):", error)
            return false
        }
    }

    /// Отмена одного уведомления
    func cancel(id: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Есть ли pending уведомление с id
    func isScheduled(id: String) async -> Bool {
        let requests = await center.pendingNotificationRequests()
        return requests.contains { $0.identifier == id }
    }

    /// Отмена всех pending уведомлений
    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    /// Очистка pending + уже показанных
    func clearAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private

    private func makeContent(
        title: String,
        body: String?,
        subtitle: String?,
        userInfo: [AnyHashable: Any],
        threadId: String?
    ) -> UNMutableNotificationContent {

        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle, !subtitle.isEmpty { content.subtitle = subtitle }
        if let body, !body.isEmpty { content.body = body }
        content.sound = .default
        content.userInfo = userInfo
        if let threadId { content.threadIdentifier = threadId }
        return content
    }
}
