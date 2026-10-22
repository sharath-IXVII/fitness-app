package com.fitalarm.fitalarm

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Strict alarm mode: while a strict alarm is active the app keeps itself in
 * front. Leaving it (home, recents, another app) brings it straight back,
 * and the screen is pinned when the system allows it. The Dart side engages
 * and releases this through the "fitalarm/strict" channel.
 */
class MainActivity : FlutterActivity() {
    companion object {
        /** Survives the activity being recreated while the process lives. */
        @Volatile var strict = false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var inFront = false

    private val bringBack = object : Runnable {
        override fun run() {
            if (!strict || inFront) return
            try {
                applicationContext.startActivity(
                    Intent(applicationContext, MainActivity::class.java).addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    ),
                )
            } catch (_: Exception) {
            }
            // Keep trying until we're back in front (the launch can be
            // deferred by the system right after the home button).
            handler.postDelayed(this, 1200)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitalarm/strict").setMethodCallHandler { call, result ->
            when (call.method) {
                "engage" -> {
                    engageStrict()
                    result.success(null)
                }
                "release" -> {
                    releaseStrict()
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun engageStrict() {
        strict = true
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            startLockTask()
        } catch (_: Exception) {
            // Screen pinning unavailable; the bring-back loop still applies.
        }
    }

    private fun releaseStrict() {
        strict = false
        handler.removeCallbacks(bringBack)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            stopLockTask()
        } catch (_: Exception) {
        }
    }

    override fun onResume() {
        super.onResume()
        inFront = true
        handler.removeCallbacks(bringBack)
        if (strict) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onPause() {
        super.onPause()
        inFront = false
        if (strict) handler.postDelayed(bringBack, 300)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (strict) handler.postDelayed(bringBack, 150)
    }
}
