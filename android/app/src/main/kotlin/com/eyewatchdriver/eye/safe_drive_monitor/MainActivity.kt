package com.eyewatchdriver.eye.safe_drive_monitor

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Debug
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.spec.MGF1ParameterSpec
import java.util.Arrays
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.eyewatchdriver.eye.safe_drive_monitor/foreground_service"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "DriveAlertDeviceMasterKey"

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
                "getDeviceAttestationPublicKey" -> {
                    try {
                        val keyPair = getOrCreateDeviceKeyPair()
                        val pubKeyDer = keyPair.public.encoded
                        val pubKeyBase64 = android.util.Base64.encodeToString(pubKeyDer, android.util.Base64.NO_WRAP)
                        result.success(pubKeyBase64)
                    } catch (e: Exception) {
                        result.error("KEYSTORE_ERROR", "Failed to retrieve device attestation key: ${e.message}", null)
                    }
                }
                "decryptModelContainer" -> {
                    var keyBytes: ByteArray? = null
                    try {
                        val container = call.argument<ByteArray>("encryptedBytes")
                        val wrappedKey = call.argument<ByteArray>("wrappedKeyBytes")
                        val directKey = call.argument<ByteArray>("keyBytes")

                        if (container == null || container.size < 32) {
                            result.error("DECRYPT_ERROR", "Encrypted container is missing or invalid", null)
                            return@setMethodCallHandler
                        }

                        keyBytes = if (wrappedKey != null && wrappedKey.isNotEmpty()) {
                            unwrapModelKeyWithKeystore(wrappedKey)
                        } else if (directKey != null && directKey.isNotEmpty()) {
                            directKey.clone()
                        } else {
                            result.error("KEY_MISSING", "No model decryption key or wrapped key provided", null)
                            return@setMethodCallHandler
                        }

                        val decryptedBytes = decryptModelContainer(container, keyBytes)
                        result.success(decryptedBytes)
                    } catch (e: Exception) {
                        result.error("DECRYPT_EXCEPTION", e.message, null)
                    } finally {
                        // Crucial Security Scrubbing: zero out plaintext key in memory
                        if (keyBytes != null) {
                            Arrays.fill(keyBytes, 0.toByte())
                        }
                    }
                }
                "checkSecurityEnvironment" -> {
                    try {
                        result.success(performSecurityEnvironmentCheck())
                    } catch (e: Exception) {
                        result.error("SECURITY_CHECK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- Android Keystore Management ---

    @Synchronized
    private fun getOrCreateDeviceKeyPair(): KeyPair {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)

        if (keyStore.containsAlias(KEY_ALIAS)) {
            val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
            val publicKey = keyStore.getCertificate(KEY_ALIAS)?.publicKey
            if (privateKey != null && publicKey != null) {
                return KeyPair(publicKey, privateKey)
            }
        }

        val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, KEYSTORE_PROVIDER)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_ENCRYPT
        )
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setKeySize(2048)
            .build()

        kpg.initialize(spec)
        return kpg.generateKeyPair()
    }

    private fun unwrapModelKeyWithKeystore(wrappedKey: ByteArray): ByteArray {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
            ?: throw IllegalStateException("Device master key not found in Android Keystore")

        val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
        val oaepParams = OAEPParameterSpec(
            "SHA-256",
            "MGF1",
            MGF1ParameterSpec.SHA256,
            PSource.PSpecified.DEFAULT
        )
        cipher.init(Cipher.DECRYPT_MODE, privateKey, oaepParams)
        return cipher.doFinal(wrappedKey)
    }

    private fun decryptModelContainer(container: ByteArray, keyBytes: ByteArray): ByteArray {
        val magic = String(container, 0, 4, Charsets.UTF_8)
        if (magic != "DAM1") {
            throw IllegalArgumentException("Invalid encrypted model container format (magic mismatch)")
        }

        val iv = container.copyOfRange(4, 16)
        val tag = container.copyOfRange(16, 32)
        val ciphertext = container.copyOfRange(32, container.size)

        // In Java Cipher "AES/GCM/NoPadding", tag must be appended to ciphertext
        val cipherInput = ByteArray(ciphertext.size + tag.size)
        System.arraycopy(ciphertext, 0, cipherInput, 0, ciphertext.size)
        System.arraycopy(tag, 0, cipherInput, ciphertext.size, tag.size)

        val secretKey = SecretKeySpec(keyBytes, "AES")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(128, iv)
        cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
        return cipher.doFinal(cipherInput)
    }

    // --- Security Environment Risk Signals (Root, Hooking, Debugger) ---

    private fun performSecurityEnvironmentCheck(): Map<String, Any> {
        val isDebuggerAttached = Debug.isDebuggerConnected() ||
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        var suBinaryFound = false
        for (path in suPaths) {
            if (File(path).exists()) {
                suBinaryFound = true
                break
            }
        }

        val buildTags = Build.TAGS
        val testKeysFound = buildTags != null && buildTags.contains("test-keys")
        val isRooted = suBinaryFound || testKeysFound

        // Check common hooking artifacts (e.g. Frida default server socket)
        var hookingArtifactFound = false
        try {
            val fridaSocket = java.net.Socket()
            fridaSocket.connect(java.net.InetSocketAddress("127.0.0.1", 27042), 50)
            fridaSocket.close()
            hookingArtifactFound = true
        } catch (_: Exception) {
            hookingArtifactFound = false
        }

        var riskScore = 0
        if (isDebuggerAttached) riskScore += 30
        if (isRooted) riskScore += 40
        if (hookingArtifactFound) riskScore += 50

        return mapOf(
            "isRooted" to isRooted,
            "isDebuggerAttached" to isDebuggerAttached,
            "isHookingDetected" to hookingArtifactFound,
            "riskScore" to riskScore
        )
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
        // Physical/system back button during active driving session:
        // move task to back without destroying the Activity or Flutter monitoring runtime.
        if (DriverMonitoringService.isServiceRunning) {
            moveTaskToBack(true)
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }
}
