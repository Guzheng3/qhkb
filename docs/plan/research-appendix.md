# 调研附录

本附录是 [product-plan.md](product-plan.md) 的事实来源，可独立阅读。

- 调研与访问日期：**2026-10-20**（Asia/Shanghai）；单独标注者除外。
- 三部分：A 课表类 App 竞品、B 情侣／双人协同类产品、C 开源实现与技术方案。
- 事实纪律：只记录可核实的公开信息；取证失败或来源不足的一律标注「**未证实**」，不作推测性补全，也不以厂商宣传语替代事实。
- 取证工具限制：本机 `web_search` 不可用（返回空结果），DuckDuckGo／Brave／Mojeek 被拒或被网络拦截，百度百科返回 403，腾讯应用宝与酷安检索页未取到可解析内容；`developer.android.com` 全站抓取失败（`fetch failed`）。凡受此影响的条目在正文与文末清单中均标注取证失败原因；**取证失败不等于「没有此功能」**。
- 来源优先级：产品官网／官方帮助文档 > Apple App Store 中国区页面与 `itunes.apple.com` 官方接口 > 腾讯应用宝详情页 > 官方 SDK 平台元数据 > 公开仓库 README 与元数据 > 用户评论（第三方主观，会明确标注）。

---

## A 课表类 App 竞品

### A.1 WakeUp课程表

- **产品名与平台**：WakeUp课程表；官方支持 Android、鸿蒙（HarmonyOS NEXT）、iOS 三端，官网自述"1800+ 高校"（https://www.wakeup.fun/ ，2026-10-20）。鸿蒙 NEXT 版单独上架华为应用市场。
- **收费模式**：商店页均标免费——App Store 价格 0 元（https://apps.apple.com/cn/app/id1553402284 ，2026-10-20），应用宝标"官方正版免费下载"（https://sj.qq.com/appdetail/com.suda.yzune.wakeupschedule ，2026-10-20）。内购／会员／订阅价格：**未证实**；官方文档把 iCloud 同步、导出日历、更多小组件、上课提醒归入"高级功能"，但未说明是否收费（https://www.wakeup.fun/doc/settings/advance_features.html ，2026-10-20）。
- **课表核心能力**：默认周视图（日期栏 + 左侧时间轴）；支持多课表且各课表配置独立；"课表数据"含一天课程节数、学期周数、当前周、学期开始日期、周日是否为首日；"上课时间"可保存多套时间表（节次时间模板），可取消"每节课时长相同"逐节调时长（https://www.wakeup.fun/doc/settings/schedule_settings.html ，2026-10-20）。课程按"时间段"组织，每个时间段独立设星期几、地点、教师、上下课时间与周数范围；iOS 版没有"日期模式"（按起止日期录入）（https://www.wakeup.fun/doc/add_course.html ，2026-10-20）。单双周／指定周的逐字勾选项：文档只写"周数"设置，**未证实**。
- **录入方式**：教务系统导入——官方文档 1200+ 所（https://www.wakeup.fun/doc/ ，2026-10-20）、官网首页 1800+、应用宝简介 3000+（https://sj.qq.com/appdetail/com.suda.yzune.wakeupschedule ，2026-10-20）、App Store 简介 2000+（https://apps.apple.com/cn/app/id1553402284 ，2026-10-20），四处口径互不一致；HTML 文件导入、Excel/CSV 模板导入（https://www.wakeup.fun/doc/import_from_file.html ，2026-10-20）；分享码导入（App Store 与应用宝简介）。截图识别：**未证实**。
- **提醒能力**：上课前自动提醒、提前时间可自定义（App Store 简介）；"上课提醒"同时在"高级功能"清单内。系统闹钟形式的叫醒：**未证实**。
- **桌面小组件与系统集成**：Android 4 种（今日课程／近日课程／一周课程／日视图），鸿蒙另加 2 张图标上划卡片，iOS 5 种；其中 Android 的"一周课程""日视图"支持样式自定义与切换课表；官方明确提示要允许后台自启与后台运行才能保证小组件正常（https://www.wakeup.fun/doc/widget.html ，2026-10-20）。灵动岛／实况窗／厂商"岛"类适配：**未证实**。
- **天气或附加能力**：App Store 简介提到"日程管理"等内置小工具。天气功能：**未证实**。
- **共享或多人协同**：仅见"分享码导入"（同学间课表分发）；是否支持持续同步的双向协同：**未证实**。
- **可借鉴点**：多套节次时间模板 + 逐节时长覆盖；同一份课表在三端都提供多尺寸桌面小组件；录入通道做成"教务 + 文件 + 分享码"三条并行；官方帮助文档把每个设置项写全。
- **短板与限制**：应用宝显示 20.0 万下载、评分 4.8 并标注"无广告"（2026-10-20），而 iOS 端 2776 个评分的均分仅约 1.7（App Store，2026-10-20），两端口碑差异显著；高校适配数量对外四个口径不一致；iOS 功能少于 Android/鸿蒙（无日期模式，小组件样式等归入"高级功能"）。

### A.2 超级课程表

- **产品名与平台**：超级课程表；Android + iOS；开发与运营均为广州超级周末科技有限公司（https://sj.qq.com/appdetail/com.xtuone.android.syllabus ，2026-10-20），官网 https://www.super.cn/ 。
- **收费模式**：商店页标免费（应用宝详情页；App Store 价格 0 元 https://apps.apple.com/cn/app/id573868981 ）。订阅／买断价格：**未证实**。应用宝页面标注"无广告"，但用户评论（2021—2022 年，第三方主观）集中抱怨开屏与跳转广告，两者不一致，均非官方功能口径。
- **课表核心能力**：可自由切换日课表与周课表、一键导入课表、桌面小组件看课表（App Store 与应用宝简介）。节次时间模板、单双周：**未证实**。
- **录入方式**：一键导入；版本更新说明称"本次新增/修复 26 所大学从系统自动导入课表，累计支持 3618 所大学自动导入课表，2443 所高校一键从官方导入各大考试时间"（App Store 版本 9.9.54 更新说明，2026-10-09）。ics／截图识别／表格导入／分享码：**未证实**。
- **提醒能力**：考试计划提醒与日程倒计时（App Store 与应用宝简介）。课前提醒、上课闹钟：**未证实**。
- **桌面小组件与系统集成**：桌面小组件（App Store 与应用宝简介）。"岛"类适配：**未证实**。
- **天气或附加能力**：官方考试时间同步（版本说明）、成绩查询与校友求助／语音互动（均为应用宝用户评论提及，第三方主观）。天气：**未证实**。
- **共享或多人协同**：**未证实**。
- **可借鉴点**：把"全校官方考试时间"这类校内强需求与课表打通，做出课表之外的日程价值；用户规模大（应用宝 1807.2 万下载，2026-10-20）。
- **短板与限制**：评分偏低——应用宝 4.2，iOS 14882 个评分均分约 2.93（2026-10-20）；广告投诉集中（第三方用户评论）；教务解析依赖人工适配学校。

### A.3 拾光课程表（shiguangschedule）

- **名称指向（已查清）**：在 GitHub 检索 `shiguangschedule`，命中的是开源项目 ShiGuangSchedule/shiguangschedule——**Apache-2.0**、984 stars、2026-10-19 更新，仓库描述"一款开源、无广告、极简的课程表 APP，支持教务导入"（https://api.github.com/search/repositories?q=shiguangschedule ，2026-10-20；仓库 https://github.com/ShiGuangSchedule/shiguangschedule ）；其官方文档站自述"拾光课程表是一款面向中国高校师生的课程表应用"（https://sgschedule.jursin.top/about.html ，2026-10-20）。微信公众号生态中亦有介绍该开源课表 App 的文章（"无广告、无会员、无开屏页，Apache-2.0 协议"；https://weixin.sogou.com/weixin?type=2&query=拾光课程表 ，2026-10-20，第三方内容）。产品正式名是"拾光课程表"。
- **渠道取证记录**：酷安网页检索返回 HTTP 404，未取得条目（https://www.coolapk.com/search?q=shiguangschedule ，2026-10-20）；APKPure、APKCombo、Google Play 在本次网络环境下均抓取失败（fetch failed）。
- **产品名与平台**：拾光课程表；2.x 起迁移到 Compose Multiplatform／KMP，仓库含 androidApp、shared、desktopApp（Desktop JVM）与 iosApp（Xcode 单独构建），Android 产物按 arm64-v8a／armeabi-v7a／x86_64 分包（https://sgschedule.jursin.top/guide/developer/app-dev.html ，2026-10-20）。FAQ 只给出安卓小部件的添加方式（以小米/红米为例）（https://sgschedule.jursin.top/faq.html ）。iOS 端是否上架 App Store：**未证实**。
- **收费模式**：开源，GitHub 仓库许可证为 Apache-2.0；文档站首页自述"开源·轻量·启动快·无广告"（https://sgschedule.jursin.top/ ）。内购／会员：无证据。
- **课表核心能力**：今日课表与周次课表两个主页面；周次课表支持左右滑动切周、长按拖拽调整课程块位置或高度、当前时间指示线、已上课程删除线；学期配置含开学日期、学期总周数、每周起始日、当前周、显示周末/非本周课程；高级功能含多课表创建与切换、全局课程增删改、自定义时间段；支持 24 小时时间轴模式（https://sgschedule.jursin.top/ ）。单双周的表达方式：**未证实**（数据模型里周次以 `weeks` 数组表示）。
- **录入方式**：教务系统导入，依赖社区开发者编写适配脚本（适配脚本集中在独立仓库 https://github.com/ShiGuangSchedule/shiguang_warehouse ）；JSON 课程文件导入/导出（结构为 `courses` + `timeSlots` + `config`，每门课带 `weeks` 周次数组）；ICS 日历文件导出（可生成带提醒时间参数的文件）；**星链课表分享码导入**（路径："选择学校-通用工具-通用工具与服务 → 执行导入-输入分享口令"）；同步到系统日历；WebDAV 云同步与本地 ZIP 备份（https://sgschedule.jursin.top/guide/user/schedule-import.html 、https://sgschedule.jursin.top/guide/user/export-and-share.html ）。截图识别：**未证实**。
- **提醒能力**：课前提醒，并可设置上课自动开启勿扰／静音；同步全年节假日数据避免假期打扰（https://sgschedule.jursin.top/ ）。
- **桌面小组件与系统集成**：多尺寸多种样式（紧凑型、列表竖直型、双日型、微型 2×1），支持明日课程预告、跟随深色模式。"岛"类适配：**未证实**。
- **天气或附加能力**：未发现天气功能；附加能力为多课表、JSON/ICS 导入导出、WebDAV 备份、多语言（简体中文／繁体中文／英语）。
- **共享或多人协同**：可导入他人分享的"星链课表分享码"，属单向导入；WebDAV 是个人云同步，无多人协同证据。
- **可借鉴点**：教务适配社区化（适配脚本独立仓库 + 专用测试器仓库）；数据模型清晰（courses + timeSlots + config，周次用数组）；ICS 导出可带提醒参数；对没有账号体系的开源项目，WebDAV 是低成本同步方案。
- **短板与限制**：教务覆盖面取决于社区适配进度，官方不给覆盖数字；无天气、无情侣/多人协同；iOS 端需自行用 Xcode 构建；FAQ 中申请适配需提供教务系统账号密码，存在凭据风险（官方亦提示"请了解相关风险与注意事项"，https://sgschedule.jursin.top/faq.html ）。
- **近名排除**：另有"时光序"（应用宝 com.duorong.smarttool，花生未来（广州）科技有限公司，V4.21.0，2025-12-30，1248.3 万下载，评分 5.0，标注无广告）——它是含"课程表"在内的 18 场景时间管理 App，日/周/月视图、多端登录、云端同步、桌面组件，"每日先知"含天气；与 shiguangschedule 无关（https://sj.qq.com/appdetail/com.duorong.smarttool ，2026-10-20）。此条仅作排除记录，不进入对比表。

