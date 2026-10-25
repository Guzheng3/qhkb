package vip.qinghan.withu

import android.content.Context
import android.graphics.Color
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * 考试卡「其他考试」条目。整张卡的主考试仍来自今日快照，
 * 这里只负责从活动档案 JSON 里取出紧随其后的考试，避免把设计稿里的 demo 常量写死。
 */
internal data class ExamWidgetEntry(
    val name: String,
    val dateOnly: String,
    val startTime: String?,
    val location: String?,
    val daysUntil: Int,
    val color: Int,
)

internal object ExamWidgetList {
    private const val DAY_MILLIS = 86_400_000L

    /**
     * 读取活动档案里尚未结束的考试，按日期/开始时间升序，
     * 跳过 [heroDate]/[heroStartTime] 指向的主考试后返回前 [limit] 条。
     */
    fun readOtherExams(
        context: Context,
        heroDate: String?,
        heroStartTime: String?,
        limit: Int = 2,
        nowMillis: Long = System.currentTimeMillis(),
    ): List<ExamWidgetEntry> {
        val upcoming = readUpcomingExams(context, nowMillis)
        if (upcoming.isEmpty()) {
            return emptyList()
        }
        var heroIndex = -1
        if (!heroDate.isNullOrBlank()) {
            heroIndex = upcoming.indexOfFirst { entry ->
                entry.dateOnly == heroDate &&
                    (heroStartTime.isNullOrBlank() || entry.startTime == heroStartTime)
            }
            if (heroIndex < 0) {
                // 开始时间对不上（历史数据缺字段）时退化为按日期定位主考试。
                heroIndex = upcoming.indexOfFirst { it.dateOnly == heroDate }
            }
        }
        val others = if (heroIndex >= 0) {
            upcoming.filterIndexed { index, _ -> index != heroIndex }
        } else {
            upcoming
        }
        return others.take(limit)
    }

    /** "2026-06-25" → "06-25 周四"（英文环境为 "06-25 Thu"）。 */
    fun examDateLabel(context: Context, rawDate: String?): String {
        val date = rawDate.orEmpty().take(10)
        if (date.length < 10) {
            return date
        }
        val monthDay = date.substring(5)
        val midnights = midnightMillis(date) ?: return monthDay
        val calendar = Calendar.getInstance().apply { timeInMillis = midnights }
        val dayNames = arrayOf(
            context.getString(R.string.widget_day_sun),
            context.getString(R.string.widget_day_mon),
            context.getString(R.string.widget_day_tue),
            context.getString(R.string.widget_day_wed),
            context.getString(R.string.widget_day_thu),
            context.getString(R.string.widget_day_fri),
            context.getString(R.string.widget_day_sat),
        )
        val dayName = dayNames[calendar.get(Calendar.DAY_OF_WEEK) - 1]
        return "$monthDay ${weekdayPrefix(context)}$dayName"
    }

    private fun readUpcomingExams(context: Context, nowMillis: Long): List<ExamWidgetEntry> {
        val raw = TodayWidgetSupport.readOwnProfileRawJson(context) ?: return emptyList()
        val profile = runCatching { JSONObject(raw) }.getOrNull() ?: return emptyList()
        val examArray = profile.optJSONArray("exams") ?: return emptyList()
        val courseColors = readCourseColors(profile)
        val fallbackColor = context.getColor(R.color.widget_loading_indicator)
        val todayStart = startOfDay(nowMillis)
        val todayDate = dateOnlyOf(nowMillis)
        val entries = mutableListOf<ExamWidgetEntry>()
        for (index in 0 until examArray.length()) {
            val exam = examArray.optJSONObject(index) ?: continue
            val dateOnly = exam.optString("dateTime").take(10)
            if (dateOnly.length < 10 || dateOnly < todayDate) {
                continue
            }
            val startTime = sanitize(exam.optString("startTime"))
            val endTime = sanitize(exam.optString("endTime"))
            // 与今日快照一致：当天的考试过了结束时间就不再占用列表位。
            if (dateOnly == todayDate && endTime != null) {
                val endMillis = timeOnDayMillis(nowMillis, endTime)
                if (endMillis != null && nowMillis >= endMillis) {
                    continue
                }
            }
            val examMidnight = midnightMillis(dateOnly) ?: continue
            val daysUntil = ((examMidnight - todayStart) / DAY_MILLIS)
                .toInt()
                .coerceAtLeast(0)
            val courseId = exam.optString("courseId")
            val color = parseColor(exam.optString("color"))
                ?: parseColor(courseColors[courseId])
                ?: fallbackColor
            entries += ExamWidgetEntry(
                name = sanitize(exam.optString("name"))
                    ?: context.getString(R.string.widget_exam_fallback_name),
                dateOnly = dateOnly,
                startTime = startTime,
                location = sanitize(exam.optString("location")),
                daysUntil = daysUntil,
                color = color,
            )
        }
        return entries.sortedWith(compareBy({ it.dateOnly }, { it.startTime.orEmpty() }))
    }

    /** 考试关联课程的颜色（课程 id → hex）；没有就返回空表走兜底色。 */
    private fun readCourseColors(profile: JSONObject): Map<String, String> {
        val courses = profile.optJSONArray("courses") ?: return emptyMap()
        val colors = mutableMapOf<String, String>()
        for (index in 0 until courses.length()) {
            val course = courses.optJSONObject(index) ?: continue
            val id = course.optString("id")
            val color = sanitize(course.optString("color")) ?: continue
            if (id.isNotBlank()) {
                colors[id] = color
            }
        }
        return colors
    }

    private fun weekdayPrefix(context: Context): String {
        val locale = context.resources.configuration.locales[0]
        if (locale.language != "zh") {
            return ""
        }
        return if (locale.country == "TW" || locale.country == "HK" || locale.country == "MO") {
            "週"
        } else {
            "周"
        }
    }

    private fun startOfDay(nowMillis: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun midnightMillis(dateOnly: String): Long? {
        val parts = dateOnly.split("-")
        if (parts.size != 3) {
            return null
        }
        val year = parts[0].toIntOrNull() ?: return null
        val month = parts[1].toIntOrNull() ?: return null
        val day = parts[2].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, 0, 0, 0)
        }.timeInMillis
    }

    private fun dateOnlyOf(nowMillis: Long): String {
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        return String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }

    private fun timeOnDayMillis(nowMillis: Long, time: String): Long? {
        val parts = time.split(":")
        if (parts.size < 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun parseColor(raw: String?): Int? {
        val value = sanitize(raw) ?: return null
        return runCatching { Color.parseColor(value) }.getOrNull()
    }

    private fun sanitize(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        return value.takeIf {
            it.isNotEmpty() && !it.equals("null", ignoreCase = true)
        }
    }
}
