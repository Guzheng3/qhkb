package vip.qinghan.withu

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.appwidget.AppWidgetManager
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import android.text.TextUtils
import android.text.TextPaint
import kotlin.math.floor
import kotlin.math.roundToInt
import java.util.Calendar

internal sealed class CoupleWidgetDisplayItem {
    data class Course(
        val course: CoupleWidgetCourse,
        val isOngoing: Boolean,
    ) : CoupleWidgetDisplayItem()

    data class Notice(val text: String) : CoupleWidgetDisplayItem()
    data object NoticeDivider : CoupleWidgetDisplayItem()
    data object Divider : CoupleWidgetDisplayItem()
}

internal data class CoupleWidgetDisplay(
    val items: List<CoupleWidgetDisplayItem>,
    val footerText: String,
    val emptyText: String? = null,
    /**
     * 空态文案是「今日课程已结束」（今天有课、已上完，且明日没有课可列）。
     * 这一档文案要在整列垂直居中，与明日有课时上方那条 Notice 观感一致。
     */
    val emptyEndedNotice: Boolean = false,
)

internal object CoupleTimetableDisplayBuilder {
    private const val MAX_VISIBLE_COURSES = 5
    private const val MAX_VISIBLE_COURSES_WITH_NOTICE = 5

    /**
     * 提示文案（「今日课程已结束」Notice 与整列空态文案）的字号。同一条
     * 文案在卡片上有两种落法，字号只留这一处，避免两处各改一半后不一样大。
     */
    const val HINT_TEXT_SIZE_SP = 16f

    /**
     * 整卡不可用时的原因文案（未开情侣模式 / 未登录 / 对方课表未上传）。
     * 这类状态下卡片不分左右两栏，由整卡居中的提示位统一显示这一句。
     */
    fun unavailableText(context: Context, status: CoupleWidgetStatus): String =
        when (status) {
            CoupleWidgetStatus.COUPLE_MODE_OFF ->
                context.getString(R.string.widget_couple_mode_off)
            CoupleWidgetStatus.NOT_LOGGED_IN ->
                context.getString(R.string.widget_couple_not_logged_in)
            CoupleWidgetStatus.NOT_BOUND ->
                context.getString(R.string.widget_couple_not_bound)
            CoupleWidgetStatus.OK -> ""
        }

    /**
     * 空态文案是否为「今日课程已结束」：今天本来有课（不是「今日无课」），
     * 课已全部上完，且明日没有课可列——此时没人再占位，文案可以直接坐到
     * 整列中间。
     */
    fun isEmptyEndedNotice(
        hasRemainingCourse: Boolean,
        todayCourseCount: Int,
        tomorrowCourseCount: Int,
    ): Boolean = !hasRemainingCourse && todayCourseCount > 0 && tomorrowCourseCount == 0

