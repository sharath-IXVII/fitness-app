package com.GetYr_io.FittArc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home screen widget: streak, today's score, steps and water. The app writes the numbers. */
class FittArcWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fittarc_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "0") ?: "0")
                setTextViewText(R.id.widget_score, widgetData.getString("score", "0") ?: "0")
                setTextViewText(R.id.widget_steps, widgetData.getString("steps", "0") ?: "0")
                setTextViewText(R.id.widget_water, widgetData.getString("water", "0 L") ?: "0 L")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
