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

## 3. 厂商系统集成现状

**结论**

- **HyperOS「焦点通知 / 超级岛」的开发者接入文档未证实**：小米官方站点 `hyperos.mi.com`
  是面向消费者的产品页（只营销描述「任务上岛」、超级小爱等），未见开发者 API、申请流程或审核要求。
  可核实的技术事实是：这套呈现对应的是 **Android 系统的 promoted ongoing notifications
  （提升型常驻通知）**，自 API 36 引入，API 36.1 补齐权限与请求接口。
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

  注意：`POST_PROMOTED_NOTIFICATIONS` **不出现在 API 36 平台元数据中，只出现在 API 36.1
  （android-37.0）元数据中**；即声明它需要 compileSdk 达到 36.1 一档，否则只是被忽略的未知权限。
- **前台服务**：`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`（API 34）、
  `Service.FOREGROUND_SERVICE_TYPE_SPECIAL_USE`（API 34）、
  `Service.PROPERTY_SPECIAL_USE_FGS_SUBTYPE`（API 34，用于说明 specialUse 的具体用途）。
- **开源项目的常见做法**（轻屿课表，GPL-3.0）：声明 `POST_PROMOTED_NOTIFICATIONS`、
  `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`、`RECEIVE_BOOT_COMPLETED`、
  `SCHEDULE_EXACT_ALARM`、`ACCESS_NOTIFICATION_POLICY`、`MODIFY_AUDIO_SETTINGS`；
  两个 `specialUse` 前台服务（课中实时活动、局域网编辑）都填写了
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 用途说明；README 还引导用户手动授予
  「通知与焦点通知权限、后台无限制与自启动、免打扰访问权限」。
  即：厂商侧的后台保活不是纯代码问题，需要用户侧授权配合。
- **通知渠道**：官方渠道行为依据未取证，可证实的仅有 `POST_NOTIFICATIONS`（API 33）一项。

**来源**

- Google 官方 SDK 平台元数据（本地已安装 SDK，取证日期 2026-10-20）：
  `E:\Android\Sdk\platforms\android-36\data\api-versions.xml`、
  `E:\Android\Sdk\platforms\android-37.0\data\api-versions.xml`
- 小米 HyperOS 官网（仅消费者内容，无开发者文档）：https://hyperos.mi.com/
- 轻屿课表 AndroidManifest（权限、前台服务与用途声明）：
  https://raw.githubusercontent.com/Mutx163/mikcb/main/android/app/src/main/AndroidManifest.xml
- 轻屿课表 README（用户侧授权要求）：
  https://raw.githubusercontent.com/Mutx163/mikcb/main/README.md

**未证实（含取证失败原因）**

- HyperOS 焦点通知/超级岛的开发者接入 API、申请与审核流程：未证实（官方站点无开发者文档）。
- 通知渠道行为、前台服务后台限制、Doze/省电白名单等 Android 官方条目：取证失败
  （`developer.android.com` 本次整体不可达）。
- `POST_PROMOTED_NOTIFICATIONS` 的运行时授权表现及各厂商适配差异：未证实。

## 4. 天气与定位数据源官方事实

### 4.1 Open-Meteo

**免费额度与限流**（官方定价页原文）

| 项 | 免费/开放层 |
| --- | --- |
| 商用 | ❌ 不允许 |
| 每分钟 | 600 calls / min |
| 每小时 | 5,000 calls / hour |
| 每天 | 10,000 calls / day |
| 每月 | 300,000 calls / month |

- 付费档：Standard 1M calls/月、Professional 5M calls/月、Enterprise >50M calls/月；
  付费档走 `customer-api.open-meteo.com` 并以 `&apikey=` 传参，语法与免费档一致，99.9% 可用性目标；
  **免费层无可用性保证**。
- **调用计量规则**：通常 1 个 HTTP 请求 = 1 次调用；但单次请求变量数 >10 或时间跨度 >2 周会被折算，
  官方示例：2 周 × 15 变量 = 1.5 次调用，4 周 = 3.0 次调用。

**许可证与署名**（官方许可页原文）

- API 数据为 **CC BY 4.0**：需署名、提供许可链接、标注是否修改；
  且**必须在任何展示 Open-Meteo 数据的位置旁给出链接**，官方示例
  `<a href="https://open-meteo.com/">Weather data by Open-Meteo.com</a>`。
- 服务端源码为 **AGPLv3**；上游数据源含 DWD、ECMWF、NOAA、CMA 等（多为 CC-BY 系）。

**常用字段**（对官方 `v1/forecast` 端点实测返回，字段名逐字核对）

- `current`：`temperature_2m`(°C)、`relative_humidity_2m`(%)、`apparent_temperature`(°C)、
  `weather_code`(wmo code)、`wind_speed_10m`(km/h)，另有 `interval`(秒)。
