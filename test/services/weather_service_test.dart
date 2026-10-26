import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qhkb/domain/weather_logic.dart';
import 'package:qhkb/models/weather_forecast.dart';
import 'package:qhkb/services/qhkb_couple_auth_service.dart';
import 'package:qhkb/services/qhkb_couple_session_store.dart';
import 'package:qhkb/services/weather_service.dart';

const _hangzhou = WeatherLocation(
  name: '杭州市',
  admin1: '浙江省',
  country: '中国',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
  adcode: '101210101',
);

/// 只替换传输层：记录 action / query，按契约返回固定 payload。
class _FakeAuthService extends QhkbCoupleAuthService {
  _FakeAuthService(this.handler)
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  final Future<Map<String, dynamic>> Function(
    String action,
    Map<String, String>? query,
  )
  handler;

  final List<({String action, Map<String, String>? query})> calls = [];

  QhkbCoupleSession? session;

  @override
  Future<QhkbCoupleSession?> loadSession() async => session;

  @override
  Future<Map<String, dynamic>> getJson(
    String action, {
    Map<String, String>? query,
  }) {
    calls.add((action: action, query: query));
    return handler(action, query);
  }
}

Map<String, dynamic> _lookupPayload() => {
  'success': true,
  'code': 200,
  'locations': [
    {
      'name': '杭州市',
      'latitude': 30.29,
      'longitude': 120.15,
      'admin1': '浙江省',
      'country': '中国',
      'district': null,
      'timezone': 'Asia/Shanghai',
      'adcode': '101210101',
      'id': '101210101',
      'lat': '30.29',
      'lon': '120.15',
    },
  ],
};

Map<String, dynamic> _nowPayload() => {
  'success': true,
  'code': 200,
  'data': {
    'weather': '多云',
    'temperature': '21',
    'humidity': '63',
    'winddirection': '东北风',
    'windpower': '3',
    'reporttime': '2026-10-26 22:00:00',
    'wmo_code': 2,
  },
};

Map<String, dynamic> _hourlyPayload() => {
  'success': true,
  'code': 200,
  'data': {
    'latitude': 30.26,
    'longitude': 120.14,
    'hourly': {
      'time': ['2026-10-26T23:00', '2026-10-27T00:00'],
      'temperature_2m': [20, 19],
      'precipitation_probability': [10, 5],
      'precipitation': [0.0, 0.0],
      'snowfall': [null, null],
      'weather_code': [2, 1],
    },
  },
};

