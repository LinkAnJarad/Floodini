package com.floodini.app

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Retries the queue about once a minute while anything is waiting, so messages
 * go out when signal returns even if the app is closed. Android may delay this
 * in battery-saving (Doze) mode.
 */
class SendQueueWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        SendLaterQueue.sendAll(applicationContext)
        if (SendLaterQueue.hasPending(applicationContext)) {
            SendLaterScheduler.scheduleSoon(applicationContext, fromWorker = true)
        }
        return Result.success()
    }
}

object SendLaterScheduler {
    private const val WORK_NAME = "floodini_send_later"

    /** Keeps one retry chain alive; the worker re-arms itself while work remains. */
    fun scheduleSoon(context: Context, fromWorker: Boolean = false) {
        val request = OneTimeWorkRequest.Builder(SendQueueWorker::class.java)
            .setInitialDelay(1, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            if (fromWorker) ExistingWorkPolicy.APPEND_OR_REPLACE else ExistingWorkPolicy.KEEP,
            request,
        )
    }
}
