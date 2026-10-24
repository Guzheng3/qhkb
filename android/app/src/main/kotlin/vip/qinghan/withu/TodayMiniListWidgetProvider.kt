package vip.qinghan.withu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 今日课程迷你列表 2×2。
 *
 * 视觉对齐 demo 的「课程卡片迷你」：白底 18dp 圆角（夜间自动换深色变体）、
 * 7dp/10dp 内边距、顶部「接下来 / 明天 · 第N周」小字头、逐条 3dp 色条 +
 * 课名（最多 7 个码点）+ 课程时段右侧天气、底部「还有 N 节」。
 * 不再套用其它今日卡片的背景风格 / 自适应内边距 / 状态芯片，demo 观感优先。
 */
class TodayMiniListWidgetProvider : BaseQinghanWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        TodayMiniListWidgetProvider::class.java

    companion object {
        private const val MAX_ROWS = 3
        private const val NAME_MAX_CODE_POINTS = 7
        private const val DAY_MILLIS = 86_400_000L

        private val rowIds = arrayOf(
            MiniRowIds(
                root = R.id.widget_mini_row_1,
                bar = R.id.widget_mini_row_1_bar,
                name = R.id.widget_mini_row_1_name,
                time = R.id.widget_mini_row_1_time,
                weatherIcon = R.id.widget_mini_row_1_weather_icon,
                weatherText = R.id.widget_mini_row_1_weather_text,
            ),
            MiniRowIds(
                root = R.id.widget_mini_row_2,
                bar = R.id.widget_mini_row_2_bar,
                name = R.id.widget_mini_row_2_name,
                time = R.id.widget_mini_row_2_time,
                weatherIcon = R.id.widget_mini_row_2_weather_icon,
                weatherText = R.id.widget_mini_row_2_weather_text,
            ),
            MiniRowIds(
                root = R.id.widget_mini_row_3,
                bar = R.id.widget_mini_row_3_bar,
                name = R.id.widget_mini_row_3_name,
                time = R.id.widget_mini_row_3_time,
                weatherIcon = R.id.widget_mini_row_3_weather_icon,
                weatherText = R.id.widget_mini_row_3_weather_text,
            ),
        )

        fun updateAll(context: Context) {
            TodayMiniListWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_mini_list)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val primaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_primary)
        val secondaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_secondary)
        val hintColor = ContextCompat.getColor(context, R.color.widget_couple_text_hint)
        val fallbackBarColor = ContextCompat.getColor(context, R.color.widget_couple_male_accent)
        val nowMillis = System.currentTimeMillis()
        val weatherLookup = CoupleWidgetWeatherSource.lookup(context)

        views.setTextColor(R.id.widget_mini_heading, hintColor)
        views.setTextColor(R.id.widget_mini_week, hintColor)
        views.setTextColor(R.id.widget_mini_empty, hintColor)
        views.setTextColor(R.id.widget_mini_more, secondaryColor)

        if (snapshot == null) {
            views.setTextViewText(
                R.id.widget_mini_heading,
                context.getString(R.string.widget_today_courses),
            )
            views.setTextViewText(R.id.widget_mini_week, context.getString(R.string.widget_app_name))
            views.setTextViewText(
                R.id.widget_mini_empty,
                context.getString(R.string.widget_open_app_sync),
            )
            views.setViewVisibility(R.id.widget_mini_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_mini_more, View.GONE)
            rowIds.forEach { ids ->
                bindRow(
                    context,
                    views,
                    ids,
                    course = null,
                    primaryColor = primaryColor,
                    secondaryColor = secondaryColor,
                    fallbackBarColor = fallbackBarColor,
                    weather = null,
                )
            }
        } else {
            // 只列表「还没结束」的课：与 demo 的 remaining 口径一致，
            // 底部「还有 N 节」也按这个列表的剩余条数算，不再把已上完的课算进去。
            val nowTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(nowMillis))
            val remainingToday = snapshot.visibleTodayCourses.filter { it.endTime > nowTime }
            val showingTomorrow = remainingToday.isEmpty()
            val source = if (showingTomorrow) snapshot.tomorrowCourses else remainingToday
            val rows = source.take(MAX_ROWS)

            views.setTextViewText(
                R.id.widget_mini_heading,
                context.getString(
                    if (showingTomorrow) {
                        R.string.widget_mini_list_tomorrow
                    } else {
                        R.string.widget_mini_list_next
                    }
                ),
            )
            views.setTextViewText(
                R.id.widget_mini_week,
                context.getString(
                    R.string.widget_week_number,
                    if (showingTomorrow) snapshot.tomorrowWeek else snapshot.currentWeek,
                ),
            )

            // 今天上完了且明日无课 → 「🌙 明日无课」；今天本来就没课（含假期）→
            // 「🍵 今天没有课程」，与 demo 的 weekend / endedNoTomorrow 两档一致。
            val emptyText = when {
                rows.isNotEmpty() -> ""
                snapshot.state == "completed" ->
                    context.getString(R.string.widget_mini_list_empty_tomorrow)
                else -> context.getString(R.string.widget_couple_no_course_today)
            }
            views.setViewVisibility(
                R.id.widget_mini_empty,
                if (emptyText.isBlank()) View.GONE else View.VISIBLE,
            )
            views.setTextViewText(R.id.widget_mini_empty, emptyText)

            val remainingCount = (source.size - rows.size).coerceAtLeast(0)
            views.setViewVisibility(
                R.id.widget_mini_more,
                if (remainingCount > 0) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(
                R.id.widget_mini_more,
                context.getString(R.string.widget_more_courses, remainingCount),
            )

            // 今日行按今天取天气，明日行按明天取；预报缺失时图标与温度一起隐藏。
            val weatherDateMillis = if (showingTomorrow) nowMillis + DAY_MILLIS else nowMillis
            rowIds.forEachIndexed { index, ids ->
                val course = rows.getOrNull(index)
                val weather = course?.let {
                    weatherLookup?.invoke(weatherDateMillis, it.startTime, it.endTime)
                }
                bindRow(
                    context,
                    views,
                    ids,
                    course = course,
                    primaryColor = primaryColor,
                    secondaryColor = secondaryColor,
                    fallbackBarColor = fallbackBarColor,
                    weather = weather,
                )
            }
        }

        views.setOnClickPendingIntent(
            R.id.widget_mini_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindRow(
        context: Context,
        views: RemoteViews,
        ids: MiniRowIds,
        course: TodayWidgetCourseInfo?,
        primaryColor: Int,
        secondaryColor: Int,
        fallbackBarColor: Int,
        weather: CoupleWidgetWeather?,
    ) {
        if (course == null) {
            views.setViewVisibility(ids.root, View.GONE)
            return
        }
        views.setViewVisibility(ids.root, View.VISIBLE)
        views.setInt(ids.bar, "setColorFilter", parseCourseColor(course.color, fallbackBarColor))
        views.setTextColor(ids.name, primaryColor)
        views.setTextViewText(ids.name, miniCourseName(course))
        views.setTextColor(ids.time, secondaryColor)
        views.setTextViewText(ids.time, "${course.startTime} - ${course.endTime}")

        if (weather != null) {
            views.setImageViewBitmap(
                ids.weatherIcon,
                CoupleTimetableRenderSupport.createWeatherBitmap(context, weather.kind),
            )
            views.setViewVisibility(ids.weatherIcon, View.VISIBLE)
        } else {
            views.setViewVisibility(ids.weatherIcon, View.GONE)
        }
        val temperature = weather?.temperatureC
        if (temperature != null) {
            views.setTextColor(ids.weatherText, secondaryColor)
            views.setTextViewText(ids.weatherText, "$temperature°")
            views.setViewVisibility(ids.weatherText, View.VISIBLE)
        } else {
            views.setViewVisibility(ids.weatherText, View.GONE)
        }
    }

    /** 课名优先用短名；超过 7 个 Unicode 码点直接截断，不加省略号（对齐 demo）。 */
    private fun miniCourseName(course: TodayWidgetCourseInfo): String {
        val raw = course.shortName?.takeIf { it.isNotBlank() } ?: course.name
        if (raw.codePointCount(0, raw.length) <= NAME_MAX_CODE_POINTS) {
            return raw
        }
        return raw.substring(0, raw.offsetByCodePoints(0, NAME_MAX_CODE_POINTS))
    }

    private fun parseCourseColor(value: String?, fallback: Int): Int {
        if (value.isNullOrBlank()) {
            return fallback
        }
        return try {
            Color.parseColor(value)
        } catch (_: IllegalArgumentException) {
            fallback
        }
    }
}

private data class MiniRowIds(
    val root: Int,
    val bar: Int,
    val name: Int,
    val time: Int,
    val weatherIcon: Int,
    val weatherText: Int,
)
