import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let appGroupId = "group.com.spectersystems.retrotrack"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Set up MethodChannel for widget communication
        let controller = window?.rootViewController as! FlutterViewController
        let widgetChannel = FlutterMethodChannel(
            name: "com.retrotracker.retrotracker/widget",
            binaryMessenger: controller.binaryMessenger
        )

        widgetChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate not available", details: nil))
                return
            }

            switch call.method {
            case "writeToAppGroup":
                if let args = call.arguments as? [String: Any],
                   let key = args["key"] as? String,
                   let value = args["value"] {
                    self.writeToAppGroup(key: key, value: value)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }

            case "writeMultipleToAppGroup":
                if let data = call.arguments as? [String: Any] {
                    for (key, value) in data {
                        self.writeToAppGroup(key: key, value: value)
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }

            case "reloadAllTimelines":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)

            case "updateWidget", "updateAllWidgets", "updateRecentAchievementsWidget",
                 "updateStreakWidget", "updateAotwWidget", "updateFriendActivityWidget":
                // Reload all widgets on iOS
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                result(nil)

            case "getInitialIntent":
                // iOS doesn't have intents like Android, return nil
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func writeToAppGroup(key: String, value: Any) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }

        // Handle different value types
        if let stringValue = value as? String {
            userDefaults.set(stringValue, forKey: key)
        } else if let intValue = value as? Int {
            userDefaults.set(intValue, forKey: key)
        } else if let doubleValue = value as? Double {
            userDefaults.set(doubleValue, forKey: key)
        } else if let boolValue = value as? Bool {
            userDefaults.set(boolValue, forKey: key)
        } else {
            // For other types, try to store as-is
            userDefaults.set(value, forKey: key)
        }

        userDefaults.synchronize()
    }
}
