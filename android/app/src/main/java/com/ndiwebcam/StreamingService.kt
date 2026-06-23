package com.ndiwebcam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the NDI stream alive when the screen is off.
 * Camera and audio capture are managed by CameraFragment; this service only
 * holds the foreground wake-lock so Android does not kill the process.
 */
class StreamingService : Service() {

    inner class StreamBinder : Binder() {
        val service: StreamingService get() = this@StreamingService
    }

    private val binder = StreamBinder()

    override fun onBind(intent: Intent): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForeground()
            ACTION_STOP  -> stopSelf()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    // MARK: Private

    private fun startForeground() {
        createNotificationChannel()

        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, StreamingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("NDI Webcam — Streaming")
            .setContentText("Tap to return to camera view")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "NDI Streaming",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps NDI stream active in the background"
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.ndiwebcam.START_STREAMING"
        const val ACTION_STOP  = "com.ndiwebcam.STOP_STREAMING"
        private const val CHANNEL_ID       = "ndi_stream"
        private const val NOTIFICATION_ID  = 1001

        fun start(context: Context) {
            val intent = Intent(context, StreamingService::class.java).setAction(ACTION_START)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, StreamingService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }
    }
}
