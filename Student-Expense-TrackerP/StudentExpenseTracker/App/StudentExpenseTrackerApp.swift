//
//  StudentExpenseTrackerApp.swift
//  StudentExpenseTracker
//
//  Created by rg on 5/15/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

@main
struct StudentExpenseTrackerApp: App {
    @State var authVM = AuthViewModel()
    @State var syncManager: SyncManager
    let persistenceController = PersistenceController.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    init() {
        FirebaseApp.configure()
        
        // Ensure CoreData is ready before using AuthViewModel
        _ = persistenceController.viewContext
        
        // Initialize SyncManager with dependencies
        let authViewModel = AuthViewModel()
        self._authVM = State(initialValue: authViewModel)
        self._syncManager = State(initialValue: SyncManager(
            authViewModel: authViewModel,
            persistenceController: persistenceController
        ))
    }

    var body: some Scene {
        WindowGroup {
            SplashView(authVM: authVM, syncManager: syncManager)
        }

    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = self   // ← Important!
    // Request permission at launch
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      print("🔔 Notification granted? \(granted), error:", error as Any)
    }
    return true
  }

  // This method makes iOS show a banner even when your app is in the foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}
