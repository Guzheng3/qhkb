# 天气功能

课卡上的天气信息：日视图课卡、周视图格子、课程详情弹窗各一处，数据源见下。

## 数据来源分工

| 用途 | 服务 | 请求 |
|------|------|------|
| 预报（逐小时，未来 16 天） | [Open-Meteo](https://open-meteo.com/) | `GET https://api.open-meteo.com/v1/forecast`，按经纬度，**不需要密钥** |
| 实况（当前天气） | 高德 Web 服务 | `GET /v3/weather/weatherInfo?extensions=base`，按 adcode |
| 城市搜索 | 高德 Web 服务 | `GET /v3/assistant/inputtips`（输入提示） |
| 定位反查地名 | 高德 Web 服务 | `GET /v3/geocode/regeo`（逆地理编码） |
| IP 估算位置 | 高德 Web 服务 | `GET /v3/ip`（无坐标时用 `/v3/geocode/geo` 由城市名补坐标） |

实况与预报分开取：预报要的是逐小时区间，Open-Meteo 免费且不限量；实况高德给的是
中文现象文本与现成温度，直接用省一次映射。

「预报不需要密钥」只是说这个请求本身不校验密钥；城市搜索与定位都要密钥，所以
**对用户而言没有 Key 就是没有天气**（见「未配置 Key 时的行为」），不要把它读成用户承诺。

## 高德 Key

Key **不进仓库**，一律在构建期注入：

```bash
flutter build apk --release --flavor prod --target-platform android-arm64 \
  --dart-define=AMAP_KEY=<你的高德 Web 服务 Key>
```

- 代码里只有占位：`String.fromEnvironment('AMAP_KEY')`（见 `lib/services/weather_service.dart`
  的 `AmapConfig`），缺省为空串。
- 测试用假 Key（`test-amap-key`）注入到 `WeatherService`，真 Key 不写进任何测试或示例。

### 未配置 Key 时的行为

未配置时城市搜索与「使用当前位置」都被挡住，而默认没有城市，所以**用户看不到任何天气**。
文案就照这个实际结果写，不能写成「预报还能用」：

- 选城市页与设置页提示「未配置高德 API Key：既搜不了城市，也用不了定位，因此不会显示天气。」，
  搜索框不再渲染；
- 实况与预报都不显示。

服务层对未配置 Key 只跳过需要 Key 的请求（预报请求本身不依赖 Key），这是实现事实，
不构成对用户的承诺——用户选不到位置就等于没有天气。

## 坐标系

设备定位（geolocator / 系统 LocationManager）给的是 **WGS-84**，高德按 **GCJ-02** 解释坐标，
国内两者相差数百米。转换实现见 `lib/utils/coordinate_transform.dart` 的 `wgs84ToGcj02`。

- **送高德的坐标先纠偏**：`WeatherService.reverseGeocode` 把入参 WGS-84 转成 GCJ-02 再拼进
  `location=lng,lat`；返回的 `WeatherLocation` 仍带**原始 WGS-84**——那份要交给 Open-Meteo，
  写成 GCJ-02 反而会让预报偏。
- **Open-Meteo 侧保持 WGS-84**，不做任何转换（它期望的就是 WGS-84）。
- **IP 估算那条路有意不反算**：`/v3/ip` 的 `rectangle` 中心是高德按 GCJ-02 给的，这里直接当
  WGS-84 送去 Open-Meteo，最多偏数百米。市/区级天气按格点取值，这个量级无实际影响；而
  GCJ-02 → WGS-84 没有闭式解、只能迭代逼近，为一个下游本就丢弃的精度引入近似不划算。
  若将来把这个坐标用于距离、导航或精确反查，必须重新评估（见 `WeatherService.networkGeocode`
  的结论式注释）。
- **高德回来的坐标不再转**：城市搜索（输入提示）、正向地理编码、IP 矩形中心给的都是 GCJ-02，
  这些坐标直接送去 Open-Meteo，与上一条同样存在数百米偏差，同样是市/区级天气可忽略的量级。
  只有「设备定位 → 送高德」这一个方向需要纠偏，因为那是唯一一处坐标来源与消费方坐标系不一致的地方。

## 定位权限

「使用当前位置」走 `geolocator`（Android 上无 GMS 时自动回退系统 LocationManager），
并在 `android/app/src/main/AndroidManifest.xml` 声明：

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

- 只在用户主动点「使用当前位置」时才申请，不随启动索取；
- 拒绝授权时不阻塞：可以继续在搜索页手动选城市；
- 两者必须同时声明（只声明 FINE 在 Android 12+ 会 lint 失败），用户选「大致」精度时
  天气仍可用——天气本来就按区级算。
- 取到坐标后只用于**反查地名**，落盘保存的是地名与坐标，不下发到自建服务器。

## 已知限制

- 预报窗口 16 天，更远的日期不显示天气；日视图能翻到的周次超出窗口时静默隐藏。
- 高德 Web 服务有每日调用配额，键值外流可能被他人冒用，因此失败日志会把
  `key=`、坐标查询参数一并抹除（见 `WeatherService._withoutCoordinates`）。