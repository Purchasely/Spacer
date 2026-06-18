//
//  SpacerApp.swift
//  Spacer
//
//  Entry point. Dark-mode-first; builds the SwiftData container and the AppModel
//  DI root, then injects the model into the environment.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Hosts launch-time SDK bootstrap. Purchasely must start on the main thread in
/// `didFinishLaunchingWithOptions` so it doesn't miss events or cold-start deeplinks.
/// Also the notification-center delegate so reminders show while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        PurchaselyService.start()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Present banners (and play sound) even when the app is in the foreground, so a
    /// just-scheduled test reminder is visible without backgrounding.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct SpacerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var appModel: AppModel

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: FavoriteItem.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.container = container
        _appModel = State(initialValue: AppModel(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appModel)
                .preferredColorScheme(.dark)
                .tint(AppColor.accent)
        }
        .modelContainer(container)
    }
}
