package com.eyewatchdriver.eye.safe_drive_monitor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

class DriverMonitoringService : Service() {

    companion object {
        private const val TAG = "DriverMonitoringService"
        const val CHANNEL_ID = "safe_drive_monitor_foreground_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START_MONITORING = "com.eyewatchdriver.eye.safe_drive_monitor.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.eyewatchdriver.eye.safe_drive_monitor.STOP_MONITORING"

        @Volatile
        var isServiceRunning: Boolean = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "DriverMonitoringService created.")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.i(TAG, "DriverMonitoringService onStartCommand action: $action")

        if (action == ACTION_STOP_MONITORING) {
            stopMonitoringService()
            return START_NOT_STICKY
        }

        startForegroundWithNotification()
        acquireWakeLock()
        isServiceRunning = true

        // START_STICKY ensures OS attempts to recreate service if killed under memory pressure.
        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        val notification = buildNotification("مراقبة يقظة السائق نشطة ومستمرة لحمايتك")

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // API 29+ foreground service type CAMERA (required on Android 14+ API 34)
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.i(TAG, "startForeground initialized successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
        }
    }

    private fun buildNotification(statusText: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentPendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingIntentFlags)

        val stopIntent = Intent(this, DriverMonitoringService::class.java).apply {
            action = ACTION_STOP_MONITORING
        }
        val stopPendingIntent = PendingIntent.getService(this, 1, stopIntent, pendingIntentFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("Safe Drive Monitor")
            .setContentText(statusText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "إيقاف المراقبة",
                    stopPendingIntent
                ).build()
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Safe Drive Monitoring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "قناة إشعارات استمرار مراقبة يقظة السائق بالخلفية"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
            Log.i(TAG, "Notification channel created.")
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SafeDriveMonitor:DrivingMonitoringWakeLock"
            ).apply {
                setReferenceCounted(false)
                // Safety 12-hour timeout to prevent permanent drain if unhandled
                acquire(12 * 60 * 60 * 1000L)
            }
            Log.i(TAG, "Partial WakeLock acquired for driving session.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.i(TAG, "Partial WakeLock released.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing WakeLock", e)
        } finally {
            wakeLock = null
        }
    }

    private fun stopMonitoringService() {
        Log.i(TAG, "Stopping DriverMonitoringService...")
        isServiceRunning = false
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "Task removed from Recents. DriverMonitoringService continues running in foreground.")
    }

    override fun onDestroy() {
        Log.i(TAG, "DriverMonitoringService onDestroy.")
        isServiceRunning = false
        releaseWakeLock()
        super.onDestroy()
    }
}
