package com.floodini.app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * The persistent "send later" queue and the SMS sender. It is native on purpose:
 * [SendQueueWorker] runs with no Dart engine, and a single owner of the queue
 * means the app and the worker can never send the same message twice.
 */
object SendLaterQueue {
    private const val PREFS = "floodini_send_later"
    private const val KEY_QUEUE = "queue"
    private const val KEY_LOCATION = "location"
    private const val SEND_TIMEOUT_SECONDS = 60L

    // queueLock guards the stored queue (short); sendLock serialises send rounds
    // (long, a send can wait for the network) so the UI is never blocked by one.
    private val queueLock = Any()
    private val sendLock = Any()
    private val counter = AtomicInteger(0)

    fun hasSmsPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun loadQueue(context: Context): JSONArray =
        try {
            JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }

    private fun saveQueue(context: Context, queue: JSONArray) {
        prefs(context).edit().putString(KEY_QUEUE, queue.toString()).commit()
    }

    fun list(context: Context): String =
        synchronized(queueLock) { loadQueue(context).toString() }

    fun enqueue(context: Context, itemJson: String) {
        synchronized(queueLock) {
            val queue = loadQueue(context)
            queue.put(JSONObject(itemJson))
            saveQueue(context, queue)
        }
    }

    fun remove(context: Context, id: String) {
        synchronized(queueLock) {
            val queue = loadQueue(context)
            val kept = JSONArray()
            for (i in 0 until queue.length()) {
                val item = queue.getJSONObject(i)
                if (item.optString("id") != id) kept.put(item)
            }
            saveQueue(context, kept)
        }
    }

    fun hasPending(context: Context): Boolean = synchronized(queueLock) {
        val queue = loadQueue(context)
        for (i in 0 until queue.length()) {
            val recipients = queue.getJSONObject(i).optJSONArray("recipients") ?: continue
            for (j in 0 until recipients.length()) {
                if (!recipients.getJSONObject(j).optBoolean("sent")) return@synchronized true
            }
        }
        false
    }

    fun saveLocation(context: Context, lat: Double, lng: Double, accuracy: Double, timeMillis: Long) {
        val json = JSONObject()
            .put("lat", lat)
            .put("lng", lng)
            .put("accuracy", accuracy)
            .put("time", timeMillis)
        prefs(context).edit().putString(KEY_LOCATION, json.toString()).commit()
    }

    fun lastLocation(context: Context): String? = prefs(context).getString(KEY_LOCATION, null)

    /** Sends every unsent recipient of every queued message. Returns a JSON summary. */
    fun sendAll(context: Context): String = synchronized(sendLock) {
        if (!hasSmsPermission(context)) {
            return@synchronized summary(0, 0, "SMS permission not granted")
        }
        var sent = 0
        var failed = 0
        var error: String? = null
        val snapshot = JSONArray(list(context))
        loop@ for (i in 0 until snapshot.length()) {
            val item = snapshot.getJSONObject(i)
            val id = item.getString("id")
            val recipients = item.getJSONArray("recipients")
            for (j in 0 until recipients.length()) {
                val recipient = recipients.getJSONObject(j)
                if (recipient.optBoolean("sent")) continue
                val outcome = sendOne(context, recipient.getString("number"), buildText(context, item))
                if (outcome.ok) {
                    markRecipient(context, id, j, true, null)
                    sent++
                } else {
                    markRecipient(context, id, j, false, outcome.message)
                    failed++
                    error = outcome.message
                    // No signal: the rest would fail too, so wait for the next round.
                    if (outcome.noSignal) break@loop
                }
            }
        }
        summary(sent, failed, error)
    }

    private fun summary(sent: Int, failed: Int, error: String?): String =
        JSONObject()
            .put("sent", sent)
            .put("failed", failed)
            .put("error", error ?: JSONObject.NULL)
            .toString()

    private fun markRecipient(context: Context, id: String, index: Int, sent: Boolean, error: String?) {
        synchronized(queueLock) {
            val queue = loadQueue(context)
            for (i in 0 until queue.length()) {
                val item = queue.getJSONObject(i)
                if (item.optString("id") != id) continue
                val recipient = item.getJSONArray("recipients").optJSONObject(index) ?: return
                recipient.put("sent", sent)
                recipient.put("error", error ?: JSONObject.NULL)
                saveQueue(context, queue)
                return
            }
        }
    }

    private fun buildText(context: Context, item: JSONObject): String {
        val body = item.optString("template").replace("{LOCATION}", locationText(context))
        return "$body (Queued ${format(item.optLong("createdAt"))}.)"
    }

    private fun locationText(context: Context): String {
        val raw = lastLocation(context) ?: return "Location unknown."
        return try {
            val json = JSONObject(raw)
            String.format(
                Locale.US,
                "Last location (%s): https://maps.google.com/?q=%.5f,%.5f (about %d m accuracy).",
                format(json.getLong("time")),
                json.getDouble("lat"),
                json.getDouble("lng"),
                Math.round(json.optDouble("accuracy", 0.0)),
            )
        } catch (e: Exception) {
            "Location unknown."
        }
    }

    private fun format(millis: Long): String =
        SimpleDateFormat("MMM d HH:mm", Locale.US).format(Date(millis))

    private class Outcome(val ok: Boolean, val noSignal: Boolean, val message: String?)

    @Suppress("DEPRECATION")
    private fun sendOne(context: Context, number: String, text: String): Outcome {
        val sms: SmsManager = if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }
        val action = "com.floodini.app.SMS_SENT." + counter.incrementAndGet()
        val receiver = object : BroadcastReceiver() {
            lateinit var latch: CountDownLatch
            val failure = AtomicInteger(Activity.RESULT_OK)

            override fun onReceive(c: Context, intent: Intent) {
                if (resultCode != Activity.RESULT_OK) {
                    failure.compareAndSet(Activity.RESULT_OK, resultCode)
                }
                latch.countDown()
            }
        }
        try {
            val parts = sms.divideMessage(text)
            receiver.latch = CountDownLatch(parts.size)
            ContextCompat.registerReceiver(
                context,
                receiver,
                IntentFilter(action),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            val sentIntents = ArrayList<PendingIntent>()
            for (part in parts.indices) {
                sentIntents.add(
                    PendingIntent.getBroadcast(
                        context,
                        counter.incrementAndGet(),
                        Intent(action).setPackage(context.packageName),
                        PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            sms.sendMultipartTextMessage(number, null, parts, sentIntents, null)
            if (!receiver.latch.await(SEND_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                return Outcome(false, false, "No confirmation from the phone")
            }
            return when (val code = receiver.failure.get()) {
                Activity.RESULT_OK -> Outcome(true, false, null)
                SmsManager.RESULT_ERROR_NO_SERVICE -> Outcome(false, true, "No cellular service")
                SmsManager.RESULT_ERROR_RADIO_OFF -> Outcome(false, true, "Radio off (airplane mode?)")
                SmsManager.RESULT_ERROR_GENERIC_FAILURE -> Outcome(false, false, "The network rejected the message")
                else -> Outcome(false, false, "SMS error $code")
            }
        } catch (e: Exception) {
            return Outcome(false, false, e.message ?: e.javaClass.simpleName)
        } finally {
            try {
                context.unregisterReceiver(receiver)
            } catch (e: Exception) {
                // Never registered, or already gone.
            }
        }
    }
}
