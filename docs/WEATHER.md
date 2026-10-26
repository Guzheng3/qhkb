# 天气功能

课卡上的天气信息：日视图课卡、周视图格子、课程详情弹窗各一处，数据源见下。

## 数据来源

客户端**不直连任何第三方天气服务**，不持有和风 / 高德 / Open-Meteo 的 Key 或
Token。所有天气数据都走 withU 课表接口的天气动作：

```
GET {baseUrl}/api/timetable.php?action=weather&mode=now|hourly|lookup&...
```

- `baseUrl` 就是 withU 已配置的地址（`QhkbCoupleConfig.baseUrl`），与
  `login` / `bootstrap` / `partner` 同一个 host。
- 认证复用现有会话：`PHPSESSID` + `withu_device` Cookie，由
  `QhkbCoupleAuthService` 统一携带与续期。天气是只读 GET，不需要 CSRF token。
- 未登录返回 401，非情侣账号返回 403；客户端把这两种情况当作「天气不可用」，
  隐藏天气或沿用本地缓存，不弹错误。
- 和风 Key / Token / 私钥只存在服务端，客户端代码与 APK 里都没有。

## 客户端用到的三种模式

| `mode` | 用途 | 主要参数 | 返回 |
|--------|------|----------|------|
| `lookup` | 地点搜索 / 坐标反查城市 | `q` 或 `lat`+`lng`、`number` | `locations[]` |
| `now` | 实况 | `lat`、`lng`、`label` | `data`（实况字段） |
| `hourly` | 逐小时预报 | `lat`、`lng`、`label`、`hours` | `data`（列式预报） |

服务端还支持 `mode=daily`，当前课卡没有用到逐日预报，客户端暂不请求。

### 请求坐标

客户端直接传 **WGS-84**、6 位小数（`lat` / `lng`）。坐标系转换与和风要求的
`lng,lat` 顺序都在服务端完成，客户端不再做 GCJ-02 纠偏。`label` 用展示名
（例如「杭州市 · 拱墅区」），服务端用它填充 `location.name` / `data.city`。

### `mode=now` 的 `data`

同时兼容两套字段：

- `weather` / `temperature` / `humidity` / `winddirection` / `windpower` /
  `reporttime`（Amap `lives[0]` 兼容字段）；
- `desc` / `temp` / `windDir` / `windScale` / `obsTime`（withU 网页沿用字段）；
- `wmo_code`：服务端由和风图标码映射出的 WMO 码，客户端优先用它归类。

解析入口：`lib/models/weather_forecast.dart` 的
`CurrentWeather.fromServerJson`。

### `mode=hourly` 的 `data`

与旧 Open-Meteo 响应同构的列式结构：

```json
{
  "latitude": 30.29,
  "longitude": 120.15,
  "hourly": {
    "time": ["2026-10-26T23:00", "2026-10-27T00:00"],
    "temperature_2m": [20, 19],
    "precipitation_probability": [10, 5],
    "precipitation": [0.0, 0.0],
    "snowfall": [null, null],
    "weather_code": [2, 1]
  }
}
```

- `time` 是不带时区偏移的墙钟时间，与课程时间同语义，直接比较。
- `weather_code` 是 WMO 码，现有按周 / 按天聚合与天气分类逻辑不用改。
- 客户端请求 `hours=168`（一周）；服务端受和风套餐限制时可能返回更短窗口，
  展示层按实际窗口降级，不假设一定有 16 天。若服务端把 168 判为非法参数
  （`weather_invalid_params`），客户端自动退到 `hours=24` 再试一次。
- 解析入口：`WeatherForecast.fromHourlyResponse`。它**优先用请求坐标**作为
  归属，而不是响应回填的格点 / 城市坐标——`WeatherForecast.matchesLocation`
  要拿它和用户所选城市比较，用响应坐标会让缓存被误判成换城。

### `mode=lookup` 的 `locations[]`

每条同时包含 `WeatherLocation.fromJson` 需要的字段（`name` / `latitude` /
`longitude` / `admin1` / `country` / `district` / `timezone` / `adcode`）与和风
GeoAPI 原始字段。`adcode` 放和风 LocationID，客户端只当不透明 ID 使用。

和风 GeoAPI 是城市级反查，不提供街道级逆地理；`district` 通常为 null，展示层
已允许（`displayName` 会退回只显示市名）。

## 缓存与刷新

客户端仍按原来的策略：

- 预报 TTL 3 小时；失败退避 15 分钟；并发请求单飞。
- 预报缓存在 `SharedPreferences` 的 `weather_forecast_v1`（列式 JSON），
  城市在 `weather_city_v1`，开关在 `weather_enabled_v1`。
