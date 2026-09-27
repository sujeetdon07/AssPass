package com.example.aaspaas

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onStart() {
        super.onStart()
        createNotificationChannels()
    }

    /**
     * Creates Aaspaas notification channels on Android 8+ (API 26+).
     * Channel IDs must stay in sync with backend resolveChannelId().
     * Android no-ops if the channel already exists — safe to call repeatedly.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channels = listOf(
            Triple("aaspaas_default",     "Aaspaas Notifications",    NotificationManager.IMPORTANCE_DEFAULT),
            Triple("aaspaas_messages",    "Messages",                  NotificationManager.IMPORTANCE_HIGH),
            Triple("aaspaas_social",      "Social",                    NotificationManager.IMPORTANCE_DEFAULT),
            Triple("aaspaas_community",   "Community",                 NotificationManager.IMPORTANCE_DEFAULT),
            Triple("aaspaas_marketplace", "Marketplace",               NotificationManager.IMPORTANCE_DEFAULT),
            Triple("aaspaas_business",    "Businesses & Services",     NotificationManager.IMPORTANCE_DEFAULT),
            Triple("aaspaas_system",      "System",                    NotificationManager.IMPORTANCE_LOW),
        )

        channels.forEach { (id, name, importance) ->
            val channel = NotificationChannel(id, name, importance).apply {
                enableLights(true)
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
