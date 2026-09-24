package com.najikify.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `najikify/platform` method channel.
 *
 * Dart side: `lib/services/notification_gateway.dart`.
 *
 * * `showNotification(title, body, url?)` posts a system notification on the
 *   "App updates" channel. Tapping it opens [url] (the release download) when
 *   one is supplied.
 * * `openUrl(url)` opens a link in the user's browser.
 *
 * Both return `false` instead of throwing when the platform refuses, so the
 * Dart caller can degrade gracefully.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL_NAME = "najikify/platform"
        const val NOTIFICATION_CHANNEL_ID = "najikify_updates"
        const val NOTIFICATION_CHANNEL_NAME = "App updates"
        const val UPDATE_NOTIFICATION_ID = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result -> handlePlatformCall(call, result) }
    }

    private fun handlePlatformCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showNotification" -> result.success(showUpdateNotification(call))
            "openUrl" -> result.success(openUrl(call.argument<String>("url")))
            else -> result.notImplemented()
        }
    }

    private fun showUpdateNotification(call: MethodCall): Boolean {
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        if (title.isNullOrBlank() || body.isNullOrBlank()) return false

        return try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            ensureNotificationChannel(manager)

            val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_update)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)

            call.argument<String>("url")?.let { url ->
                pendingIntentForUrl(url)?.let(builder::setContentIntent)
            }

            NotificationManagerCompat.from(this)
                .notify(UPDATE_NOTIFICATION_ID, builder.build())
            true
        } catch (e: Exception) {
            // A notification failure must never surface to the user.
            false
        }
    }

    private fun pendingIntentForUrl(url: String): PendingIntent? = try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    } catch (e: Exception) {
        null
    }

    private fun openUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun ensureNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Lets you know when a new Najikify version is available"
        }
        manager.createNotificationChannel(channel)
    }
}
