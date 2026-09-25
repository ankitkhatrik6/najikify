package com.najikify.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Background "is there a newer Najikify release?" check.
 *
 * This is the Android counterpart of `lib/services/update_service.dart`: the
 * Dart service can only check while the app is running, so this native helper
 * runs the same check from the scheduled [UpdateCheckJobService] and posts the
 * notification in the notification centre — like a store-installed app, without
 * the user having to open Najikify first.
 *
 * The "already notified" version is shared with Dart through [notifiedVersion]
 * / [markNotified] (method channel in `MainActivity`), so a release is announced
 * at most once across both paths.
 *
 * Everything here is best-effort and must never throw into the caller.
 */
object UpdateNotifier {

    private const val PREFS_NAME = "najikify_update_prefs"
    private const val KEY_NOTIFIED_VERSION = "najikify_notified_version"

    /** Same channel and notification id as `MainActivity`, so a re-announcement
     *  replaces the existing notification instead of stacking a second one. */
    const val CHANNEL_ID = "najikify_updates"
    const val CHANNEL_NAME = "App updates"
    const val NOTIFICATION_ID = 1001

    private const val RELEASES_API =
        "https://api.github.com/repos/ankitkhatrik6/najikify/releases/latest"
    private const val RELEASES_PAGE =
        "https://github.com/ankitkhatrik6/najikify/releases/latest"

    private const val JOB_ID = 24051997
    private const val CHECK_INTERVAL_MS = 6L * 60L * 60L * 1000L // every 6 hours

    /** Architecture suffixes used by the smaller per-ABI APK assets. */
    private val ABI_SUFFIXES = listOf("-arm64-v8a.apk", "-armeabi-v7a.apk", "-x86_64.apk", "-x86.apk")

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Version already announced to the user (shared with the Dart service). */
    fun notifiedVersion(context: Context): String? =
        prefs(context).getString(KEY_NOTIFIED_VERSION, null)

    fun markNotified(context: Context, version: String) {
        prefs(context).edit().putString(KEY_NOTIFIED_VERSION, version).apply()
    }

    fun notificationsEnabled(context: Context): Boolean = try {
        NotificationManagerCompat.from(context).areNotificationsEnabled()
    } catch (_: Exception) {
        false
    }

    /**
     * Registers the periodic background check. Safe to call on every app start:
     * JobScheduler keeps the job across restarts (and, since it is persisted,
     * across reboots) and an already-scheduled job is left untouched.
     */
    fun schedulePeriodic(context: Context) {
        try {
            val scheduler =
                context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(JOB_ID) != null) return

            val job = JobInfo.Builder(
                JOB_ID,
                ComponentName(context, UpdateCheckJobService::class.java),
            )
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
                .setPeriodic(CHECK_INTERVAL_MS)
                .build()

            scheduler.schedule(job)
        } catch (_: Exception) {
            // A missing background check never breaks the app.
        }
    }

    /**
     * Fetches the latest release and posts a notification when it is newer than
     * the installed build. Blocking — call it from a worker thread.
     *
     * @return true when a notification was posted.
     */
    fun checkForUpdate(context: Context): Boolean {
        return try {
            val installed = installedVersion(context) ?: return false
            val release = latestRelease() ?: return false
            val version = release.first
            val downloadUrl = release.second

            if (!isNewer(version, installed)) return false
            if (notifiedVersion(context) == version) return false
            if (!notificationsEnabled(context)) return false
            if (!postNotification(context, version, installed, downloadUrl)) return false

            markNotified(context, version)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Reads `releases/latest` and returns `version to downloadUrl`.
     *
     * The download URL is the universal APK when the release ships one (that
     * asset always installs), otherwise the first `.apk`, otherwise the release
     * page.
     */
    private fun latestRelease(): Pair<String, String>? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(RELEASES_API).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                // api.github.com rejects requests that send no User-Agent.
                setRequestProperty("User-Agent", "Najikify-Android")
                setRequestProperty("Accept", "application/vnd.github+json")
            }
            if (connection.responseCode !in 200..299) return null

            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            val version = json.optString("tag_name").trim().removePrefix("v")
            if (version.isEmpty()) return null

            val htmlUrl = json.optString("html_url").ifEmpty { RELEASES_PAGE }
            Pair(version, apkDownloadUrl(json) ?: htmlUrl)
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun apkDownloadUrl(json: JSONObject): String? {
        val assets = json.optJSONArray("assets") ?: return null
        var firstApk: String? = null
        for (i in 0 until assets.length()) {
            val asset = assets.optJSONObject(i) ?: continue
            val name = asset.optString("name").lowercase()
            if (!name.endsWith(".apk")) continue
            val url = asset.optString("browser_download_url")
            if (url.isEmpty()) continue
            if (ABI_SUFFIXES.none { name.endsWith(it) }) return url // universal APK
            if (firstApk == null) firstApk = url
        }
        return firstApk
    }

    private fun postNotification(
        context: Context,
        version: String,
        installed: String,
        url: String,
    ): Boolean = try {
        ensureChannel(context)

        val message = "You are on v$installed. Tap to download the new version."
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_update)
            .setContentTitle("Najikify v$version is available")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        pendingIntentForUrl(context, url)?.let(builder::setContentIntent)

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        true
    } catch (_: Exception) {
        false
    }

    private fun pendingIntentForUrl(context: Context, url: String): PendingIntent? = try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    } catch (_: Exception) {
        null
    }

    /** Creates the "App updates" channel on Android 8+. Idempotent. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Lets you know when a new Najikify version is available"
            }
            manager.createNotificationChannel(channel)
        } catch (_: Exception) {
            // No channel means no notification — the app keeps working.
        }
    }

    private fun installedVersion(context: Context): String? = try {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName
    } catch (_: Exception) {
        null
    }

    /** Numeric semver comparison; true when [candidate] is newer than [installed]. */
    private fun isNewer(candidate: String, installed: String): Boolean {
        val a = candidate.removePrefix("v").substringBefore("+").split(".")
        val b = installed.removePrefix("v").substringBefore("+").split(".")
        for (i in 0 until maxOf(a.size, b.size, 3)) {
            val x = a.getOrNull(i)?.toIntOrNull() ?: 0
            val y = b.getOrNull(i)?.toIntOrNull() ?: 0
            if (x != y) return x > y
        }
        return false
    }
}