### A.4 星链课表

- **名称指向（已查清）**：Apple App Store 中国区检索"星链课表"命中 App「星链课表」：iOS 15.0+、免费、版本 4.20.6（2026-10-10 更新，2025-09-25 上架）、648 个评分均值约 4.87、开发者署名"震 陈"、官网 https://www.starlinkkb.cn （https://apps.apple.com/cn/app/id6752886418 ，2026-10-20）。用泛词"星链"检索无果，是因为该词被 SpaceX Starlink 与网络加速类产品占据（https://itunes.apple.com/search?term=星链&country=cn&entity=software ）；腾讯应用宝检索"星链课表"也无同名应用（https://sj.qq.com/search?q=星链课表 ），说明其 Android 端走官网 APK 分发。
- **渠道取证记录**：酷安网页检索返回 HTTP 404（https://www.coolapk.com/search?q=星链课表 ）；APKPure、Google Play 抓取失败（fetch failed）；GitHub 第三方插件把"星链（课表）"与 WakeUp、拾光并列支持，可交叉印证它是一个独立的课表产品（https://github.com/VincentZyuApps/koishi-plugin-course-schedule ，第三方项目）。
- **产品名与平台**：星链课表；iOS／iPadOS 15.0+（App Store），Android 安装包由官网提供（https://www.starlinkkb.cn/download/android ）；官网自述小组件适配小米、华为、荣耀、OPPO、vivo、三星、一加、realme、iPhone、iPad，并"还适配了小米超级岛"（https://www.starlinkkb.cn/ ）。运营主体：官网页脚"星链传媒（惠州市）有限公司"。
- **收费模式**：官网 FAQ 明确"可以免费下载使用，没有开屏广告，也没有信息流广告"；App Store 价格 0 元。内购／会员：**未证实**。
- **课表核心能力**：今日/一周/近日课表、学期进度、实时时间线；多课表；主题体系（动态天气、毛玻璃、深色、15 种主题配色、AI 生成格子色、主题一键分享）。节次时间模板、单双周的具体表达：**未证实**。
- **录入方式**：教务系统一键导入（官网列出正方、强智、青果、URP、金智、树维、超星、乘方、南软、优慕课、优霓，自述覆盖 2000+ 所高校，并同时带回考试与成绩）；AI 截图识别（截图／拍照／粘贴文字，官网称约 3 秒成表）；AI 网页与文件识别；分享码导入（同学分享整张课表）。ics：**未证实**。
- **提醒能力**：课前提醒、上课自动静音、同步系统日历、考试倒计时小组件。
- **桌面小组件与系统集成**：一周课表、今日与近日、本周概览等小组件，多尺寸且壁纸／透明度／圆角／字体可调，含"下一件日程"与考试倒计时；官网明示适配小米超级岛。
- **天气或附加能力**：动态天气主题（"下雨时雨滴落在课表上"，随真实天气变化）；工具箱含成绩与绩点（GPA 支持 5.0／4.0 制）、AI 助手"小海星"、空教室查询、考证中心、带农历节气的智能时间轴。
- **共享或多人协同**：官网列出"**情侣课表**"（首页可看两人同一天的课）与"**多人比对，找共同空闲**"，另有分享码导入。这是本次调研中唯一把"情侣共享"做成明确功能入口的产品，但绑定方式、权限与冲突处理等细节官方未展开，**具体实现未证实**。
- **可借鉴点**：AI 截图/网页识别导入，把"教务适配"从硬依赖降级为兜底；情侣课表 + 多人比对直接对应情侣共享方向；天气做成"动态主题"而不是独立天气模块；系统级卡片适配；把"没有广告"写成对外承诺。
- **短板与限制**：官方自述与商店数据不一致——官网写"App Store 评分 4.9，来自 454 个评分"，同期 App Store 接口为 648 个评分、均值约 4.87；官网自述"2000+ 高校""10 万+ 大学生"均为官方口径、**未证实**；Android 端只走官网 APK，无第三方商店背书；免费无广告且无可见内购的商业模式可持续性**未证实**。

### A.5 课程格子（名称指向未证实）

- **结论**：无法证实"课程格子"当前是否仍在运营、其功能形态为何，本节所有功能字段标记**未证实**。
- **取证过程**：腾讯应用宝检索"课程格子"返回"课程伴侣／番茄课程表／Simple课程表／无敌课程表"等，无同名应用（https://sj.qq.com/search?q=课程格子 ）；Apple App Store 中国区检索"课程格子"同样未返回同名应用，返回的是超级课程表、极简课程表、WakeUp课程表、无敌课程表、ClassTable（https://itunes.apple.com/search?term=课程格子&country=cn&entity=software ）；必应中国站相关检索未返回产品页面；百度百科词条页返回 HTTP 403，无法取证（https://baike.baidu.com/item/课程格子 ）。
- **继续调研所需输入**：指向（安卓包名、iOS 链接或官网）。若它是早期大学生课表产品，需要以现存页面或应用商店条目为准，不能用记忆或行业传闻补齐。

### A.6 厂商原生课表（小米／华为／OPPO／vivo 自带）

- **形态判断（有据部分）**：在腾讯应用宝检索"小爱课程表""华为课程表"，未返回任何厂商出品的课程表应用，返回的是第三方课表（星课程表、南瓜课程表、番茄课程表、极简课程表等）与厂商其他应用（华为浏览器等）（https://sj.qq.com/search?q=小爱课程表 、https://sj.qq.com/search?q=华为课程表 ）。据此只能确认：厂商课表不是以独立 App 在第三方分发渠道上架的产品，更可能是系统预置应用或系统卡片。
- **未证实部分**：华为应用市场搜索页为前端渲染，抓取返回空内容（https://appgallery.huawei.com/search/课程表 ）；华为官网支持站搜索需要前端交互、未取得条目（https://consumer.huawei.com/cn/support/search/?keyword=课程表 ）；vivo 官网服务检索路径返回 404（https://www.vivo.com.cn/service/search?keyword=课程表 ）；小米官网检索页落到商城导航、无服务文档结果（https://www.mi.com/service/search?keyword=课程表 ）。因此四个厂商课表的**全部功能字段**（周／日视图、节次模板、单双周、教务导入、课前提醒、桌面卡片、灵动岛／实况窗类适配、天气、共享协同）均为**未证实**。

### A.7 星课程表（补充样本，与"共享／情侣"场景直接相关）

- **产品名与平台**：星课程表（StarSchedule）；官网自述 iOS／Android 双端（https://starschedule.xingqingchuang.com/ ）；安卓包名 com.xingqingchuang.starschedule，应用宝评分 4.7（https://sj.qq.com/appdetail/com.xingqingchuang.starschedule ）。
- **收费模式**：官网写明"主功能免费""海报每日限一次""无开屏推送"；会员／内购价格：**未证实**。
- **课表核心能力**：周课表、日程视图两种主视图（官网首页截图区）。节次模板、单双周：**未证实**。
- **录入方式**："智能导入全国高校课表"、教务系统导入（官网文案），另设"院校列表"页面。ics／截图识别／表格导入／分享码：**未证实**。
- **提醒能力**：官网文案提到课程提醒与备忘录、倒数日；具体提醒形式：**未证实**。
- **桌面小组件与系统集成**：官网未列出桌面小组件，**未证实**。
- **天气或附加能力**：备忘录、倒数日（官网文案）；天气：**未证实**。
- **共享或多人协同**：官网卖点含"好友同步""好友课表绑定"，并设"组织合作"入口。注意：官网页面自己声明其中的用户证言是"典型功能场景展示，不代表真实用户评价"，因此"情侣共享课表""和室友共享课表"这类页面文案只能算官方宣传场景，**共享功能的实际形态与可用性未证实**。
- **可借鉴点**：把好友／情侣共享直接放到首页卖点与独立入口；对外把免费边界讲清楚；用"院校列表 + 组织合作"承接 B 端／社团合作。
- **短板与限制**：没有官方帮助文档，应用宝页未显示下载量，功能细节无法交叉验证。
- **与 A.4 的区分**：星课程表（com.xingqingchuang.starschedule）与星链课表不是同一产品。

### A.8 极简课程表（补充样本，"岛"类系统集成有明确证据）

- **产品名与平台**：极简课程表（watch课程表）；iOS，开发者为杭州简云科技有限公司，版本 7.2.5、2026-09-06 更新、9666 个评分均分约 4.74（https://apps.apple.com/cn/app/id1581272719 ）。应用宝另有包名 cn.jianyun.timetable 的"极简课程表"，与本 iOS 应用是否同一产品：**未证实**。
- **收费模式**：商店标免费；官方简介写"会员没有广告"，即存在会员形态，具体价格与计费方式**未证实**。
- **课表核心能力**：可分别设置早晨／上午／下午／晚上各阶段课程数量与每节课上下课时间；可设学期周数与当前周；支持多课表、一键配色、手动调节课程高度；每节课周数支持"全部、单独、双周、指定周"；支持重叠时段并行课程；支持调休调课；支持自定义某节课上下课时间（官方简介）。
- **录入方式**：教务网站导入；支持课表分享与导入；iCloud 课表同步；导出课程到日历。
- **提醒能力**："课程提醒"（官方简介）。
- **桌面小组件与系统集成**：自定义桌面小组件；支持 Apple Watch；支持灵动岛和实时活动；暗黑模式。这是本次调研中唯一有明确来源的"岛"类集成证据。
- **天气或附加能力**：**未证实**。
- **共享或多人协同**：仅见课表分享／导入（单向），持续多人协同：**未证实**。
- **可借鉴点**：单双周按"全部／单独／双周／指定周"四态表达；把"调休调课""某节课单独设时长"当独立功能；iOS 侧灵动岛 + 实时活动 + Apple Watch 的系统集成路线。
- **短板与限制**：以 iOS 为主，Android 端同一性未证实；免费版与会员的功能边界在商店简介里未逐条列出。

### A.9 横向对比表

表格是 A.1–A.8 的压缩，来源与访问日期同上（2026-10-20）；"未证" = 未证实。

