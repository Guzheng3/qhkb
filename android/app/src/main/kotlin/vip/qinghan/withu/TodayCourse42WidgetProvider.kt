package vip.qinghan.withu

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 今日课程 4×2：4×1 横条的加高版。
 *
 * 头部（状态 chip | 周数）与 hero 行完全复用 [TodayStripWidgetProvider]，
 * 多出来的高度补两行「接下来」——色条 + 课名 + 时间，字号沿用情侣卡片
 * （13sp / 10sp）。单人的：课表来源与其它单人卡片一致（当前课表不是 TA
 * 的导入副本时用它，见 TodayWidgetSupport.readOwnProfileJson）。
 */
class TodayCourse42WidgetProvider : TodayStripWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        TodayCourse42WidgetProvider::class.java

    override val layoutResId: Int get() = R.layout.widget_today_course_42

    companion object {
        private const val MAX_NAME_CODE_POINTS = 7
        private const val DAY_MILLIS = 86_400_000L

        fun updateAll(context: Context) {
            TodayCourse42WidgetProvider().updateAll(context)
        }
    }

    override fun bindExtras(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo?,
        nowMillis: Long,
    ) {
        val rows = trailingCourses(snapshot, nowMillis)
        val primaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_primary)
        val secondaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_secondary)
        val fallbackAccent = ContextCompat.getColor(context, R.color.widget_couple_male_accent)
        val showLocation = snapshot?.showLocation ?: true
        val weatherLookup = CoupleWidgetWeatherSource.lookup(context)
        val weatherDateMillis = if (snapshot != null &&
            TodayWidgetSupport.isShowingTomorrowCourses(snapshot, nowMillis)
        ) {
            nowMillis + DAY_MILLIS
        } else {
            nowMillis
        }
        val weatherBitmaps = HashMap<String, Bitmap>()

        val rowIds = intArrayOf(R.id.widget_course42_row1, R.id.widget_course42_row2)
        val dividerIds = intArrayOf(
            R.id.widget_course42_divider,
            R.id.widget_course42_divider2,
        )
        val barIds = intArrayOf(R.id.widget_course42_bar1, R.id.widget_course42_bar2)
        val nameIds = intArrayOf(R.id.widget_course42_name1, R.id.widget_course42_name2)
        val locationIds = intArrayOf(
            R.id.widget_course42_location1,
            R.id.widget_course42_location2,
        )
        val timeIds = intArrayOf(R.id.widget_course42_time1, R.id.widget_course42_time2)
        val weatherIconIds = intArrayOf(
            R.id.widget_course42_weather_icon1,
            R.id.widget_course42_weather_icon2,
        )
        val weatherTempIds = intArrayOf(
            R.id.widget_course42_weather_temp1,
            R.id.widget_course42_weather_temp2,
        )

        rowIds.indices.forEach { index ->
            val course = rows.getOrNull(index)
            if (course == null) {
                views.setViewVisibility(rowIds[index], View.GONE)
                return@forEach
            }
            views.setViewVisibility(rowIds[index], View.VISIBLE)
            views.setTextViewText(nameIds[index], displayName(course))
            views.setTextColor(nameIds[index], primaryColor)
            views.setTextViewText(timeIds[index], timeText(course))
            views.setTextColor(timeIds[index], secondaryColor)
            views.setInt(barIds[index], "setColorFilter", parseColor(course.color, fallbackAccent))
            views.setViewVisibility(barIds[index], View.VISIBLE)

            val location = course.location.takeIf { showLocation && it.isNotBlank() }
            if (location == null) {
                views.setTextViewText(locationIds[index], "")
                views.setViewVisibility(locationIds[index], View.GONE)
            } else {
                views.setTextViewText(locationIds[index], location)
                views.setTextColor(locationIds[index], secondaryColor)
                views.setViewVisibility(locationIds[index], View.VISIBLE)
            }

            val weather = weatherLookup?.invoke(
                weatherDateMillis,
                course.startTime,
                course.endTime,
            )
            if (weather == null) {
                views.setViewVisibility(weatherIconIds[index], View.GONE)
                views.setViewVisibility(weatherTempIds[index], View.GONE)
            } else {
                val bitmap = weatherBitmaps.getOrPut(weather.kind) {
                    CoupleTimetableRenderSupport.createWeatherBitmap(context, weather.kind)
                }
                views.setImageViewBitmap(weatherIconIds[index], bitmap)
                views.setViewVisibility(weatherIconIds[index], View.VISIBLE)
                val temperature = weather.temperatureC
                if (temperature == null) {
                    views.setViewVisibility(weatherTempIds[index], View.GONE)
                } else {
                    views.setTextViewText(weatherTempIds[index], "$temperature°")
                    views.setTextColor(weatherTempIds[index], secondaryColor)
                    views.setViewVisibility(weatherTempIds[index], View.VISIBLE)
                }
            }
        }

        // 分割线跟随实际行数：没有接下来课程时不留悬空的线。
        dividerIds.forEachIndexed { index, dividerId ->
            views.setViewVisibility(
                dividerId,
                if (rows.size > index) View.VISIBLE else View.GONE,
            )
        }
    }

    /** hero 之后的课程：明日预告时取明日第 2 条起，今日则取还没结束的课。 */
    private fun trailingCourses(
        snapshot: TodayWidgetSnapshotInfo?,
        nowMillis: Long,
    ): List<TodayWidgetCourseInfo> {
        if (snapshot == null) {
            return emptyList()
        }
        if (TodayWidgetSupport.isShowingTomorrowCourses(snapshot, nowMillis)) {
            return snapshot.tomorrowCourses.drop(1).take(2)
        }
        val nowTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(nowMillis))
        val heroId = snapshot.highlightedCourse?.id
        return snapshot.visibleTodayCourses
            .filter { it.endTime > nowTime && it.id != heroId }
            .take(2)
    }

    private fun displayName(course: TodayWidgetCourseInfo): String {
        val text = course.shortName?.takeIf { it.isNotBlank() } ?: course.name
        return if (text.codePointCount(0, text.length) <= MAX_NAME_CODE_POINTS) {
            text
        } else {
            text.substring(0, text.offsetByCodePoints(0, MAX_NAME_CODE_POINTS))
        }
    }

    private fun timeText(course: TodayWidgetCourseInfo): String {
        return if (course.startTime.isNotBlank() && course.endTime.isNotBlank()) {
            "${course.startTime} - ${course.endTime}"
        } else {
            ""
        }
    }

    private fun parseColor(value: String?, fallback: Int): Int {
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
