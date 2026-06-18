//
//  NotificationService.swift
//  Spacer
//
//  Local "daily picture" reminder. Owns the UserNotifications calls so the rest of
//  the app stays notification-framework-free. For now it schedules a one-shot
//  reminder a few seconds out so the feature can be tested on the spot; a real
//  daily schedule would swap the trigger for a repeating calendar trigger.
//

import UserNotifications

enum NotificationService {
    private static let reminderID = "daily-picture-reminder"

    /// Requests permission (if needed) and schedules the reminder ~5s out so you can
    /// background the app and watch it arrive. Returns whether it was scheduled.
    @discardableResult
    static func sendDailyPictureReminder() async -> Bool {
        let center = UNUserNotificationCenter.current()

        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[Spacer] Notification authorization error: \(error.localizedDescription)")
            return false
        }
        guard granted else {
            print("[Spacer] Notification permission denied — enable it in Settings to test")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Today's cosmos"
        content.body = "Your daily Astronomy Picture is ready to explore."
        content.sound = .default

        // One-shot, 5s out, so it's testable immediately. Same id replaces any pending one.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("[Spacer] Daily picture reminder scheduled (fires in 5s)")
            return true
        } catch {
            print("[Spacer] Failed to schedule reminder: \(error.localizedDescription)")
            return false
        }
    }
}