| 产品 | 平台 | 收费 | 课表核心 | 录入 | 提醒 | 小组件／系统集成 | 附加能力 | 共享协同 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WakeUp课程表 | Android／鸿蒙／iOS | 免费；内购未证 | 周视图为主、多课表、多套节次模板、逐节调时长；单双周未证 | 教务导入（1200/1800/2000/3000+ 四口径不一致）、HTML／CSV、分享码；截图识别未证 | 课前提醒可设提前量 | Android 4 种／鸿蒙另 2 卡／iOS 5 种小组件；岛类未证 | 日程管理小工具；天气未证 | 分享码分发；持续协同未证 |
| 超级课程表 | Android／iOS | 免费；内购未证 | 日／周课表切换、一键导入；节次模板与单双周未证 | 教务导入（版本说明称 3618 所）；ics／截图／表格／分享码未证 | 考试计划提醒、日程倒计时；课前提醒未证 | 桌面小组件；岛类未证 | 官方考试时间同步；成绩查询等仅见用户评论；天气未证 | 未证 |
| 拾光课程表 | Android／Desktop(JVM)／iOS（需自建）；商店未上架 | 开源免费（Apache-2.0）、无广告；无内购 | 今日课表 + 周次课表、拖拽调课块、24 小时时间轴、多课表、自定义时间段；单双周未证 | 教务导入（社区适配脚本）、JSON 导入导出、ICS 导出、星链分享码导入 | 课前提醒 + 上课自动静音 + 节假日同步 | 多尺寸多种小组件（含 2×1、明日预告）；岛类未证 | 多语言、WebDAV 备份；天气未证 | 星链分享码单向导入；协同未证 |
| 星链课表 | iOS／iPadOS + 官网 Android 包 | 免费、无广告；内购未证 | 今日/一周/近日课表、学期进度、实时时间线、多课表、多主题；单双周未证 | 教务导入（自述 2000+ 高校）、AI 截图识别、AI 网页/文件识别、分享码；ics 未证 | 课前提醒、上课自动静音、考试倒计时 | 一周/今日/近日/概览小组件多尺寸；官网称适配小米超级岛 | 动态天气主题；成绩 GPA、AI 助手、空教室、考证中心、农历时间轴 | 分享码 + 情侣课表 + 多人比对（官方明示，实现细节未证） |
| 课程格子 | — | — | — | — | — | — | — | — |
| 厂商原生课表（小米／华为／OPPO／vivo） | 系统预置 | 未证 | 未证 | 未证 | 未证 | 未证 | 未证 | 未证 |
| 星课程表（补充） | iOS／Android | 主功能免费；会员未证 | 周课表 + 日程视图；节次模板与单双周未证 | 教务导入、"院校列表"；其余未证 | 文案提及课程提醒／备忘录／倒数日，形式未证 | 未证 | 备忘录、倒数日；天气未证 | 官网卖点称好友同步／好友课表绑定，实际形态未证（页内评价为营销素材） |
| 极简课程表（补充） | iOS | 免费 + 会员（"会员没有广告"）；价格未证 | 分时段节次数、逐节时长、周数四态（全部／单独／双周／指定周）、重叠课、调休调课 | 教务网站导入、课表分享与导入、iCloud 同步、导出到日历 | 课程提醒 | 自定义小组件、Apple Watch、灵动岛 + 实时活动 | 未证 | 分享／导入（单向）；协同未证 |

### A.10 共性结论

1. **教务适配数量对外口径不统一**：WakeUp 的四处数字从 1200+ 到 3000+ 并存；超级课程表以版本说明方式给出 3618 所。对外数字缺少统一维护，说明这类能力是持续维护成本项而非一次性功能。
2. **免费为主，变现靠会员／高级功能**：三款可核实的商业产品商店页都标免费，会员形态见"会员没有广告"（极简课程表）与"高级功能"清单（WakeUp），但价格几乎不可见。
3. **两端口碑落差明显**：WakeUp 应用宝 4.8 对 iOS 约 1.7、超级课程表应用宝 4.2 对 iOS 约 2.93；超级课程表的用户评论集中在广告与启动体验（第三方主观）。
4. **"共享"分两档，持续协同只有一个官方样本**：一次性分发是普遍做法——分享码（WakeUp、星链课表）、课表分享／导入（极简课程表）、"星链课表分享码导入"（拾光课程表，说明已出现跨 App 的分享码互通）；而"情侣课表 + 多人比对找共同空闲"目前只有星链课表官网明示，属功能入口级证据，实现细节未证实。
5. **桌面小组件是标配，"岛"级集成开始出现**：除星课程表未证实外，其余有来源的产品都提到桌面小组件；"岛"类适配现有两条来源——极简课程表（iOS 灵动岛 + 实时活动）与星链课表（官网称适配小米超级岛）。
6. **天气的两种用法都不是"天气页"**：星链课表做成"随真实天气变化的动态主题"，时光序把天气并进"每日先知"综合工具；WakeUp、超级课程表、极简课程表、拾光课程表均未见天气能力。没有产品把独立天气模块当核心卖点。
7. **第三方工具已支持多款课表互转**：开源 Koishi 插件自述"支持 WakeUp／星链／拾光 等课程表，ICS/JSON 等多格式导入"（https://github.com/VincentZyuApps/koishi-plugin-course-schedule ，第三方项目）。说明主流课表 App 之间已形成可被第三方读写的开放数据面，导入导出格式在事实层面趋同。

### A.11 未证实清单（课表竞品）

- 名称指向：**课程格子**指向不明（应用宝与 App Store 检索均无同名应用，百科页 403）。
- 厂商原生课表（小米／华为／OPPO／vivo）：全部功能字段与"岛"类适配未证实；官方帮助文档与商店搜索均未取得可用页面。
- WakeUp课程表：单双周勾选项、截图识别、会员／内购与价格、灵动岛类适配、天气、多人协同。
- 超级课程表：节次时间模板、单双周、课前提醒、ics／截图／表格／分享码、岛类适配、天气、共享协同、内购。
- 拾光课程表：单双周的具体表达、截图识别、iOS 是否上架商店、天气、多人协同、教务覆盖学校数、会员/内购。
- 星链课表：节次时间模板与单双周、ics 导入、内购／会员、情侣课表与多人比对的实现细节、官网自述的"2000+ 高校／10 万+ 用户／App Store 4.9 分（454 个评分）"、免费无广告模式的可持续性。
- 星课程表：节次模板、单双周、提醒形式、桌面小组件、天气、共享／情侣功能的实际形态、下载量。
- 极简课程表：Android 端同一性、会员价格、天气、多人协同。
- 检索手段限制（影响取证完整性）：必应中国站对中文产品名返回大量无关结果（长尾词大量返回无关结果，`site:` 与引号不起作用；https://cn.bing.com/search?q=%22课程格子%22+课表+应用+下架 ）；酷安网页端检索路径返回 HTTP 404；APKPure／APKCombo／Google Play 抓取失败；华为应用市场搜索页前端渲染、抓取为空；百度百科 403；vivo 官网服务检索路径 404；小米官网检索页无服务文档结果；维基百科域名解析被拦截、无法访问。

---

## B 情侣／双人协同类产品

调研目的：为课表 App 的情侣共享主线（互相查看对方课表 + 小组件展示对方当前课程）提供事实输入。只记录外部产品事实，不做市场规模推算。

事实主源是官方渠道：产品官网、官方帮助中心、App Store 官方接口返回的应用元数据（版本号、定价条款、评分、权限说明）。来源编号见 B.10。

### B.1 TimeTree（タイムツリー / TimeTree: Shared Calendar）

- **产品名与平台**：TimeTree，开发商 TimeTree, Inc.；iOS（App Store 评分 4.85／92,774 条）、Android、Web 版；官方称"全球 7500 万用户"（应用描述自述）。App Store 元数据记录版本 15.32.0，更新于 2026-10-13。来源 S1、S2、S3。
- **收费模式**：免费下载 + Premium 订阅，官网标价 4.49 美元/月、44.99 美元/年（首月免费，年付相当于省 2 个月），并注明"价格可能因地区与货币而异"。免费版可用共享日历、通知、相册、备忘、多日历；Premium 增加活动文件附件（免费版仅能在事件评论发照片）、纵向日视图、置顶重要事件、专属客服、去广告。来源 S2、S4。
- **两人绑定方式**：不是"情侣账号"模型，而是**群组日历**模型——任意成员创建日历后通过邀请把对方加入（官方帮助有"For Admins / For Members"两套邀请说明）；情侣只是"两人一组的共享日历"这一用法。来源 S5、S6。
- **共享数据的同步模型**：数据写在**日历**这一共享容器里，写入对全体成员可见。官方《Shared Calendar Guidelines》明确：日历共享后，事件（标题、时间、地点、参与人、备注）、评论、图片，以及为该日历设置的资料信息（头像、名字、生日）对**其他参与者全部可见**；其他参与者还可以再邀请新成员（新成员同样获得全部可见权），也可以经 API 或备份把共享信息带到第三方服务使用，此时该参与者对这部分处理成为独立的控制者（GDPR 第 4(7) 条口径）。**冲突处理机制未证实**。来源 S6、S7。
- **桌面小组件做法**：iOS 支持锁屏与主屏小组件，Android 另有独立说明；小组件展示的是**所选日历中的事件**，可在"App 设置 → 在其他功能中显示的日历"里勾选要显示的日历，也可在小组件上设置"只显示我自己的事件"。官方明确限制：**iOS 小组件无法显示来自外部日历的事件**，事件不刷新时建议重启设备或重新添加小组件。来源 S8、S9。
- **通知与互动玩法**：事件创建／变更或消息会产生通知；每个事件内含聊天；共享相册、备忘与待办、事件内贴图、活动（Activity）流。来源 S2、S6、S8。
- **隐私与权限处理**：官方口径是**无需同意任何可选权限也能使用**（"必需权限：无"），可选权限包括日历、位置、照片、相机、广告追踪、通知、麦克风与语音识别，逐项说明用途。共享数据的保留规则：只要日历中还有参与者，日历信息就会被保留使用；退出日历或注销账号后，个人日历资料信息不再对其他参与者可见，并会从日历信息中移除；撤回同意的方式是删除自己的日历数据并退出日历，或通过咨询表单撤回全部共享日历的同意。来源 S1、S7。
- **可借鉴点**：① 以"共享容器 + 成员"抽象双人关系，天然支持未来扩展家庭／小组；② 小组件的"选择显示哪些日历"和"只显示我的事件"两个开关，是把可见性交还给用户的轻量做法；③ 明文的共享数据可见范围条款与撤回路径，比"承诺式隐私文案"更可核验。
- **短板与限制**：广告是其免费版体验的组成部分（Premium 才去广告）；iOS 小组件不支持外部日历事件，说明小组件数据管道与 App 内并非同一条；Web／PC 版存在，也意味着多端一致性成本。来源 S2、S4、S8。

### B.2 Between（비트윈，韩国）