void main() {
  test('searchLocations 走 lookup 并解析 locations[]', () async {
    final auth = _FakeAuthService((_, _) async => _lookupPayload());
    final service = WeatherService(authService: auth);

    final results = await service.searchLocations('杭州');

    expect(results, hasLength(1));
    expect(results.first.name, '杭州市');
    expect(results.first.adcode, '101210101');
    expect(auth.calls.single.action, 'weather');
    expect(auth.calls.single.query, {
      'mode': 'lookup',
      'q': '杭州',
      'number': '10',
    });
  });

  test('关键字不足两个字符时不发请求', () async {
    final auth = _FakeAuthService((_, _) async => _lookupPayload());
    final service = WeatherService(authService: auth);

    expect(await service.searchLocations('杭'), isEmpty);
    expect(await service.searchLocations('  '), isEmpty);
    expect(auth.calls, isEmpty);
  });

  test('reverseGeocode 用 lat/lng 反查并取第一条', () async {
    final auth = _FakeAuthService((_, _) async => _lookupPayload());
    final service = WeatherService(authService: auth);

    final location = await service.reverseGeocode(30.29365, 120.16142);

    expect(location, isNotNull);
    expect(location!.name, '杭州市');
    expect(auth.calls.single.query, {
      'mode': 'lookup',
      'lat': '30.293650',
      'lng': '120.161420',
    });
  });

  test('fetchCurrentWeather 解析 now 的 Amap 兼容字段与 wmo_code', () async {
    final auth = _FakeAuthService((_, _) async => _nowPayload());
    final service = WeatherService(authService: auth);

    final current = await service.fetchCurrentWeather(_hangzhou);

    expect(current, isNotNull);
    expect(current!.text, '多云');
    expect(current.temperatureC, 21);
    expect(current.humidity, 63);
    expect(current.windDirection, '东北风');
    expect(current.windPower, '3');
    expect(current.reportTime, '2026-10-26 22:00:00');
    expect(current.wmoCode, 2);
    expect(auth.calls.single.query?['mode'], 'now');
    expect(auth.calls.single.query?['lat'], '30.293650');
    expect(auth.calls.single.query?['lng'], '120.161420');
    expect(auth.calls.single.query?['label'], '杭州市');
  });

  test('fetchForecast 解析列式 hourly，并用请求坐标作为归属', () async {
    final auth = _FakeAuthService((_, _) async => _hourlyPayload());
    final service = WeatherService(authService: auth);

    final forecast = await service.fetchForecast(_hangzhou);

    expect(forecast, isNotNull);
    expect(forecast!.hourly, hasLength(2));
    expect(forecast.hourly.first.temperatureC, 20);
    expect(
      weatherCategoryFromWmo(forecast.hourly.first.weatherCode!),
      WeatherCategory.partlyCloudy,
    );
    // 服务端回填的格点/城市坐标不能覆盖请求坐标，否则缓存判同城会失败。
    expect(forecast.latitude, _hangzhou.latitude);
    expect(forecast.longitude, _hangzhou.longitude);
    expect(auth.calls.single.query?['mode'], 'hourly');
    expect(auth.calls.single.query?['hours'], WeatherService.hourlyHours);
  });

  test('hourly 的 168h 被服务端判为非法参数时退到 24h', () async {
    var attempts = 0;
    final auth = _FakeAuthService((_, _) async {
      attempts++;
      if (attempts == 1) {
        throw const QhkbCoupleApiException(
          'qhkb_http_failed',
          serverError: 'weather_invalid_params',
        );
      }
      return _hourlyPayload();
    });
    final service = WeatherService(authService: auth);

    final forecast = await service.fetchForecast(_hangzhou);

    expect(forecast, isNotNull);
    expect(auth.calls, hasLength(2));
    expect(auth.calls.first.query?['hours'], '168');
    expect(auth.calls.last.query?['hours'], '24');
  });

  test('网络/会话错误一律降级为 null / 空列表，不向外抛', () async {
    Future<Map<String, dynamic>> failing(String _, Map<String, String>? _) {
      throw const QhkbCoupleApiException('qhkb_session_expired');
    }

    final service = WeatherService(authService: _FakeAuthService(failing));

    expect(await service.searchLocations('杭州'), isEmpty);
    expect(await service.reverseGeocode(30.29, 120.16), isNull);
    expect(await service.fetchCurrentWeather(_hangzhou), isNull);
    expect(await service.fetchForecast(_hangzhou), isNull);
  });

  test('hasSession 反映本地 withU 会话，未连接时不发请求', () async {
    final auth = _FakeAuthService((_, _) async => _lookupPayload());
    final service = WeatherService(authService: auth);

    expect(await service.hasSession(), isFalse);
    expect(auth.calls, isEmpty);

    auth.session = const QhkbCoupleSession(
      username: 'alice',
      sessionId: 'session-id',
      deviceToken: 'device-token',
      csrfToken: 'csrf-token',
    );
    expect(await service.hasSession(), isTrue);
    // 只是探测，不应触发任何天气请求。
    expect(auth.calls, isEmpty);
  });

  test('networkGeocode 不再做 IP 估算', () async {
    final auth = _FakeAuthService((_, _) async => _lookupPayload());
    final service = WeatherService(authService: auth);

    expect(await service.networkGeocode(), isNull);
    expect(auth.calls, isEmpty);
  });

  test('dispose 是空实现，不会关闭共享的认证服务', () {
    final service = WeatherService(
      authService: _FakeAuthService((_, _) async => _lookupPayload()),
    );
    expect(service.dispose, returnsNormally);
  });
}
