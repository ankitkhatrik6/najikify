package com.najikify.app

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Bundle
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
 * * `scheduleUpdateCheck()` arms the periodic background release check
 *   ([UpdateCheckJobService]); `getNotifiedVersion()` / `markUpdateNotified()`
 *   / `notificationsEnabled()` keep the "announced at most once" bookkeeping in
 *   sync with the Dart `UpdateService`.
 *
 * Every method returns `false` (or null) instead of throwing when the platform
 * refuses, so the Dart caller can degrade gracefully.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL_NAME = "najikify/platform"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Arm the periodic background update check. This is what makes Najikify
        // behave like a store-installed app: a new release is announced in the
        // notification centre on its own, without the user opening the app.
        UpdateNotifier.schedulePeriodic(this)
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
            // Background update-check bookkeeping, shared with UpdateService.
            "scheduleUpdateCheck" -> {
                UpdateNotifier.schedulePeriodic(this)
                result.success(true)
            }
            "getNotifiedVersion" ->
                result.success(UpdateNotifier.notifiedVersion(this))
            "markUpdateNotified" -> {
                val version = call.argument<String>("version")
                if (version.isNullOrBlank()) {
                    result.success(false)
                } else {
                    UpdateNotifier.markNotified(this, version)
                    result.success(true)
                }
            }
            "notificationsEnabled" ->
                result.success(UpdateNotifier.notificationsEnabled(this))
            // Local IPv4 addresses with real netmasks, used to tell whether a
            // peer could be on this network (see NetworkInspector).
            "getLinkAddresses" -> result.success(NetworkInspector.linkAddresses(this))
            else -> result.notImplemented()
        }
    }

    private fun showUpdateNotification(call: MethodCall): Boolean {
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        if (title.isNullOrBlank() || body.isNullOrBlank()) return false

        return try {
            UpdateNotifier.ensureChannel(this)

            val builder = NotificationCompat.Builder(this, UpdateNotifier.CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_update)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                // Re-posting the same update never buzzes twice.
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)

            call.argument<String>("url")?.let { url ->
                pendingIntentForUrl(url)?.let(builder::setContentIntent)
            }

            NotificationManagerCompat.from(this)
                .notify(UpdateNotifier.NOTIFICATION_ID, builder.build())
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
}
