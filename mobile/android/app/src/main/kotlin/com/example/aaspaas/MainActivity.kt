package com.example.aaspaas

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SHARE_CHANNEL = "app.aaspaas/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "share") {
                val title = call.argument<String>("title")
                val text = call.argument<String>("text")
                val subject = call.argument<String>("subject")

                try {
                    val sendIntent = Intent().apply {
                        action = Intent.ACTION_SEND
                        putExtra(Intent.EXTRA_TEXT, text)
                        if (!subject.isNullOrEmpty()) {
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                        }
                        if (!title.isNullOrEmpty()) {
                            putExtra(Intent.EXTRA_TITLE, title)
                        }
                        type = "text/plain"
                    }
                    val shareIntent = Intent.createChooser(sendIntent, title ?: "Share")
                    startActivity(shareIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

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
