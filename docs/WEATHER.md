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

不需要 Key 的部分照常工作，需要 Key 的部分明确提示而不是报错：

- 预报（Open-Meteo）**照常可用**，课卡天气正常显示；
- 实况不显示；
- 设置里的「天气」中城市搜索不可用，选城市页与设置页均提示
  「未配置高德 API Key：城市搜索与定位不可用；预报数据仍可正常使用。」，输入框不再渲染。

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