package vip.qinghan.withu

import android.content.Context

/**
 * 情侣课表 4×2：与 4×3 卡片共用同一套快照、渲染与点击分流，只有尺寸声明不同。
 * Android 要求每份尺寸声明挂在不同 Provider 类上，因此这里只覆写身份。
 */
class CoupleTimetableWideWidgetProvider : CoupleTimetableWidgetProvider() {
    override fun providerClass(): Class<out BaseQinghanWidgetProvider> =
        CoupleTimetableWideWidgetProvider::class.java

    companion object {
        fun updateAll(context: Context) {
            CoupleTimetableWideWidgetProvider().updateAll(context)
        }
    }
}
