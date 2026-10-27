package com.GetYr_io.FittArc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarting the phone is the emergency exit from strict mode. After a boot
 * the strict flag is cleared, so the app does not reopen itself and the alarm
 * does not ring again. The screens tell people this up front.
 */
class StrictBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        StrictState.clear(context)
    }
}
