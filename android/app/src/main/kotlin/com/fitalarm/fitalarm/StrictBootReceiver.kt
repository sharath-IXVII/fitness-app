package com.fitalarm.fitalarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * If the phone was switched off while a strict alarm was active, reopen the
 * app after boot; the Dart side then rings the alarm again.
 */
class StrictBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.contains("flutter.strict.active.v1")) return
        try {
            context.startActivity(
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {
        }
    }
}
