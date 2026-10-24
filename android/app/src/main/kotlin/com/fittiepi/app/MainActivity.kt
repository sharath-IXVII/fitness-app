package com.fittiepi.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Strict alarm mode. While a strict alarm is active and the user leaves the
 * app, a full-screen "Your alarm is still on" panel covers other apps and the
 * app brings itself back. Showing the panel is also what lets Android 15+
 * allow the app to reopen itself. The Dart side drives this over the
 * "fittiepi/strict" channel.
 */
class MainActivity : FlutterActivity() {
    companion object {
        /** Survive the activity being recreated while the process lives. */
        @Volatile var strict = false

        /** True while the app itself opens a permission dialog or settings
         *  page, so strict mode doesn't pull the user straight back. */
        @Volatile var suspended = false
        private var overlay: View? = null

        /** The "Your alarm is still on" notification posted after a reboot. */
        const val BOOT_NOTIFICATION_ID = 4242
    }

    private val handler = Handler(Looper.getMainLooper())
    private var inFront = false

    private val bringBack = object : Runnable {
        override fun run() {
            if (!strict || inFront || suspended) return
            StrictState.bringBack(applicationContext)
            // Keep trying until we're back in front; the system can defer a
            // launch right after the home button.
            handler.postDelayed(this, 1200)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fittiepi/strict").setMethodCallHandler { call, result ->
            when (call.method) {
                "engage" -> {
                    engageStrict()
                    result.success(null)
                }
                "release" -> {
                    releaseStrict()
                    result.success(null)
                }
                "suspend" -> {
                    suspended = true
                    handler.removeCallbacks(bringBack)
                    result.success(null)
                }
                "resume" -> {
                    suspended = false
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun open(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
        }
    }

    private fun engageStrict() {
        strict = true
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            startLockTask()
        } catch (_: Exception) {
            // Screen pinning unavailable; the panel and bring-back still apply.
        }
    }

    private fun releaseStrict() {
        strict = false
        suspended = false
        cancelBootNotification()
        handler.removeCallbacks(bringBack)
        hideOverlay(applicationContext)
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
        hideOverlay(applicationContext)
        if (strict) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (!strict && !StrictState.isActive(applicationContext)) cancelBootNotification()
    }

    private fun cancelBootNotification() {
        try {
            getSystemService(android.app.NotificationManager::class.java)?.cancel(BOOT_NOTIFICATION_ID)
        } catch (_: Exception) {
        }
    }

    override fun onPause() {
        super.onPause()
        inFront = false
        if (strict && !suspended) {
            showOverlay(applicationContext)
            handler.postDelayed(bringBack, 300)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (strict && !suspended) {
            showOverlay(applicationContext)
            handler.postDelayed(bringBack, 150)
        }
    }

    /** Full-screen panel over other apps while a strict alarm is unfinished. */
    private fun showOverlay(context: Context) {
        if (overlay != null || !Settings.canDrawOverlays(context)) return
        val wm = context.getSystemService(WindowManager::class.java) ?: return
        val dp = context.resources.displayMetrics.density
        val panel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#FAF6EF"))
            setPadding((32 * dp).toInt(), 0, (32 * dp).toInt(), 0)
            addView(TextView(context).apply {
                text = "Your alarm is still on"
                textSize = 24f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#3A2E25"))
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = "Finish your workout or challenge to unlock your phone."
                textSize = 15f
                setTextColor(Color.parseColor("#6E5C4B"))
                gravity = Gravity.CENTER
                setPadding(0, (10 * dp).toInt(), 0, (28 * dp).toInt())
            })
            addView(TextView(context).apply {
                text = "Back to alarm"
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding((36 * dp).toInt(), (16 * dp).toInt(), (36 * dp).toInt(), (16 * dp).toInt())
                background = GradientDrawable().apply {
                    cornerRadius = 20 * dp
                    setColor(Color.parseColor("#A47551"))
                }
                setOnClickListener { StrictState.bringBack(context) }
            })
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.OPAQUE,
        )
        try {
            wm.addView(panel, params)
            overlay = panel
        } catch (_: Exception) {
        }
    }

    private fun hideOverlay(context: Context) {
        val v = overlay ?: return
        overlay = null
        try {
            context.getSystemService(WindowManager::class.java)?.removeView(v)
        } catch (_: Exception) {
        }
    }
}