    fun build(
        context: Context,
        courses: CoupleWidgetDayCourses,
        nowMillis: Long = System.currentTimeMillis(),
        status: CoupleWidgetStatus = CoupleWidgetStatus.OK,
        maxVisibleCourses: Int = MAX_VISIBLE_COURSES,
    ): CoupleWidgetDisplay {
        if (status != CoupleWidgetStatus.OK) {
            return CoupleWidgetDisplay(
                items = emptyList(),
                footerText = "",
                emptyText = unavailableText(context, status),
            )
        }

        val now = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val today = courses.today.sortedWith(
            compareBy({ it.startTime }, { it.startSection }, { it.id })
        )
        val tomorrow = courses.tomorrow.sortedWith(
            compareBy({ it.startTime }, { it.startSection }, { it.id })
        )
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val remainingToday = today.filter {
            parseClockMinutes(it.endTime)?.let { it > nowMinutes } == true
        }
        val hasRemainingCourse = remainingToday.isNotEmpty()
        val remainingCount = today.count {
            parseClockMinutes(it.endTime)?.let { it > nowMinutes } == true
        }
        val statusText = when {
            today.isNotEmpty() -> context.getString(R.string.widget_couple_today_ended)
            now.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY ||
                now.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY ->
                context.getString(R.string.widget_couple_weekend_no_course)
            else -> context.getString(R.string.widget_couple_no_course_today)
        }

        val shownCourses = if (hasRemainingCourse) remainingToday else tomorrow
        val items = if (!hasRemainingCourse && tomorrow.isEmpty()) {
            emptyList()
        } else {
            buildList {
                if (!hasRemainingCourse) {
                    add(CoupleWidgetDisplayItem.Notice(statusText))
                    add(CoupleWidgetDisplayItem.NoticeDivider)
                }
                shownCourses.take(
                    maxVisibleCourses.coerceIn(0, MAX_VISIBLE_COURSES)
                ).forEachIndexed { index, course ->
                    if (index > 0) add(CoupleWidgetDisplayItem.Divider)
                    val start = parseClockMinutes(course.startTime)
                    val end = parseClockMinutes(course.endTime)
                    add(
                        CoupleWidgetDisplayItem.Course(
                            course = course,
                            isOngoing = start != null && end != null &&
                                nowMinutes >= start && nowMinutes < end,
                        )
                    )
                }
            }
        }
        val footerText = when {
            hasRemainingCourse -> context.getString(
                R.string.widget_couple_today_remaining,
                remainingCount,
                today.size,
            )
            tomorrow.isNotEmpty() ->
                context.getString(R.string.widget_couple_tomorrow_count, tomorrow.size)
            else -> context.getString(R.string.widget_couple_no_course_tomorrow)
        }
        return CoupleWidgetDisplay(
            items = items,
            footerText = footerText,
            emptyText = if (items.isEmpty()) statusText else null,
            emptyEndedNotice = isEmptyEndedNotice(
                hasRemainingCourse = hasRemainingCourse,
                todayCourseCount = today.size,
                tomorrowCourseCount = tomorrow.size,
            ),
        )
    }

    fun parseClockMinutes(value: String): Int? {
        val parts = value.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
    }
}

internal data class CoupleTimetableSizing(
    val availableListHeightPx: Float,
    val visibleCourseCount: Int,
    val courseRowHeightPx: Float,
    val noticeRowHeightPx: Float = 0f,
)

internal object CoupleTimetableSizingSupport {
    private const val CARD_VERTICAL_PADDING_DP = 14f
    private const val HEADER_HEIGHT_DP = 20f
    private const val HEADER_TOP_MARGIN_DP = 5f
    private const val FOOTER_HEIGHT_DP = 13f

    /** 一行课的高度：空态文案贴列首时按这个高度站位。 */
    const val COURSE_ROW_HEIGHT_DP = 52f
    private const val DIVIDER_TOTAL_DP = 5f
    private const val PARTIAL_MIN_DP = 12f

    /**
     * 列表区能显示多少行：整行放不下时，只要下一行还能露出 [PARTIAL_MIN_DP]
     * 就纳入渲染，剩余部分由列容器裁切（与设计预览一致）。
     */
    internal fun visibleCourseCount(
        maxCount: Int,
        availableHeightPx: Float,
        hasNotice: Boolean,
        density: Float,
    ): Int {
        if (maxCount <= 0 || availableHeightPx <= 0f) return 0
        val rowHeightPx = COURSE_ROW_HEIGHT_DP * density
        val rowStepPx = (COURSE_ROW_HEIGHT_DP + DIVIDER_TOTAL_DP) * density
        val partialMinPx = PARTIAL_MIN_DP * density
        val count = if (hasNotice) {
            floor((availableHeightPx / 2f + rowHeightPx - partialMinPx) / rowStepPx).toInt()
        } else {
            floor((availableHeightPx - partialMinPx) / rowStepPx).toInt() + 1
        }
        return count.coerceIn(0, maxCount)
    }

