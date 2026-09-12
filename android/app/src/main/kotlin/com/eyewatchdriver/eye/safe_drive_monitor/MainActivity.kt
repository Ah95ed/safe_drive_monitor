package com.eyewatchdriver.eye.safe_drive_monitor

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.eyewatchdriver.eye.safe_drive_monitor/foreground_service"

        @Volatile
        var activeChannel: MethodChannel? = null
            private set
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBackground" -> {
                    result.success(moveTaskToBack(true))
                }
                "updateNotificationStatus" -> {
                    val statusText = call.argument<String>("statusText") ?: ""
                    DriverMonitoringService.updateStatus(this, statusText)
                    result.success(true)
                }
                "startForegroundService" -> {
                    try {
                        val intent = Intent(this, DriverMonitoringService::class.java).apply {
                            action = DriverMonitoringService.ACTION_START_MONITORING
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FGS_START_ERROR", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val intent = Intent(this, DriverMonitoringService::class.java).apply {
                            action = DriverMonitoringService.ACTION_STOP_MONITORING
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FGS_STOP_ERROR", e.message, null)
                    }
                }
                "isForegroundServiceRunning" -> {
                    result.success(DriverMonitoringService.isServiceRunning)
                }
                "isLowLightBoostSupported" -> {
                    result.success(checkLowLightBoostSupport())
                }
                "openBatterySettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                "getThermalStatus" -> {
                    result.success(getDeviceThermalStatus())
                }
                "getThermalHeadroom" -> {
                    val forecastSeconds = call.argument<Int>("forecastSeconds") ?: 0
                    result.success(getDeviceThermalHeadroom(forecastSeconds))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        activeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun checkLowLightBoostSupport(): Boolean {
        if (Build.VERSION.SDK_INT < 35) return false
        return try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return false
            for (id in cameraManager.cameraIdList) {
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
                    val aeModes = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_MODES)
                    // CameraMetadata.CONTROL_AE_MODE_ON_LOW_LIGHT_BOOST_BRIGHTNESS_PRIORITY == 6 in API 35
                    if (aeModes != null && aeModes.contains(6)) {
                        return true
                    }
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent().apply {
                action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val appIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(appIntent)
            } catch (_: Exception) {}
        }
    }

    private fun getDeviceThermalStatus(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return 0 // THERMAL_STATUS_NONE
        }
        return try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            powerManager?.currentThermalStatus ?: 0
        } catch (e: Exception) {
            0
        }
    }

    private fun getDeviceThermalHeadroom(forecastSeconds: Int): Double {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return -1.0
        }
        return try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            val headroom = powerManager?.getThermalHeadroom(forecastSeconds) ?: -1.0f
            headroom.toDouble()
        } catch (e: Exception) {
            -1.0
        }
    }

    override fun onStop() {
        super.onStop()
        // Phase 25 & Android Lifecycle:
        // When activity moves to background or screen turns off during an active driving session,
        // re-dispatch ON_START so CameraX does not unbind or deactivate image analysis.
        if (DriverMonitoringService.isServiceRunning) {
            try {
                (lifecycle as? LifecycleRegistry)?.handleLifecycleEvent(Lifecycle.Event.ON_START)
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "Failed to keep lifecycle STARTED for background camera: $e")
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Phase 2: Physical/system back button during active driving session:
        // move task to back without destroying the Activity or Flutter monitoring runtime.
        if (DriverMonitoringService.isServiceRunning) {
            moveTaskToBack(true)
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }
}
