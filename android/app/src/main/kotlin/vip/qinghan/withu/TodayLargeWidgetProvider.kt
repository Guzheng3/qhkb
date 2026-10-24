package vip.qinghan.withu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import java.util.Calendar
import kotlin.math.roundToInt

/**
 * 今日课程列表 4×3（320×279dp）。
 *
 * 视觉基线取自情侣课表演示稿的「今日课程列表」大卡：白底圆角 18、7×10 内边距、
 * 10sp hint 表头、最多 4 条 52dp 课程行、页脚钉底。数据仍走今日系列快照：
 * 正常态列今日剩余课程，课程全部结束/无课时列明日课程；天气与课程颜色复用
 * 情侣卡片同源实现，避免两套视觉漂移。
 */
class TodayLargeWidgetProvider : BaseQinghanWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        TodayLargeWidgetProvider::class.java

    companion object {
        private const val MAX_ROWS = 4

        private val ROW_IDS = intArrayOf(
            R.id.widget_large_row_1,
            R.id.widget_large_row_2,
            R.id.widget_large_row_3,
            R.id.widget_large_row_4,
        )
        private val BAR_IDS = intArrayOf(
            R.id.widget_large_row_1_bar,
            R.id.widget_large_row_2_bar,
            R.id.widget_large_row_3_bar,
            R.id.widget_large_row_4_bar,
        )
        private val NAME_IDS = intArrayOf(
            R.id.widget_large_row_1_name,
            R.id.widget_large_row_2_name,
            R.id.widget_large_row_3_name,
            R.id.widget_large_row_4_name,
        )
        private val WEATHER_ICON_IDS = intArrayOf(
            R.id.widget_large_row_1_weather_icon,
            R.id.widget_large_row_2_weather_icon,
            R.id.widget_large_row_3_weather_icon,
            R.id.widget_large_row_4_weather_icon,
        )
        private val WEATHER_TEXT_IDS = intArrayOf(
            R.id.widget_large_row_1_weather_text,
            R.id.widget_large_row_2_weather_text,
            R.id.widget_large_row_3_weather_text,
            R.id.widget_large_row_4_weather_text,
        )
        private val LOCATION_IDS = intArrayOf(
            R.id.widget_large_row_1_location,
            R.id.widget_large_row_2_location,
            R.id.widget_large_row_3_location,
            R.id.widget_large_row_4_location,
        )
        private val TIME_IDS = intArrayOf(
            R.id.widget_large_row_1_time,
            R.id.widget_large_row_2_time,
            R.id.widget_large_row_3_time,
            R.id.widget_large_row_4_time,
        )
        private val PROGRESS_IDS = intArrayOf(
            R.id.widget_large_row_1_progress,
            R.id.widget_large_row_2_progress,
            R.id.widget_large_row_3_progress,
            R.id.widget_large_row_4_progress,
        )
        private val DIVIDER_IDS = intArrayOf(
            R.id.widget_large_divider_1,
            R.id.widget_large_divider_2,
            R.id.widget_large_divider_3,
        )

        fun updateAll(context: Context) {
            TodayLargeWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_large)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val accentColor = ContextCompat.getColor(context, R.color.widget_couple_male_accent)

        val nowMinutes = currentMinutes()
        val showingTomorrow = snapshot != null &&
            TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
        val tomorrowCourses = snapshot?.tomorrowCourses.orEmpty()
        val todayRemaining = snapshot?.visibleTodayCourses.orEmpty().filter { course ->
            val endMinutes = courseEndMinutes(course)
            endMinutes == null || endMinutes > nowMinutes
        }
        val displayCourses = when {
            snapshot == null -> emptyList()
            showingTomorrow -> tomorrowCourses.take(MAX_ROWS)
            else -> todayRemaining.take(MAX_ROWS)
        }

        views.setTextViewText(
            R.id.widget_large_heading,
            context.getString(R.string.widget_today_list_title),
        )
        views.setTextViewText(
            R.id.widget_large_week,
            if (snapshot == null) {
                ""
            } else {
                context.getString(
                    R.string.widget_week_number,
                    if (showingTomorrow) snapshot.tomorrowWeek else snapshot.currentWeek,
                )
            },
        )

        bindCourseRows(
            context = context,
            views = views,
            courses = displayCourses,
            showingTomorrow = showingTomorrow,
            nowMinutes = nowMinutes,
            widthDp = profile.widthDp,
            accentColor = accentColor,
        )

        val emptyText = when {
            snapshot == null -> context.getString(R.string.widget_tap_to_open)
            displayCourses.isNotEmpty() -> null
            snapshot.totalTodayCourseCount > 0 || snapshot.todayCourses.isNotEmpty() ->
                context.getString(R.string.widget_couple_today_ended)
            else -> context.getString(R.string.widget_couple_no_course_today)
        }
        if (emptyText == null) {
            views.setViewVisibility(R.id.widget_large_empty, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_large_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_large_empty, emptyText)
        }

        val footerText = when {
            snapshot == null -> null
            displayCourses.isNotEmpty() && !showingTomorrow -> {
                val total = snapshot.todayCourses.size.takeIf { it > 0 }
                    ?: snapshot.totalTodayCourseCount
                context.getString(
                    R.string.widget_couple_today_remaining,
                    todayRemaining.size,
                    total,
                )
            }
            showingTomorrow ->
                context.getString(R.string.widget_couple_tomorrow_count, tomorrowCourses.size)
            else -> context.getString(R.string.widget_couple_no_course_tomorrow)
        }
        if (footerText == null) {
            views.setViewVisibility(R.id.widget_large_footer, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_large_footer, View.VISIBLE)
            views.setTextViewText(R.id.widget_large_footer, footerText)
        }

        views.setOnClickPendingIntent(
            R.id.widget_large_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindCourseRows(
        context: Context,
        views: RemoteViews,
        courses: List<TodayWidgetCourseInfo>,
        showingTomorrow: Boolean,
        nowMinutes: Int,
        widthDp: Int,
        accentColor: Int,
    ) {
        val weatherLookup = CoupleWidgetWeatherSource.lookup(context)
        val weatherDateMillis = Calendar.getInstance().apply {
            if (showingTomorrow) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }.timeInMillis
        val weatherBitmaps = HashMap<String, Bitmap>()
        // 行内进度条宽度 = 卡片宽 - 左右内边距(20) - 行内边距(8) - 色条(3) - 间距(6)。
        val progressWidthDp = (widthDp - 37).coerceAtLeast(80)

        for (index in 0 until MAX_ROWS) {
            val course = courses.getOrNull(index)
            if (course == null) {
                views.setViewVisibility(ROW_IDS[index], View.GONE)
                continue
            }
            views.setViewVisibility(ROW_IDS[index], View.VISIBLE)
            views.setTextViewText(NAME_IDS[index], displayCourseName(course))
            views.setTextViewText(LOCATION_IDS[index], course.location.ifBlank { " " })
            views.setTextViewText(
                TIME_IDS[index],
                "${course.startTime} - ${course.endTime}",
            )
            views.setInt(
                BAR_IDS[index],
                "setColorFilter",
                parseCourseColor(course.color, accentColor),
            )

            val ongoing = isOngoing(course, nowMinutes)
            // RemoteViews 复用视图时上一行的「进行中」底色会残留，先清掉。
            views.setInt(ROW_IDS[index], "setBackgroundColor", Color.TRANSPARENT)
            if (ongoing) {
                views.setInt(
                    ROW_IDS[index],
                    "setBackgroundResource",
                    R.drawable.widget_couple_current_bg,
                )
            }
            val fraction = if (ongoing) progressFraction(course, nowMinutes) else null
            if (fraction == null) {
                views.setViewVisibility(PROGRESS_IDS[index], View.GONE)
            } else {
                views.setImageViewBitmap(
                    PROGRESS_IDS[index],
                    createProgressBitmap(context, fraction, progressWidthDp),
                )
                views.setViewVisibility(PROGRESS_IDS[index], View.VISIBLE)
            }

            val weather = weatherLookup?.invoke(
                weatherDateMillis,
                course.startTime,
                course.endTime,
            )
            if (weather == null) {
                views.setViewVisibility(WEATHER_ICON_IDS[index], View.GONE)
                views.setViewVisibility(WEATHER_TEXT_IDS[index], View.GONE)
            } else {
                val bitmap = weatherBitmaps.getOrPut(weather.kind) {
                    CoupleTimetableRenderSupport.createWeatherBitmap(context, weather.kind)
                }
                views.setImageViewBitmap(WEATHER_ICON_IDS[index], bitmap)
                views.setViewVisibility(WEATHER_ICON_IDS[index], View.VISIBLE)
                val temperature = weather.temperatureC
                if (temperature == null) {
                    views.setViewVisibility(WEATHER_TEXT_IDS[index], View.GONE)
                } else {
                    views.setTextViewText(WEATHER_TEXT_IDS[index], "$temperature°")
                    views.setViewVisibility(WEATHER_TEXT_IDS[index], View.VISIBLE)
                }
            }
        }

        DIVIDER_IDS.forEachIndexed { index, dividerId ->
            views.setViewVisibility(
                dividerId,
                if (courses.size > index + 1) View.VISIBLE else View.GONE,
            )
        }
    }

    private fun currentMinutes(): Int {
        val calendar = Calendar.getInstance()
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }

    private fun courseEndMinutes(course: TodayWidgetCourseInfo): Int? {
        return CoupleTimetableDisplayBuilder.parseClockMinutes(course.endTime)
    }

    private fun isOngoing(course: TodayWidgetCourseInfo, nowMinutes: Int): Boolean {
        val start = CoupleTimetableDisplayBuilder.parseClockMinutes(course.startTime)
            ?: return false
        val end = courseEndMinutes(course) ?: return false
        return end > start && nowMinutes >= start && nowMinutes < end
    }

    private fun progressFraction(
        course: TodayWidgetCourseInfo,
        nowMinutes: Int,
    ): Float? {
        val start = CoupleTimetableDisplayBuilder.parseClockMinutes(course.startTime)
            ?: return null
        val end = courseEndMinutes(course) ?: return null
        if (end <= start || nowMinutes <= start || nowMinutes >= end) {
            return null
        }
        return ((nowMinutes - start).toFloat() / (end - start).toFloat())
            .coerceIn(0f, 1f)
    }

    /** 课名最多 7 个 Unicode 码点；超出按演示稿直接截断。 */
    private fun displayCourseName(course: TodayWidgetCourseInfo): String {
        val text = course.shortName?.takeIf { it.isNotBlank() } ?: course.name
        if (text.isEmpty()) {
            return text
        }
        return if (text.codePointCount(0, text.length) <= 7) {
            text
        } else {
            text.substring(0, text.offsetByCodePoints(0, 7))
        }
    }

    private fun parseCourseColor(value: String?, fallback: Int): Int {
        if (value.isNullOrBlank()) {
            return fallback
        }
        return try {
            Color.parseColor(value.trim())
        } catch (_: IllegalArgumentException) {
            fallback
        }
    }

    /**
     * 进行中的连续进度条：没有课间数据，不画断点（不臆造 gaps）。
     * 演示稿高度 3dp，轨道与填充均为圆角，填充色用品牌蓝。
     */
    private fun createProgressBitmap(
        context: Context,
        fraction: Float,
        widthDp: Int,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt().coerceAtLeast(2)
        val height = (3f * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = height / 2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = ContextCompat.getColor(context, R.color.widget_couple_track)
        canvas.drawRoundRect(
            RectF(0f, 0f, width.toFloat(), height.toFloat()),
            radius,
            radius,
            paint,
        )
        val filled = width * fraction.coerceIn(0f, 1f)
        if (filled > 0f) {
            paint.color = ContextCompat.getColor(context, R.color.widget_couple_male_accent)
            canvas.drawRoundRect(
                RectF(0f, 0f, filled, height.toFloat()),
                radius,
                radius,
                paint,
            )
        }
        return bitmap
    }
}