- **产品名与平台**：Between（비트윈），开发／发行商 DLT Partners Inc.；iOS（韩国区评分 4.72／269,112 条）、Android；bundleId `kr.co.vcnc.couple`，App Store 最早发布 2011-11-21，当前版本 5.14.03，最近更新 2026-09-22。来源 S10。
- **收费模式**：免费下载（韩国区显示"무료"），描述中含内购提示但**具体档位与价格未证实**。来源 S10。
- **两人绑定方式**：**未证实**。官方文案与权限说明均未描述配对流程；仅从产品形态可知是"两人一室"的关系型应用。来源 S10。
- **共享数据的同步模型**：以"两人专属空间"承载聊天、照片、视频、日记、备忘，官方称**换手机或清空相册后内容仍在**（即数据托管在服务端而非随设备走）。日历为"一起用的日历"，并在权限说明中出现"日历：修改和登记设备日历日程"，即**可与手机系统日历双向打通**。官方称支持"从其他 messenger 导入聊天记录"。冲突处理与字段级可见性**未证实**。来源 S10。
- **桌面小组件做法**：官方文案明确："我们交往了多少天？……**用小组件就能直接看到**，一起用的日历是附带的"——即小组件主打**纪念日／恋爱天数（D-day）**，共享日历是同一入口的附属能力。小组件是否能显示对方日程／状态**未证实**。来源 S10。
- **通知与互动玩法**：以聊天为核心（贴纸、动图、语音留言／对讲机、语音通话），照片／视频／日记／备忘按时间沉淀回忆。来源 S10。
- **隐私与权限处理**：官方列明"必需权限：无"；可选权限为麦克风、蓝牙、相机、相册、日历、Siri、Face ID。**用 Face ID 给应用加锁**是对"情侣内容不想被旁人看到"这一诉求的正面回应。来源 S10。
- **可借鉴点**：① 小组件首选"关系状态"而非"日程明细"，说明情侣类小组件的默认心智是**轻量、常驻、情感化**；② 应用锁（Face ID）把"私密内容"与"公开状态展示"分开处理；③ 手机系统日历双向同步是共享日程的低成本落地方式。
- **短板与限制**：产品重心在聊天与回忆，官方文案对"日程协同"只作附带描述，课表级共享不是它的能力方向。来源 S10。

### B.3 小恩爱（中国大陆）

- **产品名与平台**：小恩爱，App Store 记录开发者为 MZD、seller 为深圳市梦之多信息科技有限公司；bundleId `com.xiaoenai.app`，官网 `xiaoenai.com`；版本 9.6.19，最近更新 2024-10-29（近两年无版本更新），评分 4.78／62,785 条。来源 S11。
- **收费模式**：免费下载 + 连续订阅 VIP：**25 元/月、58 元/季、198 元/年**（官方订阅说明原文），到期前 24 小时自动扣费续订。来源 S11。
- **两人绑定方式**：**未证实**。但官方列有"虚拟结婚登记：一旦一对情侣成功登记，将无法单方面解除绑定"——说明产品内存在**关系绑定的强约束态**，且**单方面解绑被产品层面禁止**。来源 S11。
- **共享数据的同步模型**：官方功能清单中的共享项为：相册（"只属于你们的私密相册空间，共同管理"）、日记本（"可以共享的爱情笔记"）、蜜语（"私密聊天，只有情侣彼此可见"）、恩爱果园、我们的家（虚拟二人空间）、恋爱记账本。另有 **"二人地图：时刻守护彼此，定位精确"** 的定位共享。冲突处理与字段级可见性**未证实**。来源 S11。
- **桌面小组件做法**：**未证实**。来源 S11。
- **通知与互动玩法**：远程闹钟（一键叫起床）、聊天／特效调情助手、纪念日提醒、小姨妈（经期）提醒、"想你"千纸鹤、恋爱清单（200+ 件小事）、答题类与积分／低价商城、情侣社区话题活动、签到类现金奖励。整体偏**游戏化与电商化**。来源 S11。
- **隐私与权限处理**：官方未提供独立的隐私章节说明；商店内容分级为 17+，含"频繁／强烈的成人或性暗示题材"警示。定位类功能以"守护"为卖点，缺少"双向授权／可随时关闭"的表述。来源 S11。
- **可借鉴点**：① "共同管理"式共享容器（相册／日记）与"仅彼此可见"的私密通道并存，是情侣产品的典型双层结构；② 提醒类功能承担了大部分日常触达，说明该品类的留存靠**周期性提醒**而非日程查询。
- **短板与限制**：版本停在 2024-10（近两年未更新），活跃度存疑；**"无法单方面解除绑定"**对用户是明确的关系锁定风险；功能堆叠到商城、答题、现金激励，与"安静的日程工具"定位相冲突。

### B.4 心动日常（中国大陆）

- **产品名与平台**：心动日常，App Store 记录开发者 Chongqing Calendar Tech. Co., Ltd（重庆），bundleId `com.youloft.icloser`；iOS 版本 3.9.4，最近更新 2026-09-18，评分 4.72／148,442 条，内容分级 17+。来源 S12。
- **收费模式**：免费下载 + 连续包月订阅，官方列出多档：**25 元/月**；八折 20 元/月；六折 15 元/月；三天免费试用（25 元/月）；**首月折扣 8 元**，之后 25 元/月。另有"365 心动计划"打卡活动（连续 365 天互发"我爱你"可提现 1314 元，平台承担）。来源 S12。
- **两人绑定方式**：**未证实**。来源 S12。
- **共享数据的同步模型**：核心不是日程而是**位置与手机使用状态**："实时定位，轨迹记录"、"手机记录，自动报备：手机使用记录，离开到达自动提示"、"距离查看：实时定位回放轨迹"。共享内容还包括甜言蜜语聊天（"只你可见"）、心情日记、心动相册、健康记录（睡眠监督、生理期）。冲突处理**未证实**。来源 S12。
- **桌面小组件做法**：**未证实**。商店截图中出现 `桌面传图` 命名的素材，但官方描述未提小组件，不能据此断定存在小组件。来源 S12。
- **通知与互动玩法**：自动报备与到达／离开提示是主玩法；另有情侣小游戏、情侣空间装饰、萌宠喂养、冰箱贴留言、约会点子转盘、心动圈社区、打卡提现。来源 S12。
- **隐私与权限处理**：官方在"温馨提示"中自陈："查看轨迹会持续使用 GPS 定位服务，**切换至后台仍然会保持 GPS 连接**，相比其它操作会消耗更多电量""GPS 在后台持续运行会影响电池续航时间"。来源 S12。
- **可借鉴点**：① "对方现在在做什么"这一诉求的真实解法在市场上是**自动上报状态**，不是让用户手动更新——对应到课表场景就是"课程状态由系统推算，用户不需要动手"；② 官方主动披露后台定位的耗电代价，说明这类常驻状态同步必须公开电量与隐私成本。
- **短板与限制**：以持续定位与用机记录为核心，17+ 分级与"用机记录"类功能存在明显的隐私争议空间；后台定位耗电是硬约束；商店描述中**未出现日历／课表类能力**。来源 S12。

### B.5 Cupla（英国，情侣共享日历）

- **产品名与平台**：Cupla: Couples Shared Calendar，开发／发行商 Cupla Limited；iOS 评分 4.69／2,310 条，版本 2.59.1，最近更新 2026-10-01；支持语言含英语、法语、德语、韩语、俄语、西班牙语。来源 S13。
- **收费模式**：免费下载；**订阅档位与价格未证实**。来源 S13。
- **两人绑定方式**：**未证实**。来源 S13。
- **共享数据的同步模型**：官方描述为"完整的日程可见性"：可并排查看双方日程；**"把计划直接加进伴侣的日历"**；可与 Apple、Google、Outlook、工作排班表及家庭共享日历同步；**"用灵活的隐私控制选择要共享什么"**。官方另称有大学背书的调研数据（75% 用户称降低了关系中的压力，65% 称有助于共处时间，500,000+ 对情侣使用），属厂商自述，非独立第三方复核。冲突处理**未证实**。来源 S13。
- **桌面小组件做法**：官方功能列表明确包含 "**Widgets** to keep your life together front and center"（未描述具体尺寸与展示字段）。来源 S13。
- **通知与互动玩法**：共享待办与清单（家务、采购、出行，可把提醒指派给自己或伴侣）、许愿清单、纪念日与倒数、约会频率目标提醒、回忆（Memories）流。来源 S13。
- **隐私与权限处理**：以"灵活隐私控制 + 私密共享控制（Private sharing controls）"作为卖点，但**具体粒度（按事件／按字段／按日历）未证实**。来源 S13。
- **可借鉴点**：① **"把计划直接加进对方日历"**是"写到对方数据里"这一同步模型的直接证据，也是最贴近"帮对方排课／约时间"的交互；② 把待办与提醒按"指派给我／指派给伴侣"区分，是双人任务归属的轻量表达；③ 小组件在官方文案里被定位为"把共同生活放在最前面"，与 TimeTree 的"看日程"是两种不同的默认价值。
- **短板与限制**：评分条数（2,310）明显小于前几个产品，样本代表性有限；官方自述的用户量与影响数据未见独立来源复核。来源 S13。

### B.6 Lookus（中国大陆，自动行程同步类样本）

- **产品名与平台**：Lookus；App Store 中国区条目 trackId 6474428332，版本 3.26.2，评分 4.65／68,311 条（https://itunes.apple.com/search?term=%E5%BF%83%E5%8A%A8%E6%97%A5%E5%B8%B8&country=cn&entity=software&limit=3&lang=zh_cn 结果中的第 2 条，2026-10-20）。来源 S14。
- **产品定位**：官方文案把它写成"全自动行程同步功能，会在对方抵达或离开重要地点时自动更新状态，无需反复发消息确认"，即用**自动上报的状态流**回答"对方此刻在哪、在做什么"；与本样本组的定位共享类产品同源，但它把宣传重心放在"授权与边界"上。来源 S14。
- **收费模式**：官方商店文案含会员价目（金额随地区与活动变动，未取得独立价目页）。来源 S14。
- **两人绑定方式**：**未证实**（商店文案未描述邀请码／二维码流程）。来源 S14。
- **共享数据的同步模型**：以自动上报的状态流为核心（"日常作息状态、晚间是否已休息"这类**节律级**信息），官方明确把这类节律信息与精确定位区分开。冲突处理与字段级可见性**未证实**。来源 S14。
- **授权与隐私口径**：官方反复强调"均需双方在知情前提下分别授权方可启用，双向确认""尊重每一位用户的隐私边界""有关怀，更有边界感"。厂商主动用"边界"作卖点，说明用户对持续共享存在抵触。来源 S14。
- **桌面小组件做法**：**未证实**。来源 S14。
- **可借鉴点**：① 把"双向授权、双向确认"写成正面卖点，而不是藏在隐私条款里；② 用"节律级状态"而不是"精确定位"描述共享内容，信息敏感度更低而实用度仍然足够——与课表场景里"对方此刻在上什么课"是同一类信息；③ 宣传语直接回应"无需反复发消息确认"这一核心痛点。
- **短板与限制**：本次只取到官方商店文案与元数据，产品官网与帮助中心未取得条目，功能细节无法交叉验证。来源 S14。

