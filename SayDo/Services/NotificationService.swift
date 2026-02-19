//
//  NotoficationService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//

import Foundation
import UserNotifications

final class NotificationService {
    
    static let shared = NotificationService()
    private init(){}
    
    func requestAuthIfNeeded() async -> Bool {
        
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
           return true
        case .denied:
            return false
        case .notDetermined:
            do{
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
            @unknown default:
            return false
        }
    }
    
    func schedule(id: String, title: String, fireDate: Date) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .day, .month, .hour, .minute], from: fireDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
               try? await center.add(req)
        
    }
    
    func cancel(id: String) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [id])
        
    }
    
}
