package com.eyewatchdriver.eye.safe_drive_monitor

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eyewatchdriver.eye.safe_drive_monitor/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> result.notImplemented()
            }
        }
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
}
