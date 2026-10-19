import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_forecast.dart';
import '../utils/coordinate_transform.dart';
import 'app_http_client.dart';
import 'app_log_service.dart';

/// 高德 Web 服务配置。
///
/// Key 通过构建期 `--dart-define=AMAP_KEY=...` 注入，**不落任何入库文件**；
/// 缺省为空串，[isConfigured] 为 false。城市搜索 / 定位反查 / 实况天气都依赖它；
/// 预报走 Open-Meteo，不需要 Key。
abstract final class AmapConfig {
  static const String apiKey = String.fromEnvironment('AMAP_KEY');

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}

/// 天气与地名数据访问。
///
/// 数据源分工：
/// - **预报**（逐小时、16 天）：Open-Meteo `/v1/forecast`，按经纬度，**不需要密钥**；
/// - **实况**（当前天气）：高德 `/v3/weather/weatherInfo?extensions=base`，按 adcode；
/// - **城市搜索**：高德 `/v3/assistant/inputtips`（输入提示）；
/// - **定位反查地名**：高德 `/v3/geocode/regeo`（逆地理）；
/// - **网络估算**：高德 `/v3/ip`（必要时用 `/v3/geocode/geo` 把城市名转成坐标）。
///
/// 本服务只负责发请求与解析成模型，不做缓存、不做节流、不判过期——那些策略在
/// `WeatherProvider` 里。失败一律返回 null / 空列表并留日志，绝不向上抛：
/// 天气是课卡的装饰性信息，任何故障都不该让界面报错。
class WeatherService {
  WeatherService({http.Client? client, Duration? timeout, String? amapKey})
    : this._internal(
        client ?? createAppHttpClient(),
        client == null,
        timeout ?? requestTimeout,
        // 可注入只为了测试：生产恒取构建期注入的 Key（见 [AmapConfig]）。测试传入
        // 一个假 Key 才能走到高德的请求与解析分支；不传则等价于「未配置」。
        amapKey ?? AmapConfig.apiKey,
      );

  WeatherService._internal(
    this._client,
    bool ownsCandidate,
    this._timeout,
    this._amapKey,
  ) : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  static const String _forecastBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  static const String _amapBaseUrl = 'https://restapi.amap.com';

  /// 请求的逐小时变量。**字段名即接口契约**，改动前先看 domain 的聚合算法注释。
  static const String hourlyVariables =
      'temperature_2m,precipitation_probability,precipitation,snowfall,weather_code';

  /// 实测首字节约 2.1 秒（服务器在欧美），10 秒留了约 5 倍余量。
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 回溯 1 天：当天已经上完的课也能显示天气。
  static const int pastDays = 1;

