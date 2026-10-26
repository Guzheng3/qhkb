import 'dart:async';

import '../models/weather_forecast.dart';
import 'app_log_service.dart';
import 'qhkb_couple_auth_service.dart';

/// 天气数据访问。
///
/// 客户端**不再直连任何第三方天气/地理服务**：高德与 Open-Meteo 的地址、Key、
/// 解析逻辑均已移除，统一走 withU 课表接口的天气动作：
///
/// ```
/// GET {baseUrl}/api/timetable.php?action=weather&mode=now|hourly|lookup&...
/// ```
///
/// 认证复用现有 withU 会话（`PHPSESSID` + `withu_device`，见
/// [QhkbCoupleAuthService]）：与 login / bootstrap / partner 同一个 host、
/// 同一套 401 / 403 处理；天气是只读 GET，不需要 CSRF token。
///
/// 服务端返回的外层 `location` 与 `WeatherLocation.fromJson` 同构；`mode=now` 的
/// `data` 走 [CurrentWeather.fromServerJson]，`mode=hourly` 的 `data` 是列式结构，
/// 走 [WeatherForecast.fromHourlyResponse]。
///
/// 失败一律返回 null / 空列表并留一条**不含坐标**的日志，绝不向上抛：天气是
/// 课卡的装饰性信息，任何故障都不该让界面报错。缓存、TTL、退避、单飞等策略仍在
/// `WeatherProvider` 里，本服务只负责取数。
class WeatherService {
  WeatherService({QhkbCoupleAuthService? authService})
    // ignore: prefer_initializing_formals
    : _authService = authService;

  /// 逐小时预报请求窗口。和风套餐通常 24h，付费档可 72h/168h；服务端会按实际
  /// 可用范围返回，展示层按返回窗口降级。这里请求一周，尽量让周视图的每一天
  /// 都有天气；服务端若只支持 24h，返回的列会更短，不影响解析。
  static const String hourlyHours = '168';

  QhkbCoupleAuthService? _authService;

  QhkbCoupleAuthService get _auth =>
      _authService ??= QhkbCoupleAuthService();

  /// 是否已有可用的 withU 会话。
  ///
  /// 没有会话时上层不必发请求，也不该把「未登录」当成一次失败退避；有缓存时
  /// 照常展示缓存。会话读取失败按「未登录」处理，天气是可选功能，不值得抛。
  Future<bool> hasSession() async {
    try {
      final session = await _auth.loadSession();
      return session != null && session.isUsable;
    } catch (_) {
      return false;
    }
  }

  /// 与 `WeatherProvider.dispose()` 对齐的空实现：认证服务是应用共享实例，
  /// 本服务不拥有它，不能在这里关闭。
  void dispose() {}