### B.7 横向对比：同步模型与小组件做法

| 产品 | 共享容器模型 | 谁可见 | 写到谁的数据里 | 冲突处理 | 小组件主要内容 | 小组件可自定义性 |
| --- | --- | --- | --- | --- | --- | --- |
| TimeTree | 群组日历（成员制，可 2 人可多人） | 日历内事件／评论／图片／日历资料，对全体参与者可见；新成员加入即获得全部可见权 | 写进共享日历容器，非写入对方个人日历（官方未见"写入对方日历"表述） | 未证实 | 所选日历的事件（日期／日程） | 可选择显示哪些日历；可设"只显示我自己的事件"；iOS 不支持外部日历事件 |
| Between | 两人专属空间 + 一起用的日历 | 两人之间；聊天／照片／日记以"只有我们两个人"表述 | 以服务端保存的两人共享内容为主；日历可与设备系统日历互通 | 未证实 | 纪念日／交往天数（D-day），日历为附带 | 未证实 |
| 小恩爱 | 关系绑定 + 多个共享模块（相册／日记／蜜语／定位／记账） | 相册"共同管理"；蜜语"只有情侣彼此可见" | 未证实（未见写入对方个人数据的表述） | 未证实 | 未证实（官方未提小组件） | 未证实 |
| 心动日常 | 自动上报的状态流（定位、用机记录、到达／离开） + 情侣内容模块 | 双方之间（甜言蜜语"只你可见"） | 状态由客户端自动上报到服务端，再向对方展示 | 未证实 | 未证实 | 未证实 |
| Cupla | 双人共享日历 + 待办清单 | 双方；以"灵活的隐私控制"调节共享范围（粒度未证实） | **可把计划直接加进伴侣的日历** | 未证实 | 官方仅称有小组件，展示内容未证实 | 未证实 |
| Lookus | 自动上报的状态流（节律级状态，与精确定位区分） | 双方之间；官方强调"双方在知情前提下分别授权、双向确认"；字段级粒度未证实 | 状态由客户端自动上报到服务端，再向对方展示 | 未证实 | 未证实 | 未证实 |

**结论性观察**：

1. **主流同步模型是"共享容器"，不是"互相写对方的数据"。** 六个样本中只有 Cupla 的官方文案出现"把计划加进伴侣的日历"，其余都是把数据写进一个双方共同可见的容器。来源 S6、S7、S10、S13、S14。
2. **可见性控制是产品能力的一部分，且普遍较粗。** TimeTree 把可见范围写成条款并提供"退出即失去访问权"的边界；Cupla 声称有灵活隐私控制但粒度未公开；Lookus 把"双向授权、双向确认"写成宣传语但字段级粒度未证实；小恩爱／心动日常未见字段级可见性说明。来源 S7、S11、S12、S13、S14。
3. **小组件的默认内容分化明显**：时间型产品（TimeTree）展示日程事件，关系型产品（Between）展示纪念日天数。把"对方此刻的状态"放进小组件的做法，在本次调研的六个样本中**没有一个取得官方证据**（TimeTree 的"只显示我自己的事件"是相反的取向）。来源 S8、S10。
4. **六款产品均未公开冲突处理规则**，因此"两人同时改同一节课怎么合并"在市面上没有可抄的公开答案。来源 S6、S7、S10、S11、S12、S13、S14。

### B.8 专项：情侣场景下"共享课表／查看对方现在在上什么课"的市面做法与公开诉求

**市面做法（有来源的部分）**

- **用通用共享日历承载课表**。TimeTree 官方商店文案直接点名学校／课程场景（"忘记各种学校活动和任务"、"把学校的通知拍照存进应用"），并把情侣用法描述为"在日历里看到双方的空闲时段，再安排约会"。课程表在现有产品里通常被当作**普通事件**手工录入或从设备日历导入，而不是结构化的"课程"实体。来源 S1、S2、S8。
- **用系统日历双向同步**。Between 的可选权限包含"日历：修改和登记设备日历日程"。来源 S10。
- **用定位与用机状态代替"现在在干什么"**。心动日常官方把主功能写成"手机使用记录，离开到达自动提示""实时定位，轨迹记录"，即用**自动上报的状态流**回答"对方此刻在哪、在做什么"；同类的 Lookus 官方文案表述为"全自动行程同步功能，会在对方抵达或离开重要地点时自动更新状态，无需反复发消息确认"，并强调"均需双方在知情前提下分别授权方可启用，双向确认"。来源 S12、S14。
- **课表 App 侧**：本次未能找到任何有官方来源的、把"情侣课表共享"作为主功能的产品（Apple 中国区检索"情侣课表"返回的结果为共享日历、家庭日历、倒数日类应用）。该条为检索结论，不排除存在未检索到的产品。来源 S15。

**公开用户诉求（仅有官方文案层面的证据）**

- **要减少反复确认。** TimeTree 商店文案把痛点写成"总担心对方是否知道我的安排？把日程沟通集中到 TimeTree，就不用每次再确认一遍"；Lookus 写成"无需反复发消息确认"。来源 S1、S14。
- **要"知道对方的生活节奏"而非精确轨迹。** Lookus 官方描述"日常作息状态、晚间是否已休息"这类**节律级**信息，并把它与精确定位区分开。来源 S14。
- **要边界感。** Lookus 官方反复强调"双向授权""尊重每一位用户的隐私边界""有关怀，更有边界感"。来源 S14。
- **要低耗电的常驻状态。** 心动日常官方主动披露后台 GPS 持续运行会显著影响续航。来源 S12。

### B.9 风险提示（隐私、绑定关系解除、数据归属）

1. **隐私：状态共享会被用户读成监控。** 心动日常把"用机记录""离开到达自动提示"作为卖点，而 Lookus 把"双方分别授权、双向确认"写成宣传语，两者指向同一个张力：持续共享越自动，越需要显式的授权与撤回机制。课表类功能展示"对方此刻在上什么课"的信息敏感度低于定位，但仍应给出可关闭、可粒度化的开关。来源 S12、S14。
2. **绑定关系解除：市面上存在"不可单方解绑"的先例。** 小恩爱官方功能清单写明"虚拟结婚登记：一旦一对情侣成功登记，将无法单方面解除绑定"。这是明确的产品级锁定，对用户是不可逆风险。来源 S11。
3. **解绑后的访问权与数据保留需要明确规则。** TimeTree 的官方条款给出了一种可参考的写法：只要日历仍有参与者，日历信息就继续被保留使用；成员退出日历或注销账号后，其个人资料不再对其他参与者可见，并从日历信息中移除；撤回同意的路径是删除自己的数据并退出日历。来源 S7。
4. **数据归属：共享内容的"二次流转"不可控。** TimeTree 条款明确指出其他参与者可经 API 或备份把共享信息带到第三方服务，此时该参与者对这部分处理成为独立的控制者；新邀请的成员也自动获得全部共享信息的访问权。这意味着**"共享给一个人"实际等于"共享给这个容器当前及未来的所有成员"**。来源 S7。
5. **第三方 AI／广告使用共享数据的可能性。** TimeTree 条款说明可以用 AI 处理共享日历信息（如提醒、后续行动建议，含广告用途），但需用户明示同意，且不作为法律或类似重大影响的依据。来源 S7。
6. **厂商自述数据的可信度边界。** 用户量、降压力百分比等均为厂商自述（TimeTree"7500 万用户"、Cupla"50 万+ 情侣、大学背书调研"），未找到独立来源复核，引用时应标注为自述而非事实。来源 S1、S13。

### B.10 来源清单（访问日期均为 2026-10-20）

- S1. TimeTree 应用元数据与商店文案（App Store 接口，country=us，trackId 952578473，版本 15.32.0，评分 4.85／92,774）：`https://itunes.apple.com/lookup?id=952578473&country=us`
- S2. TimeTree 官网首页（共享日历、多日历、Premium 价格 4.49 USD/月、44.99 USD/年）：`https://timetreeapp.com/intl/en/`
- S3. TimeTree 日本区商店文案（评分 4.61／1,060,784，版本 15.32.0）：`https://itunes.apple.com/search?term=time+tree+shared+calendar&country=jp&entity=software&limit=3`
- S4. TimeTree Premium 页面（含 Free 与 Premium 功能对比表）：`https://timetreeapp.com/intl/en/premium`
- S5. TimeTree 帮助《Start TimeTree》（管理员／成员邀请 PDF 指引）：`https://support.timetreeapp.com/hc/en-us/articles/900004512886-Start-TimeTree`
- S6. TimeTree 帮助《How to use shared calendar (app)》（成员列表、邀请、专有资料、日历通知设置等入口）：`https://support.timetreeapp.com/hc/en-us/articles/900004492623-How-to-use-shared-calendar-app`
- S7. TimeTree《Shared Calendar Guidelines》（共享信息范围、其他参与者可做的操作、AI 处理、保留期与撤回同意）：`https://timetreeapp.com/intl/en/terms/shared-calendar-guidelines`
- S8. TimeTree 帮助《How to Display the Calendar on iOS Lock Screen and Home Screen (Widget)》（显示日历选择、"只显示我自己的事件"、外部日历事件不显示）：`https://support.timetreeapp.com/hc/en-us/articles/900003341586`
- S9. TimeTree 帮助中心 widget 搜索结果页（含《How to use Widgets (Android)》条目与"日历不显示"排障条目摘要）：`https://support.timetreeapp.com/hc/en-us/search?query=widget`
- S10. Between 应用元数据与商店文案（韩国区，trackId 458035189，bundleId `kr.co.vcnc.couple`，版本 5.14.03，评分 4.72／269,112，权限清单）：`https://itunes.apple.com/search?term=between+couple&country=kr&entity=software&limit=5`
- S11. 小恩爱应用元数据与商店文案（中国区，trackId 524690790，bundleId `com.xiaoenai.app`，版本 9.6.19，评分 4.78／62,785，VIP 价格与"虚拟结婚登记"说明）：`https://itunes.apple.com/search?term=xiao+en+ai&country=cn&entity=software&limit=10&lang=zh_cn`
- S12. 心动日常应用元数据与商店文案（中国区，trackId 1534020402，bundleId `com.youloft.icloser`，版本 3.9.4，评分 4.72／148,442，订阅档位与后台定位提示）：`https://itunes.apple.com/search?term=%E5%BF%83%E5%8A%A8%E6%97%A5%E5%B8%B8&country=cn&entity=software&limit=3&lang=zh_cn`
- S13. Cupla 应用元数据与商店文案（美国区，trackId 1557764033，版本 2.59.1，评分 4.69／2,310，"把计划加进伴侣日历"与 Widgets）：`https://itunes.apple.com/search?term=cupla+couple&country=us&entity=software&limit=3`
- S14. Lookus 应用元数据与商店文案（中国区，trackId 6474428332，版本 3.26.2，评分 4.65／68,311，自动行程同步、双向授权、会员价目）：同 S12 检索结果中的第 2 条
- S15. Apple 中国区检索"情侣课表"结果（返回 Timely 共享日历、家庭日历、倒数日、恋爱日历等，非情侣课表产品）：`https://itunes.apple.com/search?term=%E6%83%85%E4%BE%A3%E8%AF%BE%E8%A1%A8&country=cn&entity=software&limit=8&lang=zh_cn`

