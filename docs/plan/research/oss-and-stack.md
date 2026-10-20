# 开源实现与技术方案调研

面向全新 Flutter + Android only 课表应用的架构章节事实输入。本文只做事实调研：
每条结论给出依据与来源 URL，配额、许可证、字段名、权限名一律以官方文档或官方发布物为准；
未能取证的内容标注「未证实」，不做推测性补全。

- 调研日期：2026-10-20（除另标注者，各来源访问日期同为 2026-10-20）
- 取证工具限制：本机 `web_search` 不可用，全部来源经 `web_fetch` 直取；
  `developer.android.com` 全站抓取失败（`fetch failed`），凡涉及其内容的条目均标注取证失败原因。

## 1. 开源课表/日程项目参考

**结论**

- **ClassIsland**（C# / .NET 8 / Avalonia，跨平台，非 Flutter）是模块划分最值得参照的同类项目：
  功能域拆为「课表信息显示 / 课表编辑与管理 / 自定义（组件·插件·主题）/ 自动化 / 天气」；
  课表编辑侧已具备多周轮换、单日或跨天临时换课、预定课表，以及时间表与科目分离维护。
- **许可证双轨**：应用本体 **GPL-3.0**；`ClassIsland.Core`、`ClassIsland.PluginSdk`、
  `ClassIsland.Shared`、`ClassIsland.Shared.Ipc` 为 **LGPL-3.0**（便于插件闭源）。
  同组织集控服务端 `ClassIsland/ManagementServer` 为 **AGPL-3.0**。
  借鉴其代码会引入强著佐权义务，因此只宜借鉴设计。
- **数据模型术语**（官方 README 与界面命名）：档案（Profile）、时间表、科目、课表（ClassPlan）、
  预定课表、跨天换课、组件、自动化。可视为「课程实体 / 节次时间表 / 学期周次」三者解耦的证据。
- **导入方案**：官方支持从 Excel 表格、CSES（`SmartTeachCN/CSES`）及其它软件导入，并可导出 Excel。
- **WakeUp 生态**：未检索到 WakeUp 官方 App 本体的开源仓库。按 GitHub 仓库搜索 `wakeup 课表`，
  结果均为围绕 WakeUp 的**导入适配层与第三方实现**，例如 `koishi-plugin-course-schedule`
  （同时支持 WakeUp/星链/拾光，ICS/JSON 多格式导入）、`PyWakeup`、`nju2wakeup`、
  `NYIST-CIPS/CourseTable`（MIT）、`ershiyidian/WakeUp_SHU`（自称「面向上海大学的
  WakeUp 6.0.23 定制工程」）。WakeUp 的价值在**导入格式与高校适配生态**，不在架构参考。
- **Flutter 课表项目许可分布**（GitHub 官方仓库元数据）：`BenderBlog/traintime_pda` MPL-2.0、
  `The-Brotherhood-of-SCU/Bugaoshan` AGPL-3.0、`WheretoSleepinNJU/NJU-Class-Shedule-Flutter`
  Apache-2.0、`gnahz77/SchedU` MIT（自称支持 JSON/AI 导入）、`Mutx163/mikcb`（轻屿课表）
  GPL-3.0-or-later、`JS-CAUTION/csust-course-schedule` MIT。宽松许可与强著佐权大体各半，
  「参考哪个项目」直接决定本项目的许可证与合规成本。
- **`Mutx163/mikcb` 与本项目目标最接近**（Flutter + Android only、minSdk 26 / targetSdk 36、
  Flutter 3.44.8），已实现 ics 导入、桌面小组件矩阵、双人课表合并比对，并经原生集成
  Notification、Ongoing Promoted Activity、Foreground Service、AlarmClock。
  其「Flutter 壳 + 原生能力」的职责切分有直接参考价值。

**来源**

- ClassIsland README（模块与功能、导入方案、许可证双轨）：
  https://raw.githubusercontent.com/ClassIsland/ClassIsland/master/README.md
- ClassIsland 组织仓库元数据（应用本体 GPL-3.0、ManagementServer AGPL-3.0）：
  https://api.github.com/orgs/ClassIsland/repos?per_page=100
