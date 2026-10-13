package com.valor.studyassistant

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StudyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.study_widget_layout).apply {
                val title = widgetData.getString("widget_title", "Study Assistant") ?: "Study Assistant"
                setTextViewText(R.id.widget_title, title)
                val line1 = widgetData.getString("widget_line1", "") ?: ""
                val line2 = widgetData.getString("widget_line2", "") ?: ""
                val line3 = widgetData.getString("widget_line3", "") ?: ""
                val next = widgetData.getString("widget_next", "") ?: ""
                setTextViewText(R.id.widget_line1, line1)
                setTextViewText(R.id.widget_line2, line2)
                setTextViewText(R.id.widget_line3, line3)
                setTextViewText(R.id.widget_next, next)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