### B.11 未证实事项汇总（情侣协同）

| 事项 | 涉及产品 | 状态 |
| --- | --- | --- |
| 两人绑定／配对的具体流程（邀请码、二维码、账号） | Between、小恩爱、心动日常、Cupla、Lookus | 未证实 |
| 共享数据的冲突处理规则（并发编辑、最后写入优先等） | 全部 6 个 | 未证实（均无官方说明） |
| 小组件展示对方状态／对方日程 | Between、小恩爱、心动日常、Cupla、Lookus | 未证实 |
| 是否存在桌面小组件 | 小恩爱、心动日常、Lookus | 未证实（官方文案未提及） |
| 订阅价格档位 | Between、Cupla | 未证实（官方商店文案未列价目） |
| Lookus 的会员档位与计费方式 | Lookus | 未证实（仅见厂商自述价目，未取得官方价目页） |
| 按事件／按字段／按日历的隐私控制粒度 | Cupla、Lookus | 未证实（仅称"灵活"／"双向授权"） |
| TimeTree 免费版与 Premium 的非价格权益边界 | TimeTree | 已证实（官网对比表），价格随地区变动 |
| App Store 用户评论原文与社区讨论 | 全部 | 未取得（环境限制） |
| 以"情侣课表／对方当前课程"为主功能的产品是否存在 | — | 未证实 |
| 各产品的用户量、留存等第三方数据 | 全部 | 未取得（仅厂商自述） |
| Lookus 官网与帮助中心条目 | Lookus | 未取得（本次只取到官方商店文案与元数据） |

---

## C 开源实现与技术方案

本文只做事实调研：每条结论给出依据与来源 URL；配额、许可证、字段名、权限名一律以官方文档或官方发布物为准。

### C.1 开源课表／日程项目参考

**结论**

- **ClassIsland**（C#／.NET 8／Avalonia，跨平台，非 Flutter）是模块划分最值得参照的同类项目：功能域拆为「课表信息显示／课表编辑与管理／自定义（组件·插件·主题）／自动化／天气」；课表编辑侧已具备多周轮换、单日或跨天临时换课、预定课表，以及时间表与科目分离维护。
- **许可证双轨**：应用本体 **GPL-3.0**；`ClassIsland.Core`、`ClassIsland.PluginSdk`、`ClassIsland.Shared`、`ClassIsland.Shared.Ipc` 为 **LGPL-3.0**（便于插件闭源）。同组织集控服务端 `ClassIsland/ManagementServer` 为 **AGPL-3.0**。落点：本应用采用 GPL-3.0（规划书 7.1），因此本体、LGPL-3.0 组件与 GPL 系列的代码可并入；仅 AGPL-3.0 的 ManagementServer 不可并入（规划书形态也不需要它）。
- **数据模型术语**（官方 README 与界面命名）：档案（Profile）、时间表、科目、课表（ClassPlan）、预定课表、跨天换课、组件、自动化。可视为「课程实体／节次时间表／学期周次」三者解耦的证据。
- **导入方案**：官方支持从 Excel 表格、CSES（`SmartTeachCN/CSES`）及其它软件导入，并可导出 Excel。
- **WakeUp 生态**：未检索到 WakeUp 官方 App 本体的开源仓库。按 GitHub 仓库搜索 `wakeup 课表`，结果均为围绕 WakeUp 的**导入适配层与第三方实现**，例如 `koishi-plugin-course-schedule`（同时支持 WakeUp／星链／拾光，ICS/JSON 多格式导入）、`PyWakeup`、`nju2wakeup`、`NYIST-CIPS/CourseTable`（MIT）、`ershiyidian/WakeUp_SHU`。WakeUp 的价值在**导入格式与高校适配生态**，不在架构参考。
- **Flutter 课表项目许可分布**（GitHub 官方仓库元数据）：`BenderBlog/traintime_pda` MPL-2.0、`The-Brotherhood-of-SCU/Bugaoshan` AGPL-3.0、`WheretoSleepinNJU/NJU-Class-Shedule-Flutter` Apache-2.0、`gnahz77/SchedU` MIT（自称支持 JSON/AI 导入）、`Mutx163/mikcb`（轻屿课表）GPL-3.0-or-later、`JS-CAUTION/csust-course-schedule` MIT。宽松许可与强著佐权大体各半，「参考哪个项目」直接决定许可证与合规成本。
- **`Mutx163/mikcb`（轻屿课表）与本项目目标形态最接近**（Flutter + Android only、minSdk 26／targetSdk 36、Flutter 3.44.8），已实现 ics 导入、桌面小组件矩阵、双人课表合并比对，并经原生集成 Notification、Ongoing Promoted Activity、Foreground Service、AlarmClock。其「Flutter 壳 + 原生能力」的职责切分有直接参考价值。

**来源**

- ClassIsland README（模块与功能、导入方案、许可证双轨）：https://raw.githubusercontent.com/ClassIsland/ClassIsland/master/README.md
- ClassIsland 组织仓库元数据（应用本体 GPL-3.0、ManagementServer AGPL-3.0）：https://api.github.com/orgs/ClassIsland/repos?per_page=100
- 轻屿课表 README（技术架构、格式导入、双人课表、许可证）：https://raw.githubusercontent.com/Mutx163/mikcb/main/README.md
- 轻屿课表第三方许可清单：https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/THIRD_PARTY_LICENSES.md
- GitHub 仓库检索（WakeUp 相关、Flutter 课表项目及许可证字段）：https://api.github.com/search/repositories?q=wakeup+%E8%AF%BE%E8%A1%A8 、https://api.github.com/search/repositories?q=%E8%AF%BE%E8%A1%A8+language:dart

**未证实**

- WakeUp 官方 App 是否开源：未证实（公开检索未发现官方本体仓库，不等于不存在）。
- 上述项目的字段级数据模型：未逐仓库核对，本文只采信各自 README 与仓库元数据的表述。

### C.2 Android 桌面小组件在 Flutter 下的可行方案

**结论**

- **Flutter 不能直接渲染原生桌面小组件**。`home_widget`（0.10.0，BSD-3-Clause，Android+iOS）官方表述：插件**不允许用 Flutter 编写小组件**，仍需原生代码实现；或用 `home_widget_generator` 在 Dart 中描述一次、由 `home_widget_cli` 生成原生源码。插件提供的是数据下发、读取与刷新通知的统一接口。
- **接口形态**（官方 README 示例）：`HomeWidget.saveWidgetData<String>('id', data)` 下发数据，`HomeWidget.updateWidget(name: 'XxxProvider')` 触发刷新；静态方法使其可在后台执行体中使用。
- **后台刷新路径**：官方「Background Updates」文档建议配合后台执行插件实现，示例用 `flutter_workmanager`，并提示 iOS 侧需注册插件。该文档**未定义**刷新频率上限，频率限制由各平台系统机制决定。
- **原生侧落地方式**：小组件 = `<receiver>` 声明 `android.appwidget.action.APPWIDGET_UPDATE` + `android:appwidget.provider` 元数据指向 `AppWidgetProviderInfo` XML。实践参考：轻屿课表在同一 APK 内声明 9 个 `*WidgetProvider`（今日课程多规格、统计、考试倒计时等），并用额外的 `HomeWidgetRefreshReceiver` 监听 `APPWIDGET_UPDATE` 及 `BOOT_COMPLETED`、`MY_PACKAGE_REPLACED`、`TIME_SET`、`TIMEZONE_CHANGED` 重排刷新——这是「开机、改时间、改时区后重新对齐」的可行做法。
- **深色与主题适配**：官方依据未取证。可确认的事实是：该工程让小组件共用 `android:theme="@style/QingyuWidgetTheme"`，主题由应用侧 style 承载。

**来源**

- home_widget 包页（版本、许可证、平台、文档入口）：https://pub.dev/packages/home_widget
- home_widget 官方文档首页（不支持 Flutter 直写小组件、生成器与 CLI 路线）：https://docs.page/ABausG/home_widget
- home_widget 官方「Background Updates」文档：https://docs.page/ABausG/home_widget/features/background-updates
- home_widget 仓库元数据：https://api.github.com/search/repositories?q=home_widget+flutter
- 小组件原生声明与刷新广播实践：https://raw.githubusercontent.com/Mutx163/mikcb/main/android/app/src/main/AndroidManifest.xml

**未证实（含取证失败原因）**

- Android 官方「App Widgets 概览」及小组件更新周期／后台限制页面取证失败：`https://developer.android.com/develop/ui/views/appwidgets/overview` 多次返回 `fetch failed`（该域名本次整体不可达）。**小组件更新周期、Doze／后台限制下的刷新行为**未证实。
- Jetpack **Glance** 官方文档页 `https://developer.android.com/develop/ui/views/compose/glance` 同上，未证实；其作为原生小组件实现路线、以及与 `home_widget` 数据通道的配合方式未证实。
- 小组件深色模式／主题色的官方适配规范未证实。

### C.3 厂商系统集成现状

**结论**

- **HyperOS「焦点通知／超级岛」的开发者接入文档未证实**：小米官方站点 `hyperos.mi.com` 是面向消费者的产品页（只营销描述「任务上岛」、超级小爱等），未见开发者 API、申请流程或审核要求。可核实的相邻事实是 **Android 系统自 API 36 起提供 promoted ongoing notifications（提升型常驻通知）**，API 36.1 补齐权限与请求接口；两者是否同一实现路径，官方未证实。
- **系统 API 等级事实**（Google 随 SDK 平台包发布的官方元数据，逐项核对）：

| 符号 | 起始 API |
| --- | --- |
| `NotificationManager.canPostPromotedNotifications()` | 36 |
| `Notification.FLAG_PROMOTED_ONGOING` | 36 |
| `android.permission.POST_PROMOTED_NOTIFICATIONS` | 36.1 |
| `Notification.Builder.setRequestPromotedOngoing(boolean)` | 36.1 |
| `Notification.EXTRA_REQUEST_PROMOTED_ONGOING` | 36.1 |
| `NotificationManager.isRequestPromotedOngoing()` | 36.1 |
| `android.permission.POST_NOTIFICATIONS` | 33 |

  注意：`POST_PROMOTED_NOTIFICATIONS` **不出现在 API 36 平台元数据中，只出现在 API 36.1（android-37.0）元数据中**；即声明它需要 compileSdk 达到 36.1 一档，否则只是被忽略的未知权限。
