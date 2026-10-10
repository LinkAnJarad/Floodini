package com.floodini.app

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
        if (SendLaterQueue.hasPending(this)) SendLaterScheduler.scheduleSoon(this)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasSmsPermission" -> result.success(SendLaterQueue.hasSmsPermission(this))
            "requestSmsPermission" -> {
                if (SendLaterQueue.hasSmsPermission(this)) {
                    result.success(true)
                } else {
                    pendingPermission?.success(false)
                    pendingPermission = result
                    requestPermissions(arrayOf(Manifest.permission.SEND_SMS), SMS_REQUEST)
                }
            }
            "list" -> result.success(SendLaterQueue.list(this))
            "enqueue" -> {
                SendLaterQueue.enqueue(this, call.arguments as String)
                SendLaterScheduler.scheduleSoon(this)
                result.success(null)
            }
            "remove" -> {
                SendLaterQueue.remove(this, call.arguments as String)
                result.success(null)
            }
            "sendNow" -> {
                val context = applicationContext
                Thread {
                    val summary = SendLaterQueue.sendAll(context)
                    if (SendLaterQueue.hasPending(context)) SendLaterScheduler.scheduleSoon(context)
                    runOnUiThread { result.success(summary) }
                }.start()
            }
            "saveLocation" -> {
                val args = call.arguments as Map<*, *>
                SendLaterQueue.saveLocation(
                    this,
                    (args["lat"] as Number).toDouble(),
                    (args["lng"] as Number).toDouble(),
                    (args["accuracy"] as Number).toDouble(),
                    (args["time"] as Number).toLong(),
                )
                result.success(null)
            }
            "lastLocation" -> result.success(SendLaterQueue.lastLocation(this))
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_REQUEST) {
            pendingPermission?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
            )
            pendingPermission = null
        }
    }

    companion object {
        private const val CHANNEL = "com.floodini.app/send_later"
        private const val SMS_REQUEST = 4711
    }
}
