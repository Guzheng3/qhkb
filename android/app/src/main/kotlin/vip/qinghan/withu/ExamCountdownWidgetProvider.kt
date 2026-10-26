package vip.qinghan.withu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * 考试倒计时卡 2×2：设计稿的白底双栏样式。
 *
 * 左上蓝色徽章；主考试左侧巨型天数（数字 40sp / 今天·考试中降档），
 * 右侧考试名 + 日期（含星期）+ 地点；下方分隔线后最多两条「其他考试」，
 * 数据来自活动档案 JSON 的 exams 数组（见 [ExamWidgetList]），不使用 demo 常量。
 */
class ExamCountdownWidgetProvider : BaseQinghanWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        ExamCountdownWidgetProvider::class.java

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // 卡片被移除时清掉绑定档案与专属快照，防止孤儿数据越积越多。
        appWidgetIds.forEach { appWidgetId ->
            WidgetBindingStore.remove(context, appWidgetId)
            HomeWidgetStorage.clearWidgetSnapshot(context, appWidgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            ExamCountdownWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_exam_card)
        val snapshot = TodayWidgetSupport.readSnapshot(context)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        TodayWidgetSupport.applySquareLetterbox(
            views,
            R.id.widget_root,
            profile,
            context.resources.displayMetrics.density,
        )
        // 设计稿固定白卡（夜间走 drawable-night 深底），文字与芯片统一按 solid 配色，
        // 避免用户选择 gradient/glass 后白底配白字。
        val primaryColor = TodayWidgetSupport.primaryTextColor("solid", context)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor("solid", context)

        // 徽章固定在左上角，始终是设计稿的蓝色「考试倒计时」。
        views.setTextViewText(R.id.exam_chip, context.getString(R.string.widget_exam_card_chip))
        views.setInt(
            R.id.exam_chip,
            "setBackgroundResource",
            TodayWidgetSupport.statusBackgroundRes("upcoming", "solid"),
        )
        views.setTextColor(
            R.id.exam_chip,
            TodayWidgetSupport.statusChipTextColor("upcoming", "solid", context),
        )
        TodayWidgetSupport.setTextSizeSp(views, R.id.exam_chip, 8f)

        if (snapshot == null || snapshot.nextExamName.isNullOrBlank()) {
            renderEmptyState(context, views, profile, secondaryColor)
        } else {
            renderExam(context, views, snapshot, profile, primaryColor, secondaryColor)
        }

        views.setOnClickPendingIntent(
            R.id.widget_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /** 空态：徽章 + 居中「暂无考试安排」，不显示占位符和「点击打开首页」。 */
    private fun renderEmptyState(
        context: Context,
        views: RemoteViews,
        profile: TodayWidgetSizeProfile,
        textColor: Int,
    ) {
        views.setViewVisibility(R.id.exam_hero, View.GONE)
        views.setViewVisibility(R.id.exam_divider, View.GONE)
        views.setViewVisibility(R.id.exam_row1, View.GONE)
        views.setViewVisibility(R.id.exam_row2, View.GONE)
        views.setViewVisibility(R.id.exam_empty, View.VISIBLE)
        views.setTextViewText(R.id.exam_empty, context.getString(R.string.widget_exam_none))
        views.setTextColor(R.id.exam_empty, textColor)
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_empty,
            if (profile.isShort) 11f else 13.5f,
        )
    }

    private fun renderExam(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo,
        profile: TodayWidgetSizeProfile,
        primaryColor: Int,
        secondaryColor: Int,
    ) {
        views.setViewVisibility(R.id.exam_empty, View.GONE)
        views.setViewVisibility(R.id.exam_hero, View.VISIBLE)

        val isOngoing = TodayWidgetSupport.isExamOngoing(snapshot)
        val daysUntil = snapshot.nextExamDaysUntil ?: 0
        // 沿用旧卡的阶段判断：进行中 / 今天 / 数字倒计时。
        val numericDays = !isOngoing && daysUntil > 0
        val startTime = cleanNullable(snapshot.nextExamStartTime)
        val endTime = cleanNullable(snapshot.nextExamEndTime)
        val location = cleanNullable(snapshot.nextExamLocation)

        views.setTextViewText(
            R.id.exam_days,
            when {
                numericDays -> daysUntil.toString()
                isOngoing -> context.getString(R.string.widget_status_exam_ongoing)
                else -> context.getString(R.string.widget_exam_today_big)
            },
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_days,
            when {
                !numericDays -> if (profile.isShort) 17f else 22f
                daysUntil >= 100 -> 27f
                else -> 34f
            },
        )
        views.setTextColor(R.id.exam_days, primaryColor)

        // 「天」只服务数字形态；今天/考试中不显示单位。
        views.setViewVisibility(R.id.exam_day_unit, if (numericDays) View.VISIBLE else View.GONE)
        if (numericDays) {
            views.setTextViewText(
                R.id.exam_day_unit,
                context.getString(R.string.widget_exam_unit_day),
            )
            views.setTextColor(R.id.exam_day_unit, secondaryColor)
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.exam_day_unit,
                if (profile.isShort) 8.5f else 10f,
            )
        }

        views.setTextViewText(
            R.id.exam_name,
            TodayWidgetSupport.examDisplayName(snapshot)
                ?: context.getString(R.string.widget_exam_fallback_name),
        )
        views.setTextColor(R.id.exam_name, primaryColor)
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_name,
            if (profile.isShort) 10f else 12f,
        )

        // 倒计时显示「06-25 周四」，今天/进行中改用考试时间，与设计稿一致。
        val dateText = when {
            isOngoing && endTime != null ->
                context.getString(R.string.widget_exam_until, endTime)
            daysUntil == 0 && startTime != null && endTime != null -> "$startTime - $endTime"
            else -> ExamWidgetList.examDateLabel(context, snapshot.nextExamDate)
        }
        views.setTextViewText(R.id.exam_date, dateText)
        views.setTextColor(R.id.exam_date, secondaryColor)
        views.setViewVisibility(R.id.exam_date, if (dateText.isBlank()) View.GONE else View.VISIBLE)
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_date,
            if (profile.isShort) 8.5f else 9.5f,
        )

        views.setTextViewText(R.id.exam_location, location.orEmpty())
        views.setTextColor(R.id.exam_location, secondaryColor)
        views.setViewVisibility(
            R.id.exam_location,
            if (location == null) View.GONE else View.VISIBLE,
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_location,
            if (profile.isShort) 8.5f else 9.5f,
        )

        bindOtherExams(context, views, snapshot, profile, primaryColor, secondaryColor)
    }

    private fun bindOtherExams(
        context: Context,
        views: RemoteViews,
        snapshot: TodayWidgetSnapshotInfo,
        profile: TodayWidgetSizeProfile,
        primaryColor: Int,
        secondaryColor: Int,
    ) {
        // 矮卡放不下两条列表，先让出「其他考试」保主信息不裁切。
        val others = if (profile.isShort) {
            emptyList()
        } else {
            ExamWidgetList.readOtherExams(
                context = context,
                heroDate = snapshot.nextExamDate,
                heroStartTime = snapshot.nextExamStartTime,
                limit = 2,
            )
        }
        views.setViewVisibility(
            R.id.exam_divider,
            if (others.isEmpty()) View.GONE else View.VISIBLE,
        )
        bindOtherExamRow(
            context = context,
            views = views,
            rowId = R.id.exam_row1,
            barId = R.id.exam_row1_bar,
            nameId = R.id.exam_row1_name,
            daysId = R.id.exam_row1_days,
            entry = others.getOrNull(0),
            profile = profile,
            primaryColor = primaryColor,
            secondaryColor = secondaryColor,
        )
        bindOtherExamRow(
            context = context,
            views = views,
            rowId = R.id.exam_row2,
            barId = R.id.exam_row2_bar,
            nameId = R.id.exam_row2_name,
            daysId = R.id.exam_row2_days,
            entry = others.getOrNull(1),
            profile = profile,
            primaryColor = primaryColor,
            secondaryColor = secondaryColor,
        )
    }

    private fun bindOtherExamRow(
        context: Context,
        views: RemoteViews,
        rowId: Int,
        barId: Int,
        nameId: Int,
        daysId: Int,
        entry: ExamWidgetEntry?,
        profile: TodayWidgetSizeProfile,
        primaryColor: Int,
        secondaryColor: Int,
    ) {
        if (entry == null) {
            views.setViewVisibility(rowId, View.GONE)
            return
        }
        views.setViewVisibility(rowId, View.VISIBLE)
        views.setInt(barId, "setBackgroundColor", entry.color)
        views.setTextViewText(nameId, entry.name)
        views.setTextColor(nameId, primaryColor)
        TodayWidgetSupport.setTextSizeSp(
            views,
            nameId,
            if (profile.isShort) 9.5f else 10f,
        )
        views.setTextViewText(
            daysId,
            "${entry.daysUntil} ${context.getString(R.string.widget_exam_unit_day)}",
        )
        views.setTextColor(daysId, secondaryColor)
        TodayWidgetSupport.setTextSizeSp(views, daysId, 8.5f)
    }

    private fun cleanNullable(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        return value.takeIf {
            it.isNotEmpty() && !it.equals("null", ignoreCase = true)
        }
    }
}
