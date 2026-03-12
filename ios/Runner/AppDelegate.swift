import Flutter
import UIKit
import UserNotifications
import PushKit
import AVFAudio
import CallKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  // Keep a strong reference to PKPushRegistry; otherwise VoIP pushes can stop in background.
  private var voipRegistry: PKPushRegistry?
  private let audioRouteChannelName = "memory_harbor/audio_route"
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: audioRouteChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(false)
          return
        }
        switch call.method {
        case "hasExternalAudioOutput":
          result(self.hasExternalAudioOutput())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Register for VoIP pushes (required for CallKit in terminated/background).
    let mainQueue = DispatchQueue.main
    let registry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    registry.delegate = self
    registry.desiredPushTypes = [PKPushType.voIP]
    voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // VoIP device token for APNs (PushKit).
  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  // Handle incoming VoIP push and show CallKit UI immediately.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let map = payload.dictionaryPayload
    let appState = UIApplication.shared.applicationState
    NSLog("[PK] didReceiveIncomingPushWith: state=%@, payload=%@", String(describing: appState), "\(map)")
    var completionCalled = false
    let finish: () -> Void = {
      if completionCalled { return }
      completionCalled = true
      NSLog("[PK] didReceiveIncomingPushWith COMPLETION")
      completion()
    }
    let callId = (map["callId"] as? String) ?? (map["call_id"] as? String) ?? (map["id"] as? String) ?? UUID().uuidString
    let callerName = (map["callerName"] as? String) ?? (map["nameCaller"] as? String) ?? "Incoming call"
    let handle = (map["handle"] as? String) ?? callerName
    let isVideo = (map["isVideo"] as? Bool) ?? false

    let data = flutter_callkit_incoming.Data(
      id: callId,
      nameCaller: callerName,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    data.extra = [
      "callId": callId,
      "channelName": map["channelName"] ?? map["channel_name"] ?? "",
      "callerName": map["callerName"] ?? map["caller_name"] ?? callerName,
      "callerProfileImage": map["callerProfileImage"] ?? map["caller_profile_image"] ?? "",
      "callerId": map["callerId"] ?? map["caller_id"] ?? "",
      "groupId": map["groupId"] ?? map["group_id"] ?? "",
      "receiverId": map["receiverId"] ?? map["receiver_id"] ?? "",
    ]

    NSLog("[PK] showCallkitIncoming: callId=%@", callId)
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.showCallkitIncoming(
        data,
        fromPushKit: true
      ) {
        NSLog("[PK] showCallkitIncoming completion: callId=%@", callId)
        finish()
      }
    } else {
      NSLog("[PK] showCallkitIncoming: plugin is nil")
      finish()
    }
  }

  // MARK: - CallkitIncomingAppDelegate
  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
    // No-op: handled on Flutter side via event stream.
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    // No-op: audio handled in Flutter/Agora layer.
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    // No-op: audio handled in Flutter/Agora layer.
  }

  private func hasExternalAudioOutput() -> Bool {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    return outputs.contains { output in
      switch output.portType {
      case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .airPlay:
        return true
      default:
        return false
      }
    }
  }
}
