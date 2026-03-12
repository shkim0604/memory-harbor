package org.delighthouse.memory_harbor

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
