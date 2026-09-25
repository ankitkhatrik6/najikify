package com.najikify.app

import android.app.job.JobParameters
import android.app.job.JobService

/**
 * Periodic background job that checks GitHub for a newer Najikify release and
 * posts the "update available" notification (see [UpdateNotifier]).
 *
 * Scheduled from `MainActivity` (and again on every app start) through
 * `UpdateNotifier.schedulePeriodic`. The job is *persisted*, so it survives
 * reboots via the `RECEIVE_BOOT_COMPLETED` permission declared in the manifest.
 *
 * The network call runs on a worker thread, so the framework is told that work
 * is still running (`onStartJob` returns true) and [jobFinished] is called from
 * that thread.
 */
class UpdateCheckJobService : JobService() {

    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        worker = Thread {
            try {
                UpdateNotifier.checkForUpdate(applicationContext)
            } finally {
                jobFinished(params, false)
            }
        }.also { it.start() }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        worker?.interrupt()
        worker = null
        // Reschedule: the check is cheap and only uses the network when due.
        return true
    }
}