- 换城市时立刻作废旧预报并清除落盘缓存；缓存城市与所选城市不一致时丢弃。
- 服务端还有一层短时缓存（`now` 5 分钟、`hourly` 20–30 分钟、`lookup` 24 小时），
  对客户端透明。

## 定位权限

「使用当前位置」走 `geolocator`（Android 上无 GMS 时自动回退系统 LocationManager），
并在 `android/app/src/main/AndroidManifest.xml` 声明：

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

- 只在用户主动点「使用当前位置」时才申请，不随启动索取；
- 拒绝授权时不阻塞：可以继续在搜索页手动选城市；
- 取到坐标后先经服务端 `mode=lookup&lat&lng` 反查城市名与坐标，再落盘保存；
- 服务端契约没有「按网络出口 IP 估算位置」这一种模式，实时定位拿不到时不再猜城市。

## 未连接 withU 时

天气依赖 withU 会话。未连接时设置页与选城市页显示「连接 withU 后才能查看天气」，
搜索 / 定位入口置灰；课卡沿用本地缓存（如果有），没有缓存则不显示天气。
`WeatherProvider` 在发请求前先调用 `WeatherService.hasSession()` 确认会话，
未连接时**不发任何请求**，也不进入 15 分钟失败退避——用户登录后下一次
`ensureFresh` 就能立刻重试。客户端不会因为天气去要求登录，也不会把天气请求
发到 withU 以外的地址。

## 课卡上的天气图标

天气现象用**自绘字形**（`lib/widgets/weather_glyph.dart`）：按 24×24 的设计网格摆放
坐标，绘制时整体缩放到实际边长，三个渲染面（日视图课卡、日视图信息行、课程详情弹窗）
共用同一套比例与重心。

自绘而不是取 Material 图标：图标表里没有「云 + 雨」这一族组合字形，只有单个水滴、雨伞、
雪花这些零件，形状与现象对不上；而且那一族只有描边版，缩到窄卡上的十来个点就只剩一圈
灰线。

- 颜色是一套固定的天气配色（云冷灰、水蓝、冰青、太阳与闪电暖黄），不跟随主题：天气
  现象的含义不该随主题变。深浅层次用同一颜色的透明度做。
- 为了在**任何**卡面上都看得清，每个形状外面还按 0.6 格加粗描了一圈墨色轮廓。墨色
  就是课卡那支自动翻黑白的颜色（饱和色卡配白墨、浅色卡配黑墨），浅卡上深色的云、
  深卡上发亮的雪、橙黄卡上同色系的太阳，边界都由它兜住；填充本身再按墨色明暗取两套
  色板之一，浅卡上的云比深卡上的云深一档。
- 小雨 / 中雨 / 大雨只差雨丝的条数与长度；阵雨 / 阵雪多一个露在云后的太阳；冻雨、
  冻毛毛雨里的雪花是「会结冰」的那一半信息；雷阵雨的闪电画在云之前，根部被云吃掉。
- 温度与降水概率不是天气现象，继续用 Material 图标（`Icons.thermostat` /
  `Icons.percent`），与同一张卡上时间 / 地点两行的图标同族。
- 现象 → 字形的映射是 `lib/widgets/course_weather_display.dart` 的 `weatherGlyphFor`，
  穷尽 `WeatherCategory`：将来加一档天气现象会编译不过，而不是悄悄回落成别的形状。

## 失败处理

- 服务层对任何失败只返回 null / 空列表并留一条**不含坐标、不含完整 URL** 的日志；
  不向上抛。
- `weather_not_configured`、`weather_upstream_error`、上游超时等都静默隐藏天气，
  不弹错误——天气是课卡的装饰性信息。
- 设置页保留「上次更新失败 / 重试」入口，是唯一的显式补救动作。
- 课卡在「确实该有天气但数据还没到」时预留等高不可见空位，数据到达时只换内容、
  不顶动下方卡片（实现见 `WeatherProvider.isAwaitingData`）。

## 已知限制

- 逐小时预报窗口由服务端 / 和风套餐决定，可能是 24h、72h 或 168h；更远的日期
  不显示天气。日视图 / 周视图按实际返回窗口静默降级。
- 天气需要已连接 withU；未登录 401、非情侣账号 403，这两种情况都不会显示天气。
- `mode=daily` 与和风原始字段（`qweather_hourly` 等）客户端暂不消费。
- 服务端天气代理不落库用户坐标与搜索记录；客户端日志也会抹掉坐标与完整请求 URL。

## 与规划书的关系

`docs/plan/product-plan.md` 的 3.3、4.6、5.1、5.2、5.4.13、5.7–5.10、6.3、
7.3–7.6、8.2 Q5 已按本契约同步为「全部经 withU `action=weather`，服务端持和风
凭据，客户端零密钥」。实现细节以本文与 `lib/services/weather_service.dart` 为准；
规划书如果再次调整服务端口径，需要同步回本文。