- **前台服务**：`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`（API 34）、`Service.FOREGROUND_SERVICE_TYPE_SPECIAL_USE`（API 34）、`Service.PROPERTY_SPECIAL_USE_FGS_SUBTYPE`（API 34，用于说明 specialUse 的具体用途）。
- **开源项目的常见做法**（轻屿课表，GPL-3.0）：声明 `POST_PROMOTED_NOTIFICATIONS`、`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`、`RECEIVE_BOOT_COMPLETED`、`SCHEDULE_EXACT_ALARM`、`ACCESS_NOTIFICATION_POLICY`、`MODIFY_AUDIO_SETTINGS`；两个 `specialUse` 前台服务都填写了 `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 用途说明；README 还引导用户手动授予「通知与焦点通知权限、后台无限制与自启动、免打扰访问权限」。即：厂商侧的后台保活不是纯代码问题，需要用户侧授权配合。
- **通知渠道**：官方渠道行为依据未取证，可证实的仅有 `POST_NOTIFICATIONS`（API 33）一项。

**来源**

- Google 官方 SDK 平台元数据（本地已安装 SDK）：`<Android SDK>/platforms/android-36/data/api-versions.xml`、`<Android SDK>/platforms/android-37.0/data/api-versions.xml`
- 小米 HyperOS 官网（仅消费者内容，无开发者文档）：https://hyperos.mi.com/
- 轻屿课表 AndroidManifest（权限、前台服务与用途声明）：https://raw.githubusercontent.com/Mutx163/mikcb/main/android/app/src/main/AndroidManifest.xml
- 轻屿课表 README（用户侧授权要求）：https://raw.githubusercontent.com/Mutx163/mikcb/main/README.md

**未证实（含取证失败原因）**

- HyperOS 焦点通知／超级岛的开发者接入 API、申请与审核流程：未证实（官方站点无开发者文档）。
- 通知渠道行为、前台服务后台限制、Doze／省电白名单等 Android 官方条目：取证失败（`developer.android.com` 本次整体不可达）。
- `POST_PROMOTED_NOTIFICATIONS` 的运行时授权表现及各厂商适配差异：未证实。
- promoted ongoing notifications 与 HyperOS「超级岛／焦点通知」是否为同一实现路径：未证实。

### C.4 天气与定位数据源官方事实

#### C.4.1 Open-Meteo

**免费额度与限流**（官方定价页原文）

| 项 | 免费/开放层 |
| --- | --- |
| 商用 | ❌ 不允许 |
| 每分钟 | 600 calls / min |
| 每小时 | 5,000 calls / hour |
| 每天 | 10,000 calls / day |
| 每月 | 300,000 calls / month |

- 付费档：Standard 1M calls/月、Professional 5M calls/月、Enterprise >50M calls/月；付费档走 `customer-api.open-meteo.com` 并以 `&apikey=` 传参，语法与免费档一致，99.9% 可用性目标；**免费层无可用性保证**。
- **调用计量规则**：通常 1 个 HTTP 请求 = 1 次调用；但单次请求变量数 >10 或时间跨度 >2 周会被折算，官方示例：2 周 × 15 变量 = 1.5 次调用，4 周 = 3.0 次调用。

**许可证与署名**（官方许可页原文）

- API 数据为 **CC BY 4.0**：需署名、提供许可链接、标注是否修改；且**必须在任何展示 Open-Meteo 数据的位置旁给出链接**，官方示例 `<a href="https://open-meteo.com/">Weather data by Open-Meteo.com</a>`。
- 服务端源码为 **AGPLv3**；上游数据源含 DWD、ECMWF、NOAA、CMA 等（多为 CC-BY 系）。

**常用字段**（对官方 `v1/forecast` 端点实测返回，字段名逐字核对）

- `current`：`temperature_2m`(°C)、`relative_humidity_2m`(%)、`apparent_temperature`(°C)、`weather_code`(wmo code)、`wind_speed_10m`(km/h)，另有 `interval`(秒)。
- `hourly`：`temperature_2m`、`precipitation_probability`(%)、`weather_code`。
- `daily`：`weather_code`、`temperature_2m_max`、`temperature_2m_min`、`precipitation_probability_max`。
- 顶层：`latitude`、`longitude`、`timezone`、`utc_offset_seconds`、`elevation`；各分组另返回 `current_units`／`hourly_units`／`daily_units` 标明单位。
- `forecast_days` 默认 7、最大 16；Open-Meteo 另有 Geocoding API（免费层同样包含）。

#### C.4.2 高德开放平台

- **天气查询 Web API**：`GET https://restapi.amap.com/v3/weather/weatherInfo`；参数 `key`（必填，Web 服务类型 KEY）、`city`（必填，**adcode**）、`extensions`（可选，`base`=实况／`all`=预报）。文档最后更新 2025-03-18。
- **Android 定位 SDK**：官方说明 Flutter 3.0.0 已兼容 Android 定位 SDK ≥5.6.0，并提供 Flutter 插件；定位模式 `AMapLocationMode.Hight_Accuracy`／`Battery_Saving`／`Device_Sensors`，`setInterval` 最小间隔 1000ms；**逆地理编码随定位结果返回**：`getAddress`、`getCountry`、`getProvince`、`getCity`、`getDistrict`、`getStreet`、`getStreetNum`、`getCityCode`、`getAdCode`、`getAOIName`。合规前置：定位 5.6.0 起调用任何接口前必须先调用 `updatePrivacyShow`、`updatePrivacyAgree`。
- **Key 申请流程**：Web 服务 API 为「控制台 → 应用管理 → 创建新应用 → 添加 Key → 服务平台选『Web 服务』」；Android 平台 SDK 为「创建应用 → 添加新 Key → 绑定服务选『Android平台SDK』→ 填发布版安全码 SHA1、调试版 SHA1、Package」。**1 个 KEY 只能用于一个应用**（多渠道安装包属于多个应用），多应用共用会调用失败；debug 与 release 的 SHA1 不同，发布 APK 需按发布 keystore 重新配置 Key。
- **免费配额**：官方「流量限制说明」页**未给出具体数字**，只指向「定价-基础服务配额说明」与控制台「流量分析-配额管理」。具体数值以控制台为准，本文不记录未经文档证实的数字。
- **许可**：定位 SDK 官方「开发者使用注意事项」明确——法人或非法人组织使用平台服务应事先购买技术服务许可；未购买时平台提供的 KEY 与服务配额**仅供短期、少量的测试目的**；面向公众提供、上架分发、收费或投放广告、长期或大量调用等构成未许可使用。
- **Key 不入库**：官方只提示「妥善保管你的 Key」，未发现专门的仓库安全规范（**未证实存在该规范**）。可核实的结构性事实是：Android 平台 Key 必须绑定 SHA1 与 Package，因而必然随 APK 分发，属客户端凭据；Web 服务 Key 在控制台按平台单独授予，属服务端凭据。据此，工程上的合理做法是客户端 Key 走构建期注入（占位符 + 不入库的本地配置／CI 密钥），仓库只提交占位，Web 服务 Key 只放自有服务端、不下发客户端。（此为工程判断，非官方明文要求。）

**来源**

- Open-Meteo 定价（免费档限流、付费档、调用计量）：https://open-meteo.com/en/pricing
- Open-Meteo 许可（CC BY 4.0、署名示例、AGPLv3 源码）：https://open-meteo.com/en/licence
- Open-Meteo 天气 API 文档（变量清单、forecast_days）：https://open-meteo.com/en/docs
- Open-Meteo 端点实测（字段名与单位，2026-10-20 调用）：https://api.open-meteo.com/v1/forecast?latitude=39.9042&longitude=116.4074&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FShanghai&forecast_days=2
- 高德天气查询文档：https://lbs.amap.com/api/webservice/guide/api/weatherinfo
- 高德流量限制说明（配额入口）：https://lbs.amap.com/api/webservice/guide/tools/flowlevel
- 高德 Web 服务 Key 创建流程：https://lbs.amap.com/api/webservice/create-project-and-key
- 高德 Android 定位 SDK 概述（Flutter 兼容性、字段、隐私合规、技术服务许可）：https://lbs.amap.com/api/android-location-sdk/locationsummary
- 高德 Android 定位 SDK 获取 Key（SHA1/Package 绑定、1 Key 1 应用）：https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key

**未证实**

- 高德 Web 服务 API 的具体免费配额数值：官方页面未给出，需在控制台查看（未证实具体数字）。
- 高德 SDK 的开源许可证文本：官方文档只谈技术服务许可与使用限制，未提供 SDK 开源许可声明，SDK 为闭源二进制（未证实其许可证类型）。
- 「Key 不得入库」的官方规范：未证实存在高德官方仓库安全规范页。
- Open-Meteo 免费层是否对单 IP 并发连接数另有限制：未证实。

### C.5 课表提醒与闹钟

**结论**

准点提醒有两条**互相独立**的路径，取舍点不同。

**A. 应用内自建闹钟（AlarmManager）**

| 符号 | 起始 API |
| --- | --- |
| `android.permission.SCHEDULE_EXACT_ALARM` | 31 |
| `android.permission.USE_EXACT_ALARM` | 33 |
| `android.permission.SET_ALARM` | 9 |
| `AlarmManager.canScheduleExactAlarms()` | 31 |
| `AlarmManager.setAlarmClock(AlarmManager.AlarmClockInfo, PendingIntent)` | 21 |
| `AlarmManager.setExactAndAllowWhileIdle(int, long, PendingIntent)` | 23 |
| `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` | 31 |
| `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` | 31 |

- 存在两个不同的精确闹钟权限：`SCHEDULE_EXACT_ALARM`（API 31 引入）与 `USE_EXACT_ALARM`（API 33 引入）；`canScheduleExactAlarms()`（API 31）用于运行时判断当前是否获准。两者的适用场景差异与取舍规则属官方指南内容，本次未取证。
- 「精确权限被拒后如何降级」「Android 14 起 `SCHEDULE_EXACT_ALARM` 的默认授予策略」以及 `USE_EXACT_ALARM` 的适用范围与上架审核要求：**取证失败**（见下）。

**B. 写入系统闹钟（AlarmClock）**

- `android.provider.AlarmClock` 类自 API 9 起存在；`ACTION_SET_ALARM` 无 since 标注（自 API 1 起），`ACTION_SHOW_ALARMS` 自 API 19，`ACTION_DISMISS_ALARM` 自 API 23；`AlarmClock.EXTRA_SKIP_UI` 自 API 11（用于跳过系统确认界面）。
- 实践证据（轻屿课表）：以 Intent action `android.intent.action.SET_ALARM` 与 `android.intent.action.SHOW_ALARMS` 声明 `<queries>` 以满足 Android 11+ 包可见性要求；并声明 `com.android.alarm.permission.SET_ALARM` 作为静默写入的发送方权限（该权限不属于 `android.permission` 命名空间，需逐字照写）。
- 限制：系统闹钟写入的确认界面能否跳过、跳过后的用户可见性风险，以及各厂商时钟应用对 `EXTRA_SKIP_UI` 的支持差异：**未证实**。

**C. 课中／常驻提醒**

- 前台服务 `specialUse`（`FOREGROUND_SERVICE_SPECIAL_USE`、`FOREGROUND_SERVICE_TYPE_SPECIAL_USE`、`PROPERTY_SPECIAL_USE_FGS_SUBTYPE`，均 API 34 起）是「课进行中持续提醒」的可行承载；通知需 `POST_NOTIFICATIONS`（API 33）。
- 开机与时间变更后必须重排：`RECEIVE_BOOT_COMPLETED` + `TIME_SET`／`TIMEZONE_CHANGED` 广播（实践证据同上）。

**来源**

- Google 官方 SDK 平台元数据（权限与 API 等级，本地 SDK）：`<Android SDK>/platforms/android-36/data/api-versions.xml`、`<Android SDK>/platforms/android-37.0/data/api-versions.xml`
- 系统闹钟写入的权限、包可见性与重排广播实践：https://raw.githubusercontent.com/Mutx163/mikcb/main/android/app/src/main/AndroidManifest.xml

**未证实（含取证失败原因）**

- 官方「Schedule alarms」指南（`https://developer.android.com/develop/background-work/services/alarms/schedule`）与权限参考页 `https://developer.android.com/reference/android/Manifest.permission#SCHEDULE_EXACT_ALARM` 取证失败：均返回 `fetch failed`。因此**精确闹钟的降级建议、Android 14 起默认授予策略、`USE_EXACT_ALARM` 的适用条件与 Google Play 政策要求**均未证实。
- `EXTRA_SKIP_UI` 在各厂商时钟应用中的实际支持情况：未证实。

### C.6 选型相关事实要点

以下只列事实依据与取舍点：

1. **许可证是最先要定的约束**：可参照的同类项目许可两极分化（MIT／Apache-2.0 与 GPL-3.0／AGPL-3.0 大体各半），选哪一极直接决定哪些代码可以并入。本应用采用 **GPL-3.0**（规划书 7.1）：Apache-2.0、MIT、BSD、MPL-2.0、LGPL-3.0、GPL-3.0 系列的代码与依赖均可并入；需规避 AGPL-3.0 组件、仅 GPL-2.0 组件、闭源组件与含「禁止商用」条款的组件。`home_widget`（BSD-3-Clause）与 Open-Meteo 客户端调用本身不构成许可障碍。
2. **小组件必须预留原生实现工作量**：`home_widget` 明确不支持用 Flutter 直接写小组件，因此小组件是「Flutter 数据层 + 原生 RemoteViews/AppWidgetProvider」的双份实现，且刷新要显式处理开机、改时间、改时区；相关官方刷新周期与后台限制本次未能取证。
3. **「对方现在在上什么课」需要跨端数据**：该能力依赖服务端下发对方课表，客户端侧只能决定展示与缓存策略；组件刷新时机与网络请求需要同一条数据通道（`home_widget` 的数据下发接口 + 后台执行插件）。
4. **天气按商用／非商用分叉**：Open-Meteo 免费档明确不允许商用，且限 600/分、5,000/时、10,000/日、300,000/月；非商用开源项目可落在免费档，一旦涉及商用即需付费档（Standard 1M/月起）。署名是硬义务：**展示 Open-Meteo 数据的每一处都要有指向 open-meteo.com 的链接**（CC BY 4.0）。
5. **定位与天气分工要顺着高德的接口形状走**：高德天气 API 的必填参数是 `adcode`，而 adcode 由定位 SDK 的逆地理编码结果 `getAdCode` 直接给出；因此「定位 SDK 取点 → 拿 adcode／经纬度 → 天气取值」是一条顺接口的链路。若改用 Open-Meteo，则经纬度足够，adcode 不是必需，但地理编码需另走 Open-Meteo Geocoding API 或高德逆地理编码。
6. **高德的授权风险要提前确认**：官方明确未购买技术服务许可时，KEY 与配额仅供短期少量测试；上架分发、面向公众提供、收费或广告、长期大量调用都构成未许可使用。这是上线前的合规前置条件，不是技术问题。
7. **Key 的存放位置由平台决定**：Android 平台 Key 必须绑定 SHA1 与 Package、必然随 APK 分发（客户端凭据），只能在构建期注入、仓库留占位；Web 服务 Key 属服务端凭据，只应放在自有服务端，不下发客户端。这样也顺带满足「key 不入库」。
8. **提醒有两条路，成本与确定性不同**：自建精确闹钟要处理 `SCHEDULE_EXACT_ALARM`／`USE_EXACT_ALARM` 两个权限与运行时判断（`canScheduleExactAlarms()`，API 31+）；写入系统闹钟则依赖 `EXTRA_SKIP_UI` 与厂商时钟应用的配合，确定性更弱但无需自建调度。
9. **前台服务与厂商保活是「代码 + 用户授权」两件事**：`specialUse` 前台服务（API 34+）能把「课进行中」做成长驻通知；与超级岛类呈现相关的系统能力目前只有 promoted ongoing notifications（API 36 起，`POST_PROMOTED_NOTIFICATIONS` 权限在 API 36.1），且需要用户手动开启后台无限制／自启动——开源项目的普遍做法是把这些写成设置页的引导项。

### C.7 未证实清单（开源与技术方案）

- WakeUp 官方 App 是否开源；上述项目的字段级数据模型（未逐仓库核对）。
- 小组件更新周期、Doze／后台限制下的刷新行为（`developer.android.com` 整体不可达）；Jetpack Glance 官方文档与其与 `home_widget` 的配合方式；小组件深色模式的官方适配规范。
- HyperOS 焦点通知／超级岛的开发者接入 API、申请与审核流程；通知渠道行为、前台服务后台限制、Doze／省电白名单；`POST_PROMOTED_NOTIFICATIONS` 的运行时授权表现与厂商差异；promoted ongoing notifications 与超级岛是否同一实现路径。
- 高德 Web 服务 API 的具体免费配额数值；高德 SDK 的开源许可证类型；「Key 不得入库」的官方规范；Open-Meteo 免费层是否对单 IP 并发另有限制。
- 精确闹钟的降级建议、Android 14 起 `SCHEDULE_EXACT_ALARM` 默认授予策略、`USE_EXACT_ALARM` 的适用条件与 Google Play 政策要求；`EXTRA_SKIP_UI` 在各厂商时钟应用中的实际支持。

---

## D 未证实事项总表

下表把 A、B、C 三部分中的「未证实／未取得」事项集中列出，并标注在 [product-plan.md](product-plan.md) 中的**处理方式**——要么给出实际存在的正文条目编号，要么明确写「规划书不引用」（即本文档中不存在相关陈述，也不作相反断言）。这样可核对两条纪律：未证实项不当事实陈述；反向核查时也能确认规划书里没有出现任何「已排除／假定不存在」式的推导。

收录范围：A.11、B.11、C.7 三个未证实清单的全部条目（含按产品分组的同类项，不逐产品拆行）。表中「规划书不引用」只表示该事项不被引用为事实，不表示该事项不存在。

| # | 未证实事项 | 所属部分 | 在规划书中的处理方式 |
| --- | --- | --- | --- |
| 1 | 课程格子当前是否运营、功能形态 | A | 规划书不引用（A.5 保留取证过程与排除记录） |
| 2 | 厂商原生课表（小米／华为／OPPO／vivo）全部功能字段与岛类适配 | A | 规划书不引用；仅 8.1 R6 与 8.2 Q1／Q2 处理「厂商系统集成能力」这一同源问题 |
| 3 | 星链课表「情侣课表 + 多人比对」的实现细节 | A | 仅作为「共享已有先例」的结论（2.1），实现细节不引用 |
| 4 | 星链课表官网自述的 2000+ 高校／10 万+ 用户／App Store 4.9 分（454 个评分） | A | 规划书不引用；与 App Store 接口数据的差异记录在 A.4 |
| 5 | 星链课表官网「适配小米超级岛」 | A | 记为厂商自述；系统侧能力按 C.3 处理（4.8、8.1 R6、8.2 Q1／Q2） |
| 6 | 各竞品的节次模板、单双周、天气、内购价格、多人协同等字段 | A | 规划书不引用；设计启示只引用已证实条目（2.5） |
| 7 | 情侣样本的两人绑定流程 | B | 规划书不引用；绑定流程按 5.4.4／5.4.5 自行定义 |
| 8 | 情侣样本的冲突处理规则 | B | 结论是「无公开规则」（2.2）；规则按 5.6 自行定义 |
| 9 | 情侣样本把「对方状态」放进小组件 | B | 结论是「无官方证据」（2.2、8.2 Q10） |
| 10 | 小恩爱／心动日常／Lookus 是否有桌面小组件 | B | 规划书不引用；F2 的小组件内容按 3.2 自行定义 |
| 11 | Cupla 的隐私控制粒度、Lookus 的字段级可见性粒度、用户量自述数据 | B | 规划书不引用；可见性粒度按 5.3 规则 2 自行定义为三档 |
| 12 | 是否存在以「情侣课表／对方当前课程」为主功能的产品 | B | 结论是未证实（2.1 只引用星链课表的官方入口级证据） |
| 13 | HyperOS 焦点通知／超级岛开发者接入能力 | C | 写成待验证适配目标与风险（4.8、8.1 R6、8.2 Q1／Q2） |
| 14 | promoted ongoing notifications 与超级岛是否同一路径 | C | 8.2 Q2 |
| 15 | 小组件刷新周期上限与 Doze 下行为、Glance 路线、深色模式官方规范 | C | 8.1 R5、8.2 Q3／Q4 |
| 16 | 高德 Web 服务免费配额具体数值 | C | 8.2 Q7 |
| 17 | 高德 SDK 许可证类型 | C | 7.1 只写「闭源二进制、未取得开源许可声明、不列入可复用代码来源」；7.4 按结构性事实（Key 绑定 SHA1+包名）写密钥管理 |
| 18 | 精确闹钟降级建议、`USE_EXACT_ALARM` 适用条件与商店政策 | C | 4.8 只写已核实权限与 API 等级；降级与政策见 8.2 Q5 |
| 19 | `EXTRA_SKIP_UI` 在厂商时钟应用的支持差异 | C | 8.2 Q6 |
| 20 | Open-Meteo 免费层单 IP 并发是否另有限制 | C | 8.1 R8 按已知限流与缓存去重应对 |
| 21 | 通知渠道行为、前台服务后台限制、Doze／省电白名单等官方条目 | C | 8.2 Q12（其中小组件刷新周期另见 8.1 R5 与 8.2 Q3） |
| 22 | Lookus 的官网与帮助中心条目 | B | 规划书不引用（本次只取到官方商店文案与元数据）；2.3 只引用其授权与节律级状态的公开表述 |
| 23 | 订阅价格档位（Between、Cupla） | B | 规划书不引用；本应用无付费形态（1.3、3.5），价格信息对规划无输入价值 |
| 24 | App Store 用户评论原文与社区讨论（全部样本） | B | 规划书不引用（取证环境限制）；2.3 只用官方文案层面的证据，不以评论代替用户诉求 |
| 25 | 各产品的用户量、留存等第三方数据（仅厂商自述） | B | 规划书不引用；1.3 不引用任何厂商自述规模数据 |
| 26 | Lookus 的会员档位与计费方式 | B | 规划书不引用；理由同第 23 条 |