package vip.qinghan.withu

import android.content.Context
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.roundToInt

/**
 * 情侣卡片课程行天气：直接读 Flutter 落盘的本地预报缓存
 * `FlutterSharedPreferences.flutter.weather_forecast_v1`，按课程所在日期与
 * 起止时间求平均温度，并取窗口内最严重的一档天气字形。
 *
 * 放在原生侧而不是扩展 Flutter 快照，原因：
 * - 卡片每分钟重绘时不需要 Flutter 进程存活；
 * - 原生跨天重算课程列表后，天气仍能按新日期重新取；
 * - 不依赖情侣登录态，离线也能显示。
 *
 * 预报只在 App 运行时刷新；超过 [MAX_AGE_MS] 视为过期并隐藏天气，宁可没有，
 * 也不显示两天前的温度。
 */
internal object CoupleWidgetWeatherSource {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_ENABLED = "flutter.weather_enabled_v1"
    private const val KEY_FORECAST = "flutter.weather_forecast_v1"
    private const val MAX_AGE_MS = 48L * 60L * 60L * 1000L

    fun lookup(
        context: Context,
        nowMillis: Long = System.currentTimeMillis(),
    ): ((Long, String, String) -> CoupleWidgetWeather?)? {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            return null
        }
        val raw = prefs.getString(KEY_FORECAST, null) ?: return null
        return forecastLookup(raw, nowMillis)
    }

    internal fun forecastLookup(
        raw: String,
        nowMillis: Long,
    ): ((Long, String, String) -> CoupleWidgetWeather?)? {
        val forecast = try {
            JSONObject(raw)
        } catch (_: Exception) {
            return null
        }
        val fetchedAt = forecast.optLong("fetchedAt", 0L)
        if (fetchedAt <= 0L || nowMillis - fetchedAt > MAX_AGE_MS) {
            return null
        }
        val times = forecast.optJSONArray("time") ?: return null
        val temperatures = forecast.optJSONArray("temperature_2m") ?: return null
        val codes = forecast.optJSONArray("weather_code") ?: return null
        val count = minOf(times.length(), temperatures.length(), codes.length())
        if (count <= 0) {
            return null
        }
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).apply {
            isLenient = false
        }
        val points = ArrayList<CoupleWidgetWeatherHour>(count)
        for (index in 0 until count) {
            val rawTime = times.optString(index, "")
            val temperature = temperatures.optDouble(index, Double.NaN)
            if (rawTime.isBlank() || temperature.isNaN()) {
                continue
            }
            val parsed = try {
                formatter.parse(rawTime)
            } catch (_: Exception) {
                null
            } ?: continue
            points.add(
                CoupleWidgetWeatherHour(
                    millis = parsed.time,
                    temperatureC = temperature,
                    weatherCode = codes.optInt(index, -1),
                )
            )
        }
        if (points.isEmpty()) {
            return null
        }
        return { dateMillis, startTime, endTime ->
            summarize(points, dateMillis, startTime, endTime)
        }
    }

    internal fun summarize(
        points: List<CoupleWidgetWeatherHour>,
        dateMillis: Long,
        startTime: String,
        endTime: String,
    ): CoupleWidgetWeather? {
        val start = CoupleTimetableDisplayBuilder.parseClockMinutes(startTime) ?: return null
        val end = CoupleTimetableDisplayBuilder.parseClockMinutes(endTime) ?: return null
        if (end <= start) {
            return null
        }
        val target = Calendar.getInstance().apply { timeInMillis = dateMillis }
        val matched = ArrayList<CoupleWidgetWeatherHour>()
        for (point in points) {
            val calendar = Calendar.getInstance().apply { timeInMillis = point.millis }
            if (calendar.get(Calendar.YEAR) != target.get(Calendar.YEAR) ||
                calendar.get(Calendar.DAY_OF_YEAR) != target.get(Calendar.DAY_OF_YEAR)
            ) {
                continue
            }
            val minutes = calendar.get(Calendar.HOUR_OF_DAY) * 60 +
                calendar.get(Calendar.MINUTE)
            if (minutes < start || minutes >= end) {
                continue
            }
            matched.add(point)
        }
        if (matched.isEmpty()) {
            return null
        }
        val average = matched.map { it.temperatureC }.average().roundToInt()
        val worst = matched.maxByOrNull { severity(kindOf(it.weatherCode)) }
        return CoupleWidgetWeather(
            kind = kindOf(worst?.weatherCode ?: -1),
            temperatureC = average,
        )
    }

    internal data class CoupleWidgetWeatherHour(
        val millis: Long,
        val temperatureC: Double,
        val weatherCode: Int,
    )

    private fun kindOf(code: Int): String = when (code) {
        0, 1 -> "clear"
        2 -> "partlyCloudy"
        3, 45, 48 -> "overcast"
        71, 73, 75, 77, 85, 86 -> "snow"
        95, 96, 99 -> "storm"
        in 51..67, in 80..82 -> "rain"
        else -> "overcast"
    }

    private fun severity(kind: String): Int = when (kind) {
        "clear" -> 0
        "partlyCloudy" -> 1
        "overcast" -> 2
        "rain", "snow" -> 3
        "storm" -> 4
        else -> 2
    }
}
