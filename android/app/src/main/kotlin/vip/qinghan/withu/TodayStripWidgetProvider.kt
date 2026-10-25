package vip.qinghan.withu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * 今日课程横向长条 4×1。
 *
 * 视觉对齐 demo 的「今日横条」（320×93dp）：白卡 18dp 圆角（夜间自动换深色
 * 变体）+ 7dp/10dp 内边距，顶部一行「状态 chip | 第N周」，下方单条 hero 课程行
 * ——3dp 课程色条 + 课名 + 天气，第二行地点/时间。进行中的课整行淡蓝底并追加
 * 3dp 进度条。今日快照没有课间（breaks）数据，进度条按连续填充绘制，不编造断口。
 */
open class TodayStripWidgetProvider : BaseQinghanWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        TodayStripWidgetProvider::class.java

    /** 4×2 变体只在布局与下方追加行上有差别，其余渲染完全复用本类。 */
    protected open val layoutResId: Int get() = R.layout.widget_today_strip

    /** 子类在 hero 之后追加自己的内容（4×2 用来补「接下来」的课程行）。 */
    protected open fun bindExtras(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo?,
        nowMillis: Long,
    ) {
    }

    companion object {
        private const val NAME_MAX_CODE_POINTS = 7
        private const val DAY_MILLIS = 86_400_000L
        private const val PROGRESS_MIN_WIDTH_DP = 120
        /** 卡片左右 10+10、hero 行左右 4+6、色条 3、色条与正文间距 8。 */
        private const val HERO_CHROME_WIDTH_DP = 41

        fun updateAll(context: Context) {
            TodayStripWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, layoutResId)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val nowMillis = System.currentTimeMillis()

        val primaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_primary)
        val secondaryColor = ContextCompat.getColor(context, R.color.widget_couple_text_secondary)
        val hintColor = ContextCompat.getColor(context, R.color.widget_couple_text_hint)
        val fallbackAccent = ContextCompat.getColor(context, R.color.widget_couple_male_accent)

        val state = snapshot?.state ?: "no_course"
        val examSnapshot = snapshot?.takeIf {
            TodayWidgetSupport.isExamOngoing(it, nowMillis)
        }
        val examOngoing = examSnapshot != null
        val showingTomorrow = snapshot != null &&
            TodayWidgetSupport.isShowingTomorrowCourses(snapshot, nowMillis)

        // 状态 chip：考试进行中优先。明日预告不再占用 chip——demo 的 chip 只反映
        // 今日状态（正在上课 / 下一节课 / 今日已结束 / 今日无课）。
        val chipState = if (examOngoing) "ongoing" else state
        views.setTextViewText(
            R.id.widget_strip_status,
            if (examOngoing) {
                context.getString(R.string.widget_status_exam_ongoing)
            } else {
                TodayWidgetSupport.statusText(context, state)
            },
        )
        views.setInt(
            R.id.widget_strip_status,
            "setBackgroundResource",
            TodayWidgetSupport.statusBackgroundRes(chipState, "solid"),
        )
        views.setTextColor(
            R.id.widget_strip_status,
            TodayWidgetSupport.statusChipTextColor(chipState, "solid", context),
        )
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_strip_status, 8f)

        // 周数始终可见：320dp 宽度下 chip 与「第N周」不会互相挤压。
        views.setTextViewText(
            R.id.widget_strip_week,
            context.getString(R.string.widget_week_number, snapshot?.currentWeek ?: 1),
        )
        views.setTextColor(R.id.widget_strip_week, hintColor)
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_strip_week, 8.5f)
        views.setViewVisibility(R.id.widget_strip_week, View.VISIBLE)

        // hero 选择与 demo 同序：今日进行中/下一节 → 明日首课 → 空态。
        val todayCourse = if (!examOngoing && (state == "ongoing" || state == "upcoming")) {
            snapshot?.highlightedCourse
        } else {
            null
        }
        val tomorrowCourse = if (todayCourse == null && showingTomorrow) {
            snapshot?.tomorrowCourses?.firstOrNull()
        } else {
            null
        }
        val heroCourse = todayCourse ?: tomorrowCourse
        val isOngoing = todayCourse != null && state == "ongoing"

        when {
            heroCourse != null -> bindCourseHero(
                context = context,
                views = views,
                course = heroCourse,
                isTomorrow = tomorrowCourse != null,
                isOngoing = isOngoing,
                nowMillis = nowMillis,
                profile = profile,
                primaryColor = primaryColor,
                secondaryColor = secondaryColor,
                fallbackAccent = fallbackAccent,
                showLocation = snapshot?.showLocation ?: true,
            )

            examSnapshot != null -> bindExamHero(
                context = context,
                views = views,
                snapshot = examSnapshot,
                primaryColor = primaryColor,
                secondaryColor = secondaryColor,
                fallbackAccent = fallbackAccent,
                showLocation = examSnapshot.showLocation,
            )

            else -> bindEmptyHero(
                context = context,
                views = views,
                snapshot = snapshot,
                state = state,
                nowMillis = nowMillis,
                primaryColor = primaryColor,
                secondaryColor = secondaryColor,
                fallbackAccent = fallbackAccent,
            )
        }

        bindExtras(context, views, snapshot, nowMillis)

        views.setOnClickPendingIntent(
            R.id.widget_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindCourseHero(
        context: Context,
        views: RemoteViews,
        course: TodayWidgetCourseInfo,
        isTomorrow: Boolean,
        isOngoing: Boolean,
        nowMillis: Long,
        profile: TodayWidgetSizeProfile,
        primaryColor: Int,
        secondaryColor: Int,
        fallbackAccent: Int,
        showLocation: Boolean,
    ) {
        val accent = parseCourseColor(course.color, fallbackAccent)
        views.setTextColor(R.id.widget_strip_course, primaryColor)
        views.setTextViewText(R.id.widget_strip_course, courseName(course))

        views.setTextColor(R.id.widget_strip_location, secondaryColor)
        views.setTextViewText(
            R.id.widget_strip_location,
            course.location.takeIf { showLocation && it.isNotBlank() } ?: "",
        )
        views.setTextColor(R.id.widget_strip_time, secondaryColor)
        views.setTextViewText(
            R.id.widget_strip_time,
            if (course.startTime.isNotBlank() && course.endTime.isNotBlank()) {
                "${course.startTime} - ${course.endTime}"
            } else {
                ""
            },
        )

        // 今日课按今天取天气，明日课按明天取；无预报时图标与温度一起隐藏。
        val weather = CoupleWidgetWeatherSource.lookup(context)?.invoke(
            if (isTomorrow) nowMillis + DAY_MILLIS else nowMillis,
            course.startTime,
            course.endTime,
        )
        bindWeather(context, views, weather, secondaryColor)

        views.setInt(R.id.widget_strip_bar, "setColorFilter", accent)
        views.setViewVisibility(R.id.widget_strip_bar, View.VISIBLE)

        // 先清掉上一次「进行中」的淡底，避免 RemoteViews 复用时残留。
        views.setInt(R.id.widget_strip_row, "setBackgroundColor", Color.TRANSPARENT)
        if (isOngoing) {
            views.setInt(
                R.id.widget_strip_row,
                "setBackgroundResource",
                R.drawable.widget_couple_current_bg,
            )
            bindProgress(context, views, course, accent, nowMillis, profile)
        } else {
            views.setViewVisibility(R.id.widget_strip_progress, View.GONE)
        }
    }

    private fun bindExamHero(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo,
        primaryColor: Int,
        secondaryColor: Int,
        fallbackAccent: Int,
        showLocation: Boolean,
    ) {
        views.setTextColor(R.id.widget_strip_course, primaryColor)
        views.setTextViewText(
            R.id.widget_strip_course,
            truncateName(
                TodayWidgetSupport.examDisplayName(snapshot)
                    ?: context.getString(R.string.widget_exam_fallback_name),
            ),
        )

        views.setTextColor(R.id.widget_strip_location, secondaryColor)
        views.setTextViewText(
            R.id.widget_strip_location,
            snapshot.nextExamLocation.orEmpty()
                .takeIf { showLocation && it.isNotBlank() } ?: "",
        )
        val start = snapshot.nextExamStartTime.orEmpty()
        val end = snapshot.nextExamEndTime.orEmpty()
        views.setTextColor(R.id.widget_strip_time, secondaryColor)
        views.setTextViewText(
            R.id.widget_strip_time,
            when {
                start.isNotBlank() && end.isNotBlank() -> "$start - $end"
                end.isNotBlank() -> context.getString(R.string.widget_exam_until, end)
                else -> ""
            },
        )

        views.setViewVisibility(R.id.widget_strip_weather_icon, View.GONE)
        views.setViewVisibility(R.id.widget_strip_temp, View.GONE)
        views.setInt(R.id.widget_strip_bar, "setColorFilter", fallbackAccent)
        views.setViewVisibility(R.id.widget_strip_bar, View.VISIBLE)
        views.setInt(R.id.widget_strip_row, "setBackgroundColor", Color.TRANSPARENT)
        views.setViewVisibility(R.id.widget_strip_progress, View.GONE)
    }

    /**
     * 空态与 demo 一致：主行是状态文案（今日已结束 / 周末无课 / 今天没有课程），
     * 第二行固定「明日无课」。不再出现旧的「明日课程」状态。
     */
    private fun bindEmptyHero(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo?,
        state: String,
        nowMillis: Long,
        primaryColor: Int,
        secondaryColor: Int,
        fallbackAccent: Int,
    ) {
        val mainText = when {
            state == "completed" -> context.getString(R.string.widget_couple_today_ended)
            state == "no_course" -> context.getString(
                if (isWeekend(nowMillis)) {
                    R.string.widget_couple_weekend_no_course
                } else {
                    R.string.widget_couple_no_course_today
                },
            )
            state == "holiday" -> snapshot?.holidayName?.takeIf { it.isNotBlank() }
                ?: context.getString(R.string.widget_on_holiday)
            else -> context.getString(R.string.widget_couple_no_course_today)
        }
        views.setTextColor(R.id.widget_strip_course, primaryColor)
        views.setTextViewText(R.id.widget_strip_course, mainText)

        views.setTextColor(R.id.widget_strip_location, secondaryColor)
        views.setTextViewText(
            R.id.widget_strip_location,
            context.getString(R.string.widget_couple_no_course_tomorrow),
        )
        views.setTextColor(R.id.widget_strip_time, secondaryColor)
        views.setTextViewText(R.id.widget_strip_time, "")

        views.setViewVisibility(R.id.widget_strip_weather_icon, View.GONE)
        views.setViewVisibility(R.id.widget_strip_temp, View.GONE)
        // demo 空态色条回落品牌蓝；无课程色可取。
        views.setInt(R.id.widget_strip_bar, "setColorFilter", fallbackAccent)
        views.setViewVisibility(R.id.widget_strip_bar, View.VISIBLE)
        views.setInt(R.id.widget_strip_row, "setBackgroundColor", Color.TRANSPARENT)
        views.setViewVisibility(R.id.widget_strip_progress, View.GONE)
    }

    private fun bindWeather(
        context: Context,
        views: RemoteViews,
        weather: CoupleWidgetWeather?,
        secondaryColor: Int,
    ) {
        if (weather == null) {
            views.setViewVisibility(R.id.widget_strip_weather_icon, View.GONE)
            views.setViewVisibility(R.id.widget_strip_temp, View.GONE)
            return
        }
        views.setImageViewBitmap(
            R.id.widget_strip_weather_icon,
            CoupleTimetableRenderSupport.createWeatherBitmap(context, weather.kind),
        )
        views.setViewVisibility(R.id.widget_strip_weather_icon, View.VISIBLE)

        val temperature = weather.temperatureC
        if (temperature == null) {
            views.setViewVisibility(R.id.widget_strip_temp, View.GONE)
        } else {
            views.setTextColor(R.id.widget_strip_temp, secondaryColor)
            views.setTextViewText(R.id.widget_strip_temp, "$temperature°")
            views.setViewVisibility(R.id.widget_strip_temp, View.VISIBLE)
        }
    }

    private fun bindProgress(
        context: Context,
        views: RemoteViews,
        course: TodayWidgetCourseInfo,
        accentColor: Int,
        nowMillis: Long,
        profile: TodayWidgetSizeProfile,
    ) {
        // Today 快照没有课间数据：breaks 传空列表，进度条连续填充。
        val progressCourse = CoupleWidgetCourse(
            id = course.id,
            name = course.name,
            shortName = course.shortName,
            location = course.location,
            color = course.color,
            startSection = 1,
            endSection = 1,
            startTime = course.startTime,
            endTime = course.endTime,
            breaks = emptyList(),
        )
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val nowMinutes = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        val widthDp = (profile.widthDp - HERO_CHROME_WIDTH_DP)
            .coerceAtLeast(PROGRESS_MIN_WIDTH_DP)
        val widthPx = (widthDp * context.resources.displayMetrics.density).toInt()
        val progress = CoupleTimetableRenderSupport.createProgressBitmap(
            context = context,
            accentColor = accentColor,
            course = progressCourse,
            nowMinutes = nowMinutes,
            widthPx = widthPx,
        )
        if (progress != null) {
            views.setImageViewBitmap(R.id.widget_strip_progress, progress)
            views.setViewVisibility(R.id.widget_strip_progress, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_strip_progress, View.GONE)
        }
    }

    /** 课名优先短名；超过 7 个 Unicode 码点直接截断，不加省略号（对齐 demo）。 */
    private fun courseName(course: TodayWidgetCourseInfo): String {
        return truncateName(course.shortName?.takeIf { it.isNotBlank() } ?: course.name)
    }

    private fun truncateName(value: String): String {
        if (value.codePointCount(0, value.length) <= NAME_MAX_CODE_POINTS) {
            return value
        }
        return value.substring(0, value.offsetByCodePoints(0, NAME_MAX_CODE_POINTS))
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

    private fun isWeekend(nowMillis: Long): Boolean {
        val day = Calendar.getInstance().apply { timeInMillis = nowMillis }
            .get(Calendar.DAY_OF_WEEK)
        return day == Calendar.SATURDAY || day == Calendar.SUNDAY
    }
}