- 轻屿课表 README（技术架构、格式导入、双人课表、许可证）：
  https://raw.githubusercontent.com/Mutx163/mikcb/main/README.md
- 轻屿课表第三方许可清单（依赖许可与商标声明）：
  https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/THIRD_PARTY_LICENSES.md
- GitHub 仓库检索（WakeUp 相关、Flutter 课表项目及许可证字段）：
  https://api.github.com/search/repositories?q=wakeup+%E8%AF%BE%E8%A1%A8 、
  https://api.github.com/search/repositories?q=%E8%AF%BE%E8%A1%A8+language:dart

**未证实**

- WakeUp 官方 App 是否开源：未证实（公开检索未发现官方本体仓库，不等于不存在）。
- 上述项目的字段级数据模型：未逐仓库核对，本文只采信各自 README 与仓库元数据的表述。

## 2. Android 桌面小组件在 Flutter 下的可行方案

**结论**

- **Flutter 不能直接渲染原生桌面小组件**。`home_widget`（0.10.0，BSD-3-Clause，Android+iOS）
  官方表述：插件**不允许用 Flutter 编写小组件**，仍需原生代码实现；
  或用 `home_widget_generator` 在 Dart 中描述一次、由 `home_widget_cli` 生成原生源码。
  插件提供的是数据下发、读取与刷新通知的统一接口。
- **接口形态**（官方 README 示例）：`HomeWidget.saveWidgetData<String>('id', data)` 下发数据，
  `HomeWidget.updateWidget(name: 'XxxProvider')` 触发刷新；静态方法使其可在后台执行体中使用。
- **后台刷新路径**：官方「Background Updates」文档建议配合后台执行插件实现，示例用
  `flutter_workmanager`，并提示 iOS 侧需注册插件。该文档**未定义**刷新频率上限，
  频率限制由各平台系统机制决定。
- **原生侧落地方式**：小组件 = `<receiver>` 声明 `android.appwidget.action.APPWIDGET_UPDATE`
  + `android:appwidget.provider` 元数据指向 `AppWidgetProviderInfo` XML。
  实践参考：轻屿课表在同一 APK 内声明 9 个 `*WidgetProvider`（今日课程多规格、统计、
  考试倒计时等），并用额外的 `HomeWidgetRefreshReceiver` 监听 `APPWIDGET_UPDATE` 及
  `BOOT_COMPLETED`、`MY_PACKAGE_REPLACED`、`TIME_SET`、`TIMEZONE_CHANGED` 重排刷新——
  这是「开机、改时间、改时区后重新对齐」的可行做法。
- **深色与主题适配**：官方依据未取证。可确认的事实是：该工程让小组件共用
  `android:theme="@style/QingyuWidgetTheme"`，主题由应用侧 style 承载。

**来源**

- home_widget 包页（版本、许可证、平台、文档入口）：https://pub.dev/packages/home_widget
- home_widget 官方文档首页（不支持 Flutter 直写小组件、生成器与 CLI 路线）：
  https://docs.page/ABausG/home_widget
- home_widget 官方「Background Updates」文档（后台刷新建议、需配合后台执行插件）：
  https://docs.page/ABausG/home_widget/features/background-updates
- home_widget 仓库元数据：https://api.github.com/search/repositories?q=home_widget+flutter
- 小组件原生声明与刷新广播实践：
  https://raw.githubusercontent.com/Mutx163/mikcb/main/android/app/src/main/AndroidManifest.xml

**未证实（含取证失败原因）**

- Android 官方「App Widgets 概览」及小组件更新周期/后台限制页面取证失败：
  `https://developer.android.com/develop/ui/views/appwidgets/overview` 多次返回 `fetch failed`
  （该域名本次整体不可达）。**小组件更新周期、Doze/后台限制下的刷新行为**未证实。
- Jetpack **Glance** 官方文档页
  `https://developer.android.com/develop/ui/views/compose/glance` 同上，未证实；
  其作为原生小组件实现路线、以及与 `home_widget` 数据通道的配合方式未证实。
- 小组件深色模式/主题色的官方适配规范未证实。