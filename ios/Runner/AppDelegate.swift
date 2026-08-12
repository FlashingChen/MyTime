import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // workmanager_apple runs the background callbackDispatcher in a separate
    // headless FlutterEngine; without this callback its plugins (e.g.
    // shared_preferences) are never registered and background sync fails with
    // MissingPluginException.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Identifier must match WorkmanagerSyncScheduler.taskName in
    // lib/data/sync/sync_scheduler.dart and the Info.plist
    // BGTaskSchedulerPermittedIdentifiers entry.
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "mytime.webdav.sync"
    )
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LiveActivityPlugin"
    ) {
      LiveActivityPlugin.register(with: registrar)
    }
  }
}