  /// 按关键字搜索地点（服务端 `mode=lookup&q=`）。
  ///
  /// 关键字不足两个字符时直接返回空列表，不浪费一次请求。
  Future<List<WeatherLocation>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const <WeatherLocation>[];
    }
    try {
      final payload = await _auth.getJson(
        'weather',
        query: {'mode': 'lookup', 'q': trimmed, 'number': '10'},
      );
      return _locationsFrom(payload);
    } catch (error) {
      _logFailure('weather_lookup_failed', error);
      return const <WeatherLocation>[];
    }
  }

  /// 按坐标反查可读地名（服务端 `mode=lookup&lat=&lng=`）。
  ///
  /// 入参是设备定位的 WGS-84 坐标；坐标系转换与和风请求都在服务端完成。反查
  /// 结果是城市级的（和风 GeoAPI 不提供街道级逆地理），没有区县时
  /// [WeatherLocation.district] 为 null，展示层已允许。
  Future<WeatherLocation?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final payload = await _auth.getJson(
        'weather',
        query: {
          'mode': 'lookup',
          'lat': latitude.toStringAsFixed(6),
          'lng': longitude.toStringAsFixed(6),
        },
      );
      final locations = _locationsFrom(payload);
      if (locations.isNotEmpty) {
        return locations.first;
      }
      // 有些响应会把单条结果放在外层 location 里；兼容这一种形态。
      return _locationFrom(payload['location']);
    } catch (error) {
      _logFailure('weather_reverse_geocode_failed', error);
      return null;
    }
  }

  /// 服务端契约没有「按网络出口 IP 估算位置」这一种模式。
  ///
  /// 实时定位拿不到时不再猜城市：宁可让上层如实报定位失败，也不拿运营商网关
  /// 所在城市的天气冒充当前位置。
  Future<WeatherLocation?> networkGeocode() async => null;

  /// 取 [location] 的实况天气（服务端 `mode=now`）。
  Future<CurrentWeather?> fetchCurrentWeather(WeatherLocation location) async {
    try {
      final payload = await _auth.getJson(
        'weather',
        query: _locationQuery(location, 'now'),
      );
      final data = _mapFrom(payload['data']);
      if (data == null) {
        return null;
      }
      return CurrentWeather.fromServerJson(data);
    } catch (error) {
      _logFailure('weather_now_failed', error);
      return null;
    }
  }

  /// 取 [location] 的逐小时预报（服务端 `mode=hourly`）。
  ///
  /// 服务端返回的 `data` 与旧 Open-Meteo 列式结构同构；经纬度优先用**请求
  /// 坐标**，这样 `WeatherForecast.matchesLocation` 才能把它认成当前城市，
  /// 缓存不会在冷启动时被误丢。
  Future<WeatherForecast?> fetchForecast(WeatherLocation location) async {
    try {
      final payload = await _hourlyPayload(location);
      final data = _mapFrom(payload['data']);
      if (data == null) {
        return null;
      }
      final forecast = WeatherForecast.fromHourlyResponse(
        data,
        fetchedAt: DateTime.now(),
        requestLatitude: location.latitude,
        requestLongitude: location.longitude,
      );
      return forecast.hourly.isEmpty ? null : forecast;
    } catch (error) {
      _logFailure('weather_hourly_failed', error);
      return null;
    }
  }

  /// 请求一周窗口；服务端/和风套餐不支持 168h 时退到 24h 再试一次。
  ///
  /// 契约把 `hours` 的合法值限定为 24/72/168 且「取决于和风套餐」，所以 168
  /// 被服务端判为非法参数时不是真正的失败，降级到默认窗口即可保证至少有今天
  /// 的天气；其它错误原样抛给 [fetchForecast] 的 catch。
  Future<Map<String, dynamic>> _hourlyPayload(
    WeatherLocation location,
  ) async {
    try {
      return await _auth.getJson(
        'weather',
        query: _locationQuery(
          location,
          'hourly',
          extra: {'hours': hourlyHours},
        ),
      );
    } on QhkbCoupleApiException catch (error) {
      if (error.serverError == 'weather_invalid_params') {
        return _auth.getJson(
          'weather',
          query: _locationQuery(
            location,
            'hourly',
            extra: {'hours': '24'},
          ),
        );
      }
      rethrow;
    }
  }

  Map<String, String> _locationQuery(
    WeatherLocation location,
    String mode, {
    Map<String, String> extra = const <String, String>{},
  }) {
    return {
      'mode': mode,
      'lat': location.latitude.toStringAsFixed(6),
      'lng': location.longitude.toStringAsFixed(6),
      // 服务端用它填充 location.name / data.city；用展示名让定位来的地点也带区。
      'label': location.displayName,
      ...extra,
    };
  }

  List<WeatherLocation> _locationsFrom(Map<String, dynamic> payload) {
    final raw = payload['locations'] ?? _mapFrom(payload['data'])?['locations'];
    if (raw is! List) {
      return const <WeatherLocation>[];
    }
    final locations = <WeatherLocation>[];
    for (final item in raw) {
      final location = _locationFrom(item);
      if (location != null) {
        locations.add(location);
      }
    }
    return locations;
  }

  WeatherLocation? _locationFrom(Object? raw) {
    final map = _mapFrom(raw);
    if (map == null) {
      return null;
    }
    try {
      return WeatherLocation.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _mapFrom(Object? raw) {
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  /// 只记录错误类别，**不记录坐标或完整 URL**：`app_runtime.log` 会被用户导出
  /// 附在 issue 里，天气请求的查询串带经纬度，不能原样落盘。
  void _logFailure(String event, Object error) {
    final detail = error is QhkbCoupleApiException
        ? 'code=${error.code}'
              '${error.serverError == null ? '' : ' error=${error.serverError}'}'
        : 'failed';
    unawaited(
      AppLogService.instance
          .warn(event, detail)
          .catchError((Object _) {}),
    );
  }
}