    fun calculate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        display: CoupleWidgetDisplay,
    ): CoupleTimetableSizing {
        val density = context.resources.displayMetrics.density
        val availableHeightPx = availableListHeightPx(context, appWidgetManager, appWidgetId)
        val maxCourseCount = display.items.count { it is CoupleWidgetDisplayItem.Course }
        val hasNotice = display.items.any { it is CoupleWidgetDisplayItem.Notice }
        val courseCount = visibleCourseCount(
            maxCount = maxCourseCount,
            availableHeightPx = availableHeightPx,
            hasNotice = hasNotice,
            density = density,
        )
        val dividerCount = if (hasNotice) {
            courseCount
        } else {
            (courseCount - 1).coerceAtLeast(0)
        }
        val dividerHeightPx = dividerCount * DIVIDER_TOTAL_DP * density
        val rowHeightPx = if (courseCount == 0) {
            0f
        } else {
            val courseAreaHeightPx = if (hasNotice) {
                availableHeightPx / 2f
            } else {
                availableHeightPx
            }
            COURSE_ROW_HEIGHT_DP * density
        }
        val noticeHeightPx = if (hasNotice) availableHeightPx / 2f else 0f
        return CoupleTimetableSizing(
            availableListHeightPx = availableHeightPx,
            visibleCourseCount = courseCount,
            courseRowHeightPx = rowHeightPx,
            noticeRowHeightPx = noticeHeightPx,
        )
    }

    fun calculateSynced(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        display: CoupleWidgetDisplay,
        oppositeDisplay: CoupleWidgetDisplay,
    ): CoupleTimetableSizing {
        val current = calculate(context, appWidgetManager, appWidgetId, display)
        val opposite = calculate(context, appWidgetManager, appWidgetId, oppositeDisplay)
        val density = context.resources.displayMetrics.density
        val sharedRowHeightPx = COURSE_ROW_HEIGHT_DP * density

        val availableHeightPx = availableListHeightPx(context, appWidgetManager, appWidgetId)
        val maxCourseCount = display.items.count { it is CoupleWidgetDisplayItem.Course }
        val hasNotice = display.items.any { it is CoupleWidgetDisplayItem.Notice }
        val courseCount = visibleCourseCount(
            maxCount = maxCourseCount,
            availableHeightPx = availableHeightPx,
            hasNotice = hasNotice,
            density = density,
        )
        return current.copy(
            visibleCourseCount = courseCount,
            courseRowHeightPx = sharedRowHeightPx,
        )
    }

    fun applyRowHeight(views: RemoteViews, viewId: Int, heightPx: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && heightPx > 0f) {
            views.setViewLayoutHeight(viewId, heightPx, TypedValue.COMPLEX_UNIT_PX)
        }
    }

    /**
     * 空态文案占的高度：所有空态都铺满整列，让文案落在列的垂直中点
     * （与设计预览一致；列里没有别的内容，空出来的位置由居中的文案自己吃掉）。
     */
    fun emptyRowHeightPx(
        availableListHeightPx: Float,
        @Suppress("UNUSED_PARAMETER") courseRowHeightPx: Float,
        @Suppress("UNUSED_PARAMETER") endedNotice: Boolean,
    ): Float = availableListHeightPx

    /** 列表区可用高度（整列去掉卡片内边距、昵称行与页脚后的部分）。 */
    fun availableListHeightPx(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): Float {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val isPortrait = context.resources.configuration.orientation ==
            android.content.res.Configuration.ORIENTATION_PORTRAIT
        val optionHeightDp = if (isPortrait) {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        } else {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        }
        val heightDp = optionHeightDp.takeIf { it > 0 }
            ?: appWidgetManager.getAppWidgetInfo(appWidgetId)?.minHeight?.takeIf { it > 0 }
            ?: 180
        val reservedHeightDp = CARD_VERTICAL_PADDING_DP +
            HEADER_HEIGHT_DP +
            HEADER_TOP_MARGIN_DP +
            FOOTER_HEIGHT_DP
        val listHeightDp = (heightDp - reservedHeightDp).coerceAtLeast(0f)
        return listHeightDp * context.resources.displayMetrics.density
    }

    /** 课程行内容区宽度：进度条位图按这个宽度创建，避免 220dp 位图被 fitXY 缩放后课间空档变细。 */
    fun availableCourseContentWidthPx(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): Float {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val isPortrait = context.resources.configuration.orientation ==
            android.content.res.Configuration.ORIENTATION_PORTRAIT
        val optionWidthDp = if (isPortrait) {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        } else {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        }
        val widthDp = optionWidthDp.takeIf { it > 0 }
            ?: appWidgetManager.getAppWidgetInfo(appWidgetId)?.minWidth?.takeIf { it > 0 }
            ?: 250
        val contentWidthDp = ((widthDp - 20f - 8f) / 2f - 8f - 4f - 6f).coerceAtLeast(1f)
        return contentWidthDp * context.resources.displayMetrics.density
    }
}