  /// 预报窗口 16 天（接口上限）。日视图能翻到第 20 周，超出窗口时静默不显示。
  static const int forecastDays = 16;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;
  final String _amapKey;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'qhkb-weather',
  };

  /// 高德 Key 是否已配置（未配置时城市搜索 / 定位 / 实况不可用）。
  bool get isConfigured => _amapKey.trim().isNotEmpty;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  // ─── 高德：城市搜索（输入提示）─────────────────────────────────────────────

  /// 按关键字搜索地点（高德输入提示 `/v3/assistant/inputtips`）。
  ///
  /// 未配置 Key、关键字不足 2 个字符或任何失败都返回空列表。
  /// 只保留**带有效坐标**的建议（公交线路等类型不返回坐标），无坐标的无法用于天气。
  Future<List<WeatherLocation>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (!isConfigured || trimmed.length < 2) {
      return const <WeatherLocation>[];
    }

    final uri = Uri.parse('$_amapBaseUrl/v3/assistant/inputtips').replace(
      queryParameters: {
        'key': _amapKey,
        'keywords': trimmed,
        'datatype': 'poi',
      },
    );

    final json = await _getJson(uri, 'weather_geocoding');
    if (json == null || !_amapOk(json)) {
      return const <WeatherLocation>[];
    }
    final tips = json['tips'];
    if (tips is! List) {
      return const <WeatherLocation>[];
    }

    final locations = <WeatherLocation>[];
    for (final item in tips) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final coordinates = _parseAmapCoordinates(map['location']);
      final name = _text(map['name']);
      if (coordinates == null || name == null) {
        continue;
      }
      locations.add(
        WeatherLocation(
          name: name,
          // 输入提示的 district 是「省+市+区」整串，用作行政区标签区分同名地点。
          admin1: _text(map['district']),
          adcode: _text(map['adcode']),
          latitude: coordinates.$1,
          longitude: coordinates.$2,
        ),
      );
    }
    return locations;
  }

  // ─── 高德：定位反查（逆地理）───────────────────────────────────────────────

  /// 按坐标反查可读地名（高德逆地理 `/v3/geocode/regeo`）。
  ///
  /// 失败、未配置 Key 或解析不出地名时返回 null。返回的 [WeatherLocation.timezone]
  /// 留空——让预报接口用 `timezone=auto` 按坐标自行解析，比依赖地名推时区更可靠。
  ///
  /// 参数用位置式（与 [searchLocations] 一致），这样本方法可以直接当
  /// `ReverseGeocode` 的引用传给 `DeviceLocationService`。
  ///
  /// 注意：入参是设备定位给的 **WGS-84**，而高德按 **GCJ-02** 解释坐标，国内两者
  /// 相差数百米；**送高德之前先做正向纠偏**（[wgs84ToGcj02]），否则反查会落到
  /// 邻近的街道。纠偏只作用于请求参数：返回的 [WeatherLocation] 仍带**原始
  /// WGS-84 坐标**，因为那份坐标要交给 Open-Meteo（它期望的就是 WGS-84），
  /// 一旦写成 GCJ-02，预报反而会偏。
  Future<WeatherLocation?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (!isConfigured) {
      return null;
    }
    final (amapLatitude, amapLongitude) = wgs84ToGcj02(latitude, longitude);
    final uri = Uri.parse('$_amapBaseUrl/v3/geocode/regeo').replace(
      queryParameters: {
        'key': _amapKey,
        'location': '$amapLongitude,$amapLatitude',
      },
    );

    final json = await _getJson(uri, 'weather_reverse_geocode');
    if (json == null || !_amapOk(json)) {
      return null;
    }
    final regeocode = json['regeocode'];
    if (regeocode is! Map) {
      return null;
    }
    final component = regeocode['addressComponent'];
    if (component is! Map) {
      return null;
    }
    final comp = Map<String, dynamic>.from(component);
    // 市级名优先取 city；直辖市 city 为空时退回 province。
    final name = _text(comp['city']) ?? _text(comp['province']);
    if (name == null) {
      return null;
    }
    final district = _text(comp['district']);
    return WeatherLocation(
      name: name,
      admin1: _text(comp['province']),
      // 区名与市名相同时不重复记（直辖市反查会给出同名的 city 与 district）。
      district: district == name ? null : district,
      adcode: _text(comp['adcode']),
      // 坐标用**入参那一份原始 WGS-84**（不是纠偏后送高德的那份，也不是响应里
      // 回显的）：这份要交给 Open-Meteo。
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ─── 高德：网络出口 IP 估算 ───────────────────────────────────────────────

  /// 按网络出口 IP 估算所在地（高德 `/v3/ip`）。
  ///
  /// 只在实时定位拿不到时用。必须说清它的性质：这是**估算**，坐标取自城市矩形
  /// 区域范围（[`rectangle`] 的中心），移动网络下可能指到运营商网关所在城市。
  /// 调用方要把结果标注出来，不能当真实定位用。
  Future<WeatherLocation?> networkGeocode() async {
    if (!isConfigured) {
      return null;
    }
    final uri = Uri.parse(
      '$_amapBaseUrl/v3/ip',
    ).replace(queryParameters: {'key': _amapKey});

    final json = await _getJson(uri, 'weather_network_geocode');
    if (json == null || !_amapOk(json)) {
      return null;
    }
    final name = _text(json['city']) ?? _text(json['province']);
    if (name == null) {
      return null;
    }
    final adcode = _text(json['adcode']);

    // 优先用城市矩形区域范围的中心，省一次网络往返。
    //
    // 这里**有意不做 GCJ-02 → WGS-84 反算**（与实时定位那条路相反）。理由：
    // 矩形是高德按 GCJ-02 给的，中心自然也是 GCJ-02，而它的用途只有「市级天气」
    // ——几百米偏移在城市尺度上无实际影响；反算又没有闭式解、只能迭代逼近，
    // 为一个下游要丢弃的精度引入近似不划算。若将来要把这个坐标当真实定位用
    // （距离、导航、精确反查），必须重新评估这里。
    final center = _rectangleCenter(_text(json['rectangle']));
    if (center != null) {
      return WeatherLocation(
        name: name,
        admin1: _text(json['province']),
        adcode: adcode,
        latitude: center.$1,
        longitude: center.$2,
      );
    }
    // 矩形范围缺失时退到正向地理编码，把城市名转成坐标。
    return geocodeAddress(name, adcode: adcode);
  }

  /// 正向地理编码：地名 → 坐标（高德 `/v3/geocode/geo`）。
  ///
  /// 取第一条结果。失败或未配置 Key 返回 null。
  Future<WeatherLocation?> geocodeAddress(String address, {String? adcode}) async {
    final trimmed = address.trim();
    if (!isConfigured || trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_amapBaseUrl/v3/geocode/geo').replace(
      queryParameters: {'key': _amapKey, 'address': trimmed},
    );
    final json = await _getJson(uri, 'weather_forward_geocode');
    if (json == null || !_amapOk(json)) {
      return null;
    }
    final geocodes = json['geocodes'];
    if (geocodes is! List || geocodes.isEmpty) {
      return null;
    }
    final first = geocodes.first;
    if (first is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(first);
    final coordinates = _parseAmapCoordinates(map['location']);
    if (coordinates == null) {
      return null;
    }
    final name =
        _text(map['city']) ?? _text(map['province']) ?? _text(map['district']);
    if (name == null) {
      return null;
    }
    final district = _text(map['district']);
    return WeatherLocation(
      name: name,
      admin1: _text(map['province']),
      district: district == name ? null : district,
      adcode: _text(map['adcode']) ?? adcode,
      latitude: coordinates.$1,
      longitude: coordinates.$2,
    );
  }

  // ─── 高德：实况天气 ───────────────────────────────────────────────────────

  /// 取 [location] 的实况天气（高德 `extensions=base`，按 adcode 查询）。
  ///
  /// 需要 adcode（搜索 / 反查都会带上）；没有 adcode 或未配置 Key 时返回 null。
  Future<CurrentWeather?> fetchCurrentWeather(WeatherLocation location) async {
    final adcode = location.adcode;
    if (!isConfigured || adcode == null || adcode.trim().isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_amapBaseUrl/v3/weather/weatherInfo').replace(
      queryParameters: {
        'key': _amapKey,
        'city': adcode,
        'extensions': 'base',
      },
    );

    final json = await _getJson(uri, 'weather_current');
    if (json == null || !_amapOk(json)) {
      return null;
    }
    final lives = json['lives'];
    if (lives is! List || lives.isEmpty) {
      return null;
    }
    final first = lives.first;
    if (first is! Map) {
      return null;
    }
    try {
      return CurrentWeather.fromAmapLive(Map<String, dynamic>.from(first));
    } catch (error, stackTrace) {
      await _logFailure('weather_current_parse_failed', error, stackTrace);
      return null;
    }
  }

  // ─── Open-Meteo：预报 ─────────────────────────────────────────────────────

  /// 拉取 [location] 的逐小时预报；失败或没有有效数据时返回 null。
  ///
  /// 不需要密钥，因此 Key 未配置时预报仍可用（前提是已有城市）。
  Future<WeatherForecast?> fetchForecast(WeatherLocation location) async {
    final uri = Uri.parse(_forecastBaseUrl).replace(
      queryParameters: {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        // 显式用城市自己的时区，别让服务端按请求 IP 猜：返回的 hourly.time 是
        // 不带偏移量的墙钟串，与课程时间同为墙钟语义，直接比较即可。
        'timezone': location.timezone ?? 'auto',
        'hourly': hourlyVariables,
        'past_days': '$pastDays',
        'forecast_days': '$forecastDays',
      },
    );

    final json = await _getJson(uri, 'weather_forecast');
    if (json == null) {
      return null;
    }
    try {
      final forecast = WeatherForecast.fromOpenMeteoResponse(
        json,
        fetchedAt: DateTime.now(),
      );
      return forecast.hourly.isEmpty ? null : forecast;
    } catch (error, stackTrace) {
      await _logFailure('weather_forecast_parse_failed', error, stackTrace);
      return null;
    }
  }

  // ─── 解析与请求工具 ───────────────────────────────────────────────────────

  /// 高德统一的成功判定：`status == "1"`。失败时留一条含 `info` 的日志。
  bool _amapOk(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    if (status == '1') {
      return true;
    }
    // 高德的 info / infocode 是诊断「Key 无效 / 配额用尽 / 参数错」的关键。
    _logMessage(
      'weather_amap_status',
      'amap returned status=$status info=${json['info']} '
          'infocode=${json['infocode']}',
    );
    return false;
  }

  /// 解析高德 `location` / `rectangle` 里的坐标串 `lng,lat`。
  (double, double)? _parseAmapCoordinates(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final parts = raw.trim().split(',');
    if (parts.length < 2) {
      return null;
    }
    final longitude = double.tryParse(parts[0].trim());
    final latitude = double.tryParse(parts[1].trim());
    if (longitude == null || latitude == null) {
      return null;
    }
    return (latitude, longitude);
  }

  /// 解析高德城市矩形范围 `lng1,lat1;lng2,lat2`，返回其中心点。
  (double, double)? _rectangleCenter(String? raw) {
    if (raw == null) {
      return null;
    }
    final corners = raw.split(';');
    if (corners.length < 2) {
      return null;
    }
    final first = _parseAmapCoordinates(corners[0]);
    final second = _parseAmapCoordinates(corners[1]);
    if (first == null || second == null) {
      return null;
    }
    return ((first.$1 + second.$1) / 2, (first.$2 + second.$2) / 2);
  }

  /// 取非空字符串；非字符串或只有空白都返回 null。
  static String? _text(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// GET 一个 JSON 对象；任何失败都返回 null 并留痕。
  Future<Map<String, dynamic>?> _getJson(Uri uri, String logTag) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        await _logMessage(
          '${logTag}_status',
          'weather request returned ${response.statusCode}',
        );
        return null;
      }
      // 显式按 UTF-8 解码而不是用 response.body：中文城市名（如「杭州」）一旦
      // 落在 latin1 兜底解码上就会变成乱码，而 charset 声明是服务端可选的。
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error, stackTrace) {
      await _logFailure('${logTag}_failed', error, stackTrace);
      return null;
    }
  }

  Future<void> _logFailure(
    String event,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await AppLogService.instance.warn(
        event,
        'weather request failed',
        // 不能把异常对象原样交出去：见 [_withoutCoordinates]。
        error: _withoutCoordinates('$error'),
        stackTrace: stackTrace,
      );
    } catch (_) {
      // 日志通道不可用时不外抛：与 holiday_service 的失败路径一致。
    }
  }

  /// 查询串里的坐标值，形如 `?latitude=30.2936` / `&location=120.16,30.29`。
  /// 值截到下一个 `&` 或空白为止，其它参数原样保留。
  static final RegExp _sensitiveQueryPair = RegExp(
    r'([?&](?:latitude|longitude|lat|lon|location|key)=)[^&\s]*',
    caseSensitive: false,
  );

  /// 抹掉异常文本中的坐标与高德 Key，其余诊断信息一律保留。
  ///
  /// 为什么必须有这一步：`AppLogService` 的落盘会把 `'$error'` 原样写进
  /// `error=` 行，而 http 的异常 `toString()` 会把**完整请求 URL**拼进去
  /// （`ClientException: $message, uri=$uri`）。本服务的 URL 查询串就带
  /// `latitude=&longitude=`（预报）、`location=`（高德逆地理，拿的是**设备定位**）
  /// 与 `key=`（高德明文 Key），而 `app_runtime.log` 正是让用户导出、附在 issue
  /// 里的那份文件 —— 不抹掉的话，弱网下每次刷新天气就往可外流的附件里写一行精确
  /// 坐标与一个可被他人冒用的 Key。
  ///
  /// 只抹这几项的值，不动域名、状态原因与其余 URL：否则这条日志就失去诊断价值。
  static String _withoutCoordinates(String text) => text.replaceAllMapped(
    _sensitiveQueryPair,
    (match) => '${match.group(1)}**',
  );

  Future<void> _logMessage(String event, String message) async {
    try {
      await AppLogService.instance.warn(event, message);
    } catch (_) {
      // 同上。
    }
  }
}