package com.GetYr_io.FittArc

import android.content.Context
import android.content.Intent

/**
 * Whether a strict alarm is active. Saved by the Dart side in shared
 * preferences ("strict.active.v1"), so it survives the app being killed or
 * the phone restarting.
 */
object StrictState {
    private const val PREFS = "FlutterSharedPreferences"
    private const val ACTIVE = "flutter.strict.active.v1"
    fun isActive(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).contains(ACTIVE)

    /** Opens the app on top of whatever is showing. */
    fun bringBack(context: Context) {
        try {
            context.startActivity(
                Intent(context, MainActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            )
        } catch (_: Exception) {
        }
    }
}
