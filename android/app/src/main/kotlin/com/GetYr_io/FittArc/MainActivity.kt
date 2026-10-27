package com.GetYr_io.FittArc

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.ImageView
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
 *
 * Sleep mode is the same idea for bedtime: other apps are blocked until the
 * chosen end time, but the phone app stays available. Calls (ringing or in
 * progress) and the dialer are never covered. There is no exit button; a
 * restart releases it (see SleepMode in Dart).
 */
class MainActivity : FlutterActivity() {
    companion object {
        /** Survive the activity being recreated while the process lives. */
        @Volatile var strict = false

        /** True while the app itself opens a permission dialog or settings
         *  page, so strict mode doesn't pull the user straight back. */
        @Volatile var suspended = false
        private var overlay: View? = null

        /** Sleep mode: other apps are blocked until [sleepEndMs]. */
        @Volatile var sleepLock = false
        @Volatile var sleepEndMs = 0L

        /** The dialer was opened from the app; don't pull the user back for a while. */
        @Volatile var dialerUntil = 0L

        /** The "Your alarm is still on" notification posted after a reboot. */
        const val BOOT_NOTIFICATION_ID = 4242
    }

    private val handler = Handler(Looper.getMainLooper())
    private var inFront = false

    private fun locked() = strict || sleepLock

    private fun callActive(): Boolean {
        val mode = (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.mode ?: AudioManager.MODE_NORMAL
        return mode == AudioManager.MODE_RINGTONE || mode == AudioManager.MODE_IN_CALL ||
            mode == AudioManager.MODE_IN_COMMUNICATION
    }

    private fun dialerActive() = System.currentTimeMillis() < dialerUntil

    private val bringBack = object : Runnable {
        override fun run() {
            if (sleepLock && System.currentTimeMillis() >= sleepEndMs) {
                releaseSleep()
                return
            }
            if (!locked() || inFront || suspended) return
            if (sleepLock) {
                // A sleeping phone's screen stays off: don't wake it to pull
                // the app back. Wait until the screen is on again.
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                if (pm != null && !pm.isInteractive) {
                    handler.postDelayed(this, 3000)
                    return
                }
                // Never cover a call or the dialer; wait until they are over.
                if (callActive() || dialerActive()) {
                    hideOverlay(applicationContext)
                    handler.postDelayed(this, 1500)
                    return
                }
                showOverlay(applicationContext)
            }
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
                "engageSleep" -> {
                    sleepEndMs = (call.arguments as? Number)?.toLong() ?: 0L
                    sleepLock = true
                    result.success(null)
                }
                "releaseSleep" -> {
                    releaseSleep()
                    result.success(null)
                }
                "openDialer" -> {
                    val number = call.arguments as? String
                    dialerUntil = System.currentTimeMillis() + 180_000
                    hideOverlay(applicationContext)
                    open(Intent(Intent.ACTION_DIAL, if (number == null) Uri.parse("tel:") else Uri.parse("tel:$number")))
                    result.success(null)
                }
                "bootCount" -> result.success(Settings.Global.getInt(contentResolver, "boot_count", 0))
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

    private fun releaseSleep() {
        sleepLock = false
        dialerUntil = 0L
        handler.removeCallbacks(bringBack)
        hideOverlay(applicationContext)
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
        if (sleepLock && System.currentTimeMillis() >= sleepEndMs) releaseSleep()
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
        } else if (sleepLock && !suspended) {
            // Wait a moment first: a call or the dialer must not be covered.
            handler.postDelayed(bringBack, 1200)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (strict && !suspended) {
            showOverlay(applicationContext)
            handler.postDelayed(bringBack, 150)
        } else if (sleepLock && !suspended) {
            handler.postDelayed(bringBack, 1200)
        }
    }

    /** Full-screen panel over other apps while a strict alarm is unfinished. */
    private fun showOverlay(context: Context) {
        if (overlay != null || !Settings.canDrawOverlays(context)) return
        val wm = context.getSystemService(WindowManager::class.java) ?: return
        val dp = context.resources.displayMetrics.density
        // Fittarc's own night-blue look (the same navy as the app icon), so
        // the panel never looks like a different app.
        val panel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0C1B37"))
            setPadding((32 * dp).toInt(), 0, (32 * dp).toInt(), 0)
            addView(ImageView(context).apply {
                setImageResource(R.drawable.notif_large)
                layoutParams = LinearLayout.LayoutParams((84 * dp).toInt(), (84 * dp).toInt()).apply {
                    bottomMargin = (22 * dp).toInt()
                }
                outlineProvider = object : ViewOutlineProvider() {
                    override fun getOutline(view: View, outline: Outline) {
                        outline.setRoundRect(0, 0, view.width, view.height, 20 * dp)
                    }
                }
                clipToOutline = true
            })
            addView(TextView(context).apply {
                text = if (sleepLock) "Sleep mode is on" else "Your alarm is still on"
                textSize = 24f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = if (sleepLock) {
                    "Time to rest. Calls still work. In an emergency, restart your phone to unlock it."
                } else {
                    "Finish your workout or challenge to unlock your phone. In an emergency, restart your phone."
                }
                textSize = 15f
                setTextColor(Color.parseColor("#B9C8E0"))
                gravity = Gravity.CENTER
                setPadding(0, (10 * dp).toInt(), 0, (28 * dp).toInt())
            })
            addView(TextView(context).apply {
                text = if (sleepLock) "Back to Fittarc" else "Back to alarm"
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#06142B"))
                gravity = Gravity.CENTER
                setPadding((36 * dp).toInt(), (16 * dp).toInt(), (36 * dp).toInt(), (16 * dp).toInt())
                background = GradientDrawable().apply {
                    cornerRadius = 20 * dp
                    setColor(Color.parseColor("#9AD3FF"))
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
