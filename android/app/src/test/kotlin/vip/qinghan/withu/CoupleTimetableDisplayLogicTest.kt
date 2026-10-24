package vip.qinghan.withu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣卡片空态的两处判断：今天是否已结束、文案占多高。
 *
 * 这两条决定卡片上「今天课程已结束」这条文案落到哪里——是整列居中，还是
 * 像其他空态一样贴在列首。渲染层没法在没有设备的情况下断言，所以把判断本身
 * 纯函数化后钉在这里。
 */
class CoupleTimetableDisplayLogicTest {

    // --- isEmptyEndedNotice --------------------------------------------------

    @Test
    fun `today ended with nothing left for tomorrow is the centred notice`() {
        assertTrue(
            CoupleTimetableDisplayBuilder.isEmptyEndedNotice(
                hasRemainingCourse = false,
                todayCourseCount = 4,
                tomorrowCourseCount = 0,
            ),
        )
    }

    @Test
    fun `tomorrow has courses keeps the notice above the list`() {
        // 明日有课时文案要给课程让位：上方一条 Notice，下方明日课程。
        assertFalse(
            CoupleTimetableDisplayBuilder.isEmptyEndedNotice(
                hasRemainingCourse = false,
                todayCourseCount = 4,
                tomorrowCourseCount = 2,
            ),
        )
    }

    @Test
    fun `a day without any course is not the ended notice`() {
        // 今天本来没课 → 文案是「今天没有课程」，与「已结束」不是一回事。
        assertFalse(
            CoupleTimetableDisplayBuilder.isEmptyEndedNotice(
                hasRemainingCourse = false,
                todayCourseCount = 0,
                tomorrowCourseCount = 0,
            ),
        )
    }

    @Test
    fun `a course still to come is not the ended notice`() {
        assertFalse(
            CoupleTimetableDisplayBuilder.isEmptyEndedNotice(
                hasRemainingCourse = true,
                todayCourseCount = 4,
                tomorrowCourseCount = 0,
            ),
        )
    }

    // --- emptyRowHeightPx ---------------------------------------------------

    @Test
    fun `centred notice fills the column so the text lands in the middle`() {
        val height = CoupleTimetableSizingSupport.emptyRowHeightPx(
            availableListHeightPx = 240f,
            courseRowHeightPx = 52f,
            endedNotice = true,
        )

        assertEquals(240f, height, 0f)
    }

    @Test
    fun `every empty state fills the column so the text is centred`() {
        val height = CoupleTimetableSizingSupport.emptyRowHeightPx(
            availableListHeightPx = 240f,
            courseRowHeightPx = 52f,
            endedNotice = false,
        )

        assertEquals(240f, height, 0f)
    }

    // --- visibleCourseCount（部分行） ----------------------------------------

    @Test
    fun `a next row is kept when at least 12dp is visible`() {
        // 4×2 185dp：列表区 133dp → 2 整行 + 第 3 行露出 19dp。
        assertEquals(
            3,
            CoupleTimetableSizingSupport.visibleCourseCount(
                maxCount = 5,
                availableHeightPx = 133f,
                hasNotice = false,
                density = 1f,
            ),
        )
    }

    @Test
    fun `with a notice the next row only shows if it clears the minimum`() {
        // 4×2 185dp + 提示：课程区 66.5dp → 1 整行，下一行只露 4.5dp 被省略。
        assertEquals(
            1,
            CoupleTimetableSizingSupport.visibleCourseCount(
                maxCount = 3,
                availableHeightPx = 133f,
                hasNotice = true,
                density = 1f,
            ),
        )
    }

    @Test
    fun `4x3 at 279dp fits four full rows`() {
        assertEquals(
            4,
            CoupleTimetableSizingSupport.visibleCourseCount(
                maxCount = 5,
                availableHeightPx = 227f,
                hasNotice = false,
                density = 1f,
            ),
        )
    }

    @Test
    fun `4x3 at the 180dp minimum keeps a partial third row`() {
        assertEquals(
            3,
            CoupleTimetableSizingSupport.visibleCourseCount(
                maxCount = 5,
                availableHeightPx = 128f,
                hasNotice = false,
                density = 1f,
            ),
        )
    }

    @Test
    fun `4x2 at the 110dp minimum does not keep a 1dp sliver`() {
        assertEquals(
            1,
            CoupleTimetableSizingSupport.visibleCourseCount(
                maxCount = 5,
                availableHeightPx = 58f,
                hasNotice = false,
                density = 1f,
            ),
        )
    }
}