internal object CoupleTimetableRenderSupport {
    fun createNameBitmap(context: Context, text: String, color: Int): Bitmap? {
        val value = text.trim()
        if (value.isEmpty()) return null
        val density = context.resources.displayMetrics.density
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = sp(context, 13f)
            typeface = ResourcesCompat.getFont(context, R.font.pacifico)
            setShadowLayer(
                density,
                density * 0.5f,
                density * 0.5f,
                ContextCompat.getColor(context, R.color.widget_couple_shadow)
            )
        }
        val maxWidth = density * 104f
        val label = TextUtils.ellipsize(value, paint, maxWidth, TextUtils.TruncateAt.END)
        val metrics = paint.fontMetrics
        val textHeight = metrics.descent - metrics.ascent
        val height = (density * 20f).toInt().coerceAtLeast(textHeight.toInt() + 1)
        val width = (paint.measureText(label, 0, label.length) + density * 3f)
            .toInt()
            .coerceAtMost(maxWidth.toInt())
            .coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val baseline = (height - textHeight) / 2f - metrics.ascent
        canvas.drawText(label, 0, label.length, density * 1.5f, baseline, paint)
        return bitmap
    }

    fun createProgressBitmap(
        context: Context,
        accentColor: Int,
        course: CoupleWidgetCourse,
        nowMinutes: Int,
        widthPx: Int,
    ): Bitmap? {
        val start = CoupleTimetableDisplayBuilder.parseClockMinutes(course.startTime) ?: return null
        val end = CoupleTimetableDisplayBuilder.parseClockMinutes(course.endTime) ?: return null
        if (end <= start || nowMinutes !in start until end) return null

        val density = context.resources.displayMetrics.density
        val width = widthPx.coerceAtLeast(1)
        val height = (density * 3f).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = height / 2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ContextCompat.getColor(context, R.color.widget_couple_track)
        }
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)

        // 课间把进度条断开：逐段填充，空档用白色贯穿已走到和没走到的部分。
        val boundaries = mutableListOf(start)
        for (breakTime in course.breaks) {
            val boundary = CoupleTimetableDisplayBuilder.parseClockMinutes(breakTime.startTime)
                ?: continue
            if (boundary > start && boundary < end) boundaries.add(boundary)
        }
        boundaries.add(end)
        boundaries.sort()
        for (index in 0 until boundaries.size - 1) {
            val segmentStart = boundaries[index]
            val segmentEnd = boundaries[index + 1]
            if (nowMinutes <= segmentStart) continue
            val fillEnd = minOf(nowMinutes, segmentEnd)
            val left = width * ((segmentStart - start).toFloat() / (end - start).toFloat())
            val right = width * ((fillEnd - start).toFloat() / (end - start).toFloat())
            if (right > left) {
                paint.color = accentColor
                canvas.drawRoundRect(RectF(left, 0f, right, height.toFloat()), radius, radius, paint)
            }
        }

        val gapWidth = density * 2.5f
        paint.color = ContextCompat.getColor(context, R.color.widget_couple_progress_gap)
        for (breakTime in course.breaks) {
            val boundary = CoupleTimetableDisplayBuilder.parseClockMinutes(breakTime.startTime)
                ?: continue
            if (boundary <= start || boundary >= end) continue
            val x = width * ((boundary - start).toFloat() / (end - start).toFloat())
            canvas.drawRect(x - gapWidth / 2f, 0f, x + gapWidth / 2f, height.toFloat(), paint)
        }
        return bitmap
    }

    fun createWeatherBitmap(context: Context, kind: String): Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (density * 13f).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(size / 24f, size / 24f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val sun = ContextCompat.getColor(context, R.color.widget_weather_sun)
        val ray = ContextCompat.getColor(context, R.color.widget_weather_ray)
        val cloud = ContextCompat.getColor(context, R.color.widget_weather_cloud)
        val rain = ContextCompat.getColor(context, R.color.widget_weather_rain)
        val snow = ContextCompat.getColor(context, R.color.widget_weather_snow)
        val bolt = ContextCompat.getColor(context, R.color.widget_weather_bolt)

        fun drawSun(cx: Float, cy: Float, radius: Float) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2f
            paint.strokeCap = Paint.Cap.ROUND
            paint.color = ray
            if (cx == 12f) {
                canvas.drawLine(12f, 2.2f, 12f, 4.6f, paint)
                canvas.drawLine(12f, 19.4f, 12f, 21.8f, paint)
                canvas.drawLine(2.2f, 12f, 4.6f, 12f, paint)
                canvas.drawLine(19.4f, 12f, 21.8f, 12f, paint)
                canvas.drawLine(5.1f, 5.1f, 6.8f, 6.8f, paint)
                canvas.drawLine(17.2f, 17.2f, 18.9f, 18.9f, paint)
                canvas.drawLine(18.9f, 5.1f, 17.2f, 6.8f, paint)
                canvas.drawLine(6.8f, 17.2f, 5.1f, 18.9f, paint)
            } else {
                canvas.drawLine(cx, 2.5f, cx, 4.3f, paint)
                canvas.drawLine(cx - 6.5f, cy, cx - 4.7f, cy, paint)
                canvas.drawLine(cx - 4.5f, cy - 4.5f, cx - 3.2f, cy - 3.2f, paint)
                canvas.drawLine(cx + 4.5f, cy - 4.5f, cx + 3.2f, cy - 3.2f, paint)
            }
            paint.style = Paint.Style.FILL
            paint.color = sun
            canvas.drawCircle(cx, cy, radius, paint)
        }

        fun drawCloud() {
            paint.style = Paint.Style.FILL
            paint.color = cloud
            canvas.drawCircle(9f, 9.8f, 3.2f, paint)
            canvas.drawCircle(13.3f, 8.8f, 4f, paint)
            canvas.drawRoundRect(RectF(6.6f, 9.4f, 18.4f, 14f), 2.3f, 2.3f, paint)
        }

        when (kind) {
            "clear" -> drawSun(12f, 12f, 4.4f)
            "partlyCloudy" -> {
                drawSun(9f, 9f, 3.4f)
                paint.style = Paint.Style.FILL
                paint.color = cloud
                canvas.drawCircle(10.5f, 14.6f, 3.1f, paint)
                canvas.drawCircle(14.4f, 13.5f, 3.8f, paint)
                canvas.drawRoundRect(RectF(8.4f, 14.2f, 18.6f, 18.4f), 2.1f, 2.1f, paint)
            }
            "rain" -> {
                drawCloud()
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 1.9f
                paint.strokeCap = Paint.Cap.ROUND
                paint.color = rain
                canvas.drawLine(8.6f, 16.8f, 7.6f, 19.3f, paint)
                canvas.drawLine(13f, 16.8f, 12f, 19.3f, paint)
                canvas.drawLine(17.4f, 16.8f, 16.4f, 19.3f, paint)
            }
            "snow" -> {
                drawCloud()
                paint.style = Paint.Style.FILL
                paint.color = snow
                for (x in floatArrayOf(8.6f, 13f, 17.4f)) {
                    canvas.drawCircle(x, 18f, 1.3f, paint)
                }
            }
            "storm" -> {
                drawCloud()
                paint.style = Paint.Style.FILL
                paint.color = bolt
                val path = Path().apply {
                    moveTo(13.6f, 14.2f)
                    lineTo(9.8f, 19.4f)
                    lineTo(12.2f, 19.4f)
                    lineTo(10.8f, 23f)
                    lineTo(15.6f, 17.4f)
                    lineTo(13.1f, 17.4f)
                    close()
                }
                canvas.drawPath(path, paint)
            }
            else -> drawCloud()
        }
        return bitmap
    }

    private fun sp(context: Context, value: Float): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            value,
            context.resources.displayMetrics
        )
    }
}

class CoupleTimetableViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CoupleTimetableViewsFactory(applicationContext, intent)
    }

    private class CoupleTimetableViewsFactory(
        private val context: Context,
        intent: Intent,
    ) : RemoteViewsFactory {
        private val appWidgetId = intent.getIntExtra(
            CoupleTimetableWidgetProvider.EXTRA_APP_WIDGET_ID,
            -1
        )
        private val isLeft = intent.getBooleanExtra(
            CoupleTimetableWidgetProvider.EXTRA_IS_LEFT,
            true
        )
        private val accentColor = intent.getIntExtra(
            CoupleTimetableWidgetProvider.EXTRA_ACCENT_COLOR,
            if (isLeft) {
                CoupleTimetableWidgetProvider.maleAccentColor(context)
            } else {
                CoupleTimetableWidgetProvider.femaleAccentColor(context)
            }
        )
        private var items: List<CoupleWidgetDisplayItem> = emptyList()
        private var courseRowHeightPx = 0f
        private var noticeRowHeightPx = 0f
        private var progressWidthPx = 0f
        private val weatherBitmaps = mutableMapOf<String, Bitmap>()

        override fun onCreate() {
            onDataSetChanged()
        }

        override fun onDataSetChanged() {
            val snapshot = CoupleTimetableStore.readSnapshot(context)
            val status = snapshot?.status ?: CoupleWidgetStatus.COUPLE_MODE_OFF
            val courses = if (isLeft) snapshot?.mine else snapshot?.partner
            if (status != CoupleWidgetStatus.OK || courses == null) {
                items = emptyList()
                courseRowHeightPx = 0f
                noticeRowHeightPx = 0f
                progressWidthPx = 0f
            } else {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val oppositeCourses = if (isLeft) snapshot?.partner else snapshot?.mine
                val unconstrainedDisplay = CoupleTimetableDisplayBuilder.build(
                    context,
                    courses,
                    status = status,
                )
                val oppositeUnconstrainedDisplay = CoupleTimetableDisplayBuilder.build(
                    context,
                    oppositeCourses ?: CoupleWidgetDayCourses(emptyList(), emptyList()),
                    status = status,
                )
                val sizing = CoupleTimetableSizingSupport.calculateSynced(
                    context,
                    appWidgetManager,
                    appWidgetId,
                    unconstrainedDisplay,
                    oppositeUnconstrainedDisplay,
                )
                progressWidthPx = CoupleTimetableSizingSupport.availableCourseContentWidthPx(
                    context,
                    appWidgetManager,
                    appWidgetId,
                )
                val display = CoupleTimetableDisplayBuilder.build(
                    context,
                    courses,
                    status = status,
                    maxVisibleCourses = sizing.visibleCourseCount,
                )
                items = display.items
                courseRowHeightPx = sizing.courseRowHeightPx
                noticeRowHeightPx = sizing.noticeRowHeightPx
            }
        }

        override fun onDestroy() {
            items = emptyList()
            weatherBitmaps.clear()
        }

        override fun getCount(): Int = items.size

        override fun getViewAt(position: Int): RemoteViews {
            return when (val item = items.getOrNull(position)) {
                is CoupleWidgetDisplayItem.Course -> renderCourse(item).apply {
                    attachSideTap(R.id.widget_couple_course_root, item.course.id)
                }
                is CoupleWidgetDisplayItem.Notice ->
                    renderNotice(item.text).apply {
                        attachSideTap(R.id.widget_couple_today_ended)
                    }
                CoupleWidgetDisplayItem.NoticeDivider ->
                    RemoteViews(
                        context.packageName,
                        R.layout.widget_couple_notice_divider
                    ).apply {
                        attachSideTap(R.id.widget_couple_notice_divider)
                    }
                CoupleWidgetDisplayItem.Divider ->
                    RemoteViews(
                        context.packageName,
                        R.layout.widget_couple_course_divider
                    ).apply {
                        attachSideTap(R.id.widget_couple_course_divider)
                    }
                null -> RemoteViews(
                    context.packageName,
                    R.layout.widget_couple_today_ended_item
                ).apply {
                    attachSideTap(R.id.widget_couple_today_ended)
                }
            }
        }

        // 行点击随 PendingIntentTemplate 派发到对应一侧；不挂 fill intent
        // 的行不会触发模板，导致课程行区域成为点击死区。课程行额外带上
        // course id，Flutter 侧据此决定是否展开该课程的详情弹窗。
        private fun RemoteViews.attachSideTap(rootId: Int, courseId: String? = null) {
            val fillIn = Intent().putExtra(
                TodayWidgetSupport.EXTRA_WIDGET_LAUNCH_SIDE,
                if (isLeft) "left" else "right"
            )
            if (!courseId.isNullOrBlank()) {
                fillIn.putExtra(TodayWidgetSupport.EXTRA_WIDGET_LAUNCH_COURSE_ID, courseId)
            }
            setOnClickFillInIntent(rootId, fillIn)
        }

        private fun renderCourse(item: CoupleWidgetDisplayItem.Course): RemoteViews {
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_couple_course_item
            )
            CoupleTimetableSizingSupport.applyRowHeight(
                views,
                R.id.widget_couple_course_root,
                courseRowHeightPx,
            )
            val course = item.course
            views.setTextViewText(
                R.id.widget_couple_course_name,
                displayCourseName(course),
            )
            val weatherKind = course.weatherKind
            if (weatherKind != null) {
                views.setImageViewBitmap(
                    R.id.widget_couple_course_weather_icon,
                    weatherBitmap(weatherKind),
                )
                views.setViewVisibility(
                    R.id.widget_couple_course_weather_icon,
                    View.VISIBLE,
                )
            } else {
                views.setViewVisibility(R.id.widget_couple_course_weather_icon, View.GONE)
            }
            val weatherTemp = course.weatherTempC
            if (weatherTemp != null) {
                views.setTextViewText(
                    R.id.widget_couple_course_weather_text,
                    "$weatherTemp°",
                )
                views.setViewVisibility(
                    R.id.widget_couple_course_weather_text,
                    View.VISIBLE,
                )
            } else {
                views.setViewVisibility(R.id.widget_couple_course_weather_text, View.GONE)
            }
            views.setTextViewText(
                R.id.widget_couple_course_location,
                course.location.takeIf { it.isNotBlank() } ?: " "
            )
            views.setTextViewText(
                R.id.widget_couple_course_time,
                "${course.startTime} - ${course.endTime}"
            )
            views.setInt(
                R.id.widget_couple_course_indicator,
                "setColorFilter",
                parseCourseColor(course.color, accentColor)
            )
            // 复用 RemoteViews 时，上一行「进行中」的淡底会残留：每次都先清掉。
            views.setInt(R.id.widget_couple_course_root, "setBackgroundColor", Color.TRANSPARENT)
            if (item.isOngoing) {
                views.setInt(
                    R.id.widget_couple_course_root,
                    "setBackgroundResource",
                    R.drawable.widget_couple_current_bg
                )
                val now = Calendar.getInstance()
                val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
                val fallbackWidth = (context.resources.displayMetrics.density * 220f).toInt()
                val progress = CoupleTimetableRenderSupport.createProgressBitmap(
                    context,
                    accentColor,
                    course,
                    nowMinutes,
                    progressWidthPx.toInt().takeIf { it > 0 } ?: fallbackWidth,
                )
                if (progress != null) {
                    views.setImageViewBitmap(R.id.widget_couple_course_progress, progress)
                    views.setViewVisibility(R.id.widget_couple_course_progress, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_couple_course_progress, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_couple_course_progress, View.GONE)
            }
            return views
        }

        private fun weatherBitmap(kind: String): Bitmap {
            weatherBitmaps[kind]?.let { return it }
            val created = CoupleTimetableRenderSupport.createWeatherBitmap(context, kind)
            weatherBitmaps[kind] = created
            return created
        }

        private fun displayCourseName(course: CoupleWidgetCourse): String {
            val text = course.shortName?.takeIf { it.isNotBlank() } ?: course.name
            return if (text.codePointCount(0, text.length) <= 7) {
                text
            } else {
                text.substring(0, text.offsetByCodePoints(0, 7))
            }
        }

        private fun parseCourseColor(value: String?, fallback: Int): Int {
            if (value.isNullOrBlank()) return fallback
            return try {
                Color.parseColor(value)
            } catch (_: IllegalArgumentException) {
                fallback
            }
        }

        private fun renderNotice(text: String): RemoteViews {
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_couple_today_ended_item
            )
            views.setTextViewText(R.id.widget_couple_today_ended, text)
            views.setTextViewTextSize(
                R.id.widget_couple_today_ended,
                TypedValue.COMPLEX_UNIT_SP,
                CoupleTimetableDisplayBuilder.HINT_TEXT_SIZE_SP,
            )
            CoupleTimetableSizingSupport.applyRowHeight(
                views,
                R.id.widget_couple_today_ended,
                noticeRowHeightPx,
            )
            return views
        }

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount(): Int = 4

        override fun getItemId(position: Int): Long {
            return when (val item = items.getOrNull(position)) {
                is CoupleWidgetDisplayItem.Course ->
                    (item.course.id.hashCode().toLong() * 31L) + item.course.startSection
                is CoupleWidgetDisplayItem.Notice -> item.text.hashCode().toLong()
                CoupleWidgetDisplayItem.NoticeDivider -> "notice-divider".hashCode().toLong()
                CoupleWidgetDisplayItem.Divider -> "divider".hashCode().toLong()
                null -> 0L
            }
        }

        override fun hasStableIds(): Boolean = true
    }
}
