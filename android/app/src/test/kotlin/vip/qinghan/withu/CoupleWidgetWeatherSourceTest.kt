package vip.qinghan.withu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar

class CoupleWidgetWeatherSourceTest {

    private fun dayStart(year: Int, month: Int, day: Int): Long =
        Calendar.getInstance().apply {
            clear()
            set(year, month, day, 0, 0, 0)
        }.timeInMillis

    private fun hour(
        day: Long,
        hourOfDay: Int,
        temperature: Double,
        code: Int,
    ): CoupleWidgetWeatherSource.CoupleWidgetWeatherHour {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = day
            set(Calendar.HOUR_OF_DAY, hourOfDay)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return CoupleWidgetWeatherSource.CoupleWidgetWeatherHour(
            millis = calendar.timeInMillis,
            temperatureC = temperature,
            weatherCode = code,
        )
    }

    @Test
    fun `averages temperature and keeps the most severe condition`() {
        val day = dayStart(2026, Calendar.OCTOBER, 24)
        val weather = CoupleWidgetWeatherSource.summarize(
            points = listOf(
                hour(day, 8, 20.0, 0),
                hour(day, 9, 24.0, 61),
            ),
            dateMillis = day,
            startTime = "08:00",
            endTime = "09:40",
        )

        assertEquals("rain", weather?.kind)
        assertEquals(22, weather?.temperatureC)
    }

    @Test
    fun `course outside the forecast hours has no weather`() {
        val day = dayStart(2026, Calendar.OCTOBER, 24)
        val weather = CoupleWidgetWeatherSource.summarize(
            points = listOf(hour(day, 8, 20.0, 0)),
            dateMillis = day,
            startTime = "10:00",
            endTime = "11:40",
        )

        assertNull(weather)
    }

    @Test
    fun `weather from another day is ignored`() {
        val day = dayStart(2026, Calendar.OCTOBER, 24)
        val nextDay = dayStart(2026, Calendar.OCTOBER, 25)
        val weather = CoupleWidgetWeatherSource.summarize(
            points = listOf(hour(nextDay, 8, 20.0, 0)),
            dateMillis = day,
            startTime = "08:00",
            endTime = "09:40",
        )

        assertNull(weather)
    }
}
