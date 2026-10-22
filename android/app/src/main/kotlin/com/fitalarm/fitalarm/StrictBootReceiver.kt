package com.fitalarm.fitalarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * If the phone was switched off while a strict alarm was active, reopen the
 * app after boot (the Dart side then rings the alarm again). Android may block
 * opening an activity straight from boot, so a full-screen alarm notification
 * is posted as well.
 */
class StrictBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!StrictState.isActive(context)) return
        StrictState.bringBack(context)

        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel("strict", "Strict alarm", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Reopens a strict alarm that wasn't finished"
            },
        )
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = Notification.Builder(context, "strict")
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle("Your alarm is still on")
            .setContentText("Finish it to turn it off")
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .setOngoing(true)
            .build()
        try {
            nm.notify(4242, n)
        } catch (_: SecurityException) {
        }
    }
}
