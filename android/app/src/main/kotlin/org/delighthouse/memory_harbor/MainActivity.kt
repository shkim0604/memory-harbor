package org.delighthouse.memory_harbor

import android.content.Intent
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingCallkitLaunchAction: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "memory_harbor/audio_route"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasExternalAudioOutput" -> result.success(hasExternalAudioOutput())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "memory_harbor/callkit_launch"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndClearPendingCallkitAction" -> {
                    result.success(pendingCallkitLaunchAction)
                    pendingCallkitLaunchAction = null
                }
                else -> result.notImplemented()
            }
        }

        cacheCallkitLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        cacheCallkitLaunchIntent(intent)
    }

    private fun cacheCallkitLaunchIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (!action.startsWith("com.hiennv.flutter_callkit_incoming.ACTION_CALL_")) {
            return
        }
        val data = intent.getBundleExtra("EXTRA_CALLKIT_CALL_DATA") ?: return
        pendingCallkitLaunchAction = mapOf(
            "event" to normalizeCallkitAction(action),
            "body" to bundleToCallkitBody(data),
        )
    }

    private fun normalizeCallkitAction(action: String): String {
        return when (action.substringAfterLast('.')) {
            "ACTION_CALL_ACCEPT" -> "ACTION_CALL_ACCEPT"
            "ACTION_CALL_DECLINE" -> "ACTION_CALL_DECLINE"
            "ACTION_CALL_TIMEOUT" -> "ACTION_CALL_TIMEOUT"
            "ACTION_CALL_ENDED" -> "ACTION_CALL_ENDED"
            else -> action.substringAfterLast('.')
        }
    }

    @Suppress("DEPRECATION")
    private fun bundleToCallkitBody(bundle: Bundle): Map<String, Any?> {
        val extra =
            (bundle.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<*, *>)
                ?.entries
                ?.associate { (key, value) -> key.toString() to value }
                ?: emptyMap<String, Any?>()
        return mapOf(
            "id" to bundle.getString("EXTRA_CALLKIT_ID", ""),
            "extra" to extra,
        )
    }

    private fun hasExternalAudioOutput(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { device ->
                when (device.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_AUX_LINE -> true
                    else -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                                device.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                        } else {
                            false
                        }
                    }
                }
            }
        }

        @Suppress("DEPRECATION")
        return audioManager.isBluetoothScoOn ||
            audioManager.isBluetoothA2dpOn ||
            audioManager.isWiredHeadsetOn
    }
}