- `hourly`：`temperature_2m`、`precipitation_probability`(%)、`weather_code`。
- `daily`：`weather_code`、`temperature_2m_max`、`temperature_2m_min`、`precipitation_probability_max`。
- 顶层：`latitude`、`longitude`、`timezone`、`utc_offset_seconds`、`elevation`；
  各分组另返回 `current_units` / `hourly_units` / `daily_units` 标明单位。
- `forecast_days` 默认 7、最大 16；Open-Meteo 另有 Geocoding API（免费层同样包含）。

### 4.2 高德开放平台

- **天气查询 Web API**：`GET https://restapi.amap.com/v3/weather/weatherInfo`；
  参数 `key`（必填，Web 服务类型 KEY）、`city`（必填，**adcode**）、
  `extensions`（可选，`base`=实况 / `all`=预报）。文档最后更新 2025-03-18。
- **Android 定位 SDK**：官方说明 Flutter 3.0.0 已兼容 Android 定位 SDK ≥5.6.0，并提供 Flutter 插件；
  定位模式 `AMapLocationMode.Hight_Accuracy` / `Battery_Saving` / `Device_Sensors`，
  `setInterval` 最小间隔 1000ms；**逆地理编码随定位结果返回**：
  `getAddress`、`getCountry`、`getProvince`、`getCity`、`getDistrict`、`getStreet`、
  `getStreetNum`、`getCityCode`、`getAdCode`、`getAOIName`。
  合规前置：定位 5.6.0 起调用任何接口前必须先调用 `updatePrivacyShow`、`updatePrivacyAgree`。
- **Key 申请流程**：Web 服务 API 为「控制台 → 应用管理 → 创建新应用 → 添加 Key →
  服务平台选『Web 服务』」；Android 平台 SDK 为「创建应用 → 添加新 Key →
  绑定服务选『Android平台SDK』→ 填发布版安全码 SHA1、调试版 SHA1、Package」。
  `1 个 KEY 只能用于一个应用`（多渠道安装包属于多个应用），多应用共用会调用失败；
  debug 与 release 的 SHA1 不同，发布 APK 需按发布 keystore 重新配置 Key。
- **免费配额**：官方「流量限制说明」页**未给出具体数字**，只指向「定价-基础服务配额说明」与控制台
  「流量分析-配额管理」。具体数值以控制台为准，本文不记录未经文档证实的数字。
- **许可**：定位 SDK 官方「开发者使用注意事项」明确——法人或非法人组织使用平台服务应事先购买
  技术服务许可；未购买时平台提供的 KEY 与服务配额**仅供短期、少量的测试目的**；
  面向公众提供、上架分发、收费或投放广告、长期或大量调用等构成未许可使用。
- **Key 不入库**：官方只提示「妥善保管你的 Key」，未发现专门的仓库安全规范（未证实存在该规范）。
  可核实的结构性事实是：Android 平台 Key 必须绑定 SHA1 与 Package，因而必然随 APK 分发，
  属客户端凭据；Web 服务 Key 在控制台按平台单独授予，属服务端凭据。
  据此，工程上的合理做法是客户端 Key 走构建期注入（占位符 + 不入库的 `local.properties`/CI 密钥），
  仓库只提交占位，Web 服务 Key 只放自有服务端、不下发客户端。
  （此为工程判断，非官方明文要求。）

**来源**

- Open-Meteo 定价（免费档限流、付费档、调用计量）：https://open-meteo.com/en/pricing
- Open-Meteo 许可（CC BY 4.0、署名示例、AGPLv3 源码）：https://open-meteo.com/en/licence
- Open-Meteo 天气 API 文档（变量清单、forecast_days）：https://open-meteo.com/en/docs
- Open-Meteo 端点实测（字段名与单位，2026-10-20 调用）：
  https://api.open-meteo.com/v1/forecast?latitude=39.9042&longitude=116.4074&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FShanghai&forecast_days=2
- 高德天气查询文档：https://lbs.amap.com/api/webservice/guide/api/weatherinfo
- 高德流量限制说明（配额入口）：https://lbs.amap.com/api/webservice/guide/tools/flowlevel
- 高德 Web 服务 Key 创建流程：https://lbs.amap.com/api/webservice/create-project-and-key
- 高德 Android 定位 SDK 概述（Flutter 兼容性、字段、隐私合规、技术服务许可）：
  https://lbs.amap.com/api/android-location-sdk/locationsummary
- 高德 Android 定位 SDK 获取 Key（SHA1/Package 绑定、1 Key 1 应用）：
  https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key

**未证实**

- 高德 Web 服务 API 的具体免费配额数值：官方页面未给出，需在控制台查看（未证实具体数字）。
- 高德 SDK 的开源许可证文本：官方文档只谈技术服务许可与使用限制，未提供 SDK 开源许可声明，
  SDK 为闭源二进制（未证实其许可证类型）。
- 「Key 不得入库」的官方规范：未证实存在高德官方仓库安全规范页；仓库保密措施依据
  GitHub 等平台能力，本次未取证。
- Open-Meteo 免费层是否对单 IP 并发连接数另有限制：未证实。