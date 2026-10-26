import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/domain/weather_logic.dart';
import 'package:qhkb/models/weather_forecast.dart';
import 'package:qhkb/providers/weather_provider.dart';
import 'package:qhkb/services/device_location_service.dart';
import 'package:qhkb/services/weather_preferences.dart';
import 'package:qhkb/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers_location_stub.dart';

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  adcode: '330100',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

const _chengdu = WeatherLocation(
  name: '成都',
  admin1: '四川',
  adcode: '510100',
  latitude: 30.5728,
  longitude: 104.0668,
  timezone: 'Asia/Shanghai',
);

/// 造一份窗口覆盖「今天 0 点起 96 小时」的预报。
///
/// 窗口很关键：`hasLapsedAt(now)` 一旦为真就会一直判过期，TTL 类断言会失真。
WeatherForecast _forecast({
  double latitude = 30.29365,
  double longitude = 120.16142,
  DateTime? fetchedAt,
}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final hourly = <HourlyWeatherPoint>[
    for (var hour = 0; hour < 96; hour++)
      HourlyWeatherPoint(
        time: start.add(Duration(hours: hour)),
        temperatureC: 20.0 + (hour % 5),
        precipitationProbability: 60,
        precipitationMm: 0.5,
        snowfallCm: 0,
        weatherCode: 61,
      ),
  ];
  return WeatherForecast(
    latitude: latitude,
    longitude: longitude,
    fetchedAt: fetchedAt ?? DateTime.now(),
    hourly: hourly,
  );
}

/// 可计数的假天气服务。
///
/// 服务端契约尚未落地，生产实现是空壳；Provider 的策略测试需要一个能按城市
/// 返回数据、能计数、能卡住请求的替身，就在这里显式造一个。
class _FakeWeatherService extends WeatherService {
  _FakeWeatherService({this.fail = false, this.configured = true});

  bool fail;
  bool configured;

  /// `fetchForecast` 的调用次数（Provider 的 TTL / 退避断言只看这个）。
  int calls = 0;
  final List<WeatherLocation> forecastRequests = [];
  final List<WeatherLocation> currentRequests = [];
  final List<String> searchQueries = [];

  WeatherLocation? reverseResult;
  WeatherLocation? networkResult;
  CurrentWeather? current = const CurrentWeather(
    text: '晴',
    temperatureC: 23,
    humidity: 58,
  );
  List<WeatherLocation> searchResults = const [
    WeatherLocation(
      name: '杭州',
      admin1: '浙江省杭州市',
      adcode: '330100',
      latitude: 30.293651,
      longitude: 120.16142,
    ),
  ];

  /// 是否有 withU 会话；未连接时的天气请求应被 Provider 直接跳过。
  bool sessionAvailable = true;

  /// 卡住 `fetchForecast` 的闸门；为 null 时立即返回。
  Completer<void>? forecastGate;

  /// 自定义单次预报结果；为 null 时返回 [_forecast]。
  Future<WeatherForecast?> Function(WeatherLocation location)? onForecast;

  @override
  Future<bool> hasSession() async => sessionAvailable;

  @override
  Future<WeatherForecast?> fetchForecast(WeatherLocation location) async {
    calls++;
    forecastRequests.add(location);
    final gate = forecastGate;
    if (gate != null) {
      await gate.future;
    }
    if (fail) {
      return null;
    }
    final custom = onForecast;
    if (custom != null) {
      return custom(location);
    }
    return _forecast(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  @override
  Future<CurrentWeather?> fetchCurrentWeather(WeatherLocation location) async {
    currentRequests.add(location);
    if (!configured || fail) {
      return null;
    }
    return current;
  }

  @override
  Future<List<WeatherLocation>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (!configured || trimmed.length < 2) {
      return const <WeatherLocation>[];
    }
    searchQueries.add(trimmed);
    return searchResults;
  }

  @override
  Future<WeatherLocation?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (!configured || fail) {
      return null;
    }
    return reverseResult;
  }

  @override
  Future<WeatherLocation?> networkGeocode() async {
    if (!configured || fail) {
      return null;
    }
    return networkResult;
  }
}

/// 今天（与 [_payload] 的窗口起点同一天）的一个课程时刻。
DateTime get _today => DateTime.now();
String _timeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

CourseWeatherSummary? _summaryOf(WeatherProvider provider, {int hour = 8}) {
  return provider.summaryForCourse(
    date: _today,
    startTime: _timeOfDay(hour, 0),
    endTime: _timeOfDay(hour + 1, 35),
  );
}

Future<void> _seed({
  bool enabled = true,
  WeatherLocation? location = _hangzhou,
  WeatherForecast? forecast,
}) async {
  await WeatherPreferences.setEnabled(enabled);
  if (location != null) {
    await WeatherPreferences.saveLocation(location);
  }
  if (forecast != null) {
    await WeatherPreferences.saveForecast(forecast);
  }
}

/// 定位反查会得到的地点。
const _located = WeatherLocation(
  name: '成都市',
  admin1: '四川省',
  country: '中国',
  district: '武侯区',
  latitude: 30.5728,
  longitude: 104.0668,
);

/// 定位源固定在 [_located] 的坐标上（断言「请求打在新坐标上」要用）。
///
/// `fix: null` 表示实时定位拿不到，流程会退到 IP 估算那条路。
StubDeviceLocationSource _source({bool serviceEnabled = true, bool hasFix = true}) =>
    StubDeviceLocationSource(
      serviceEnabled: serviceEnabled,
      fix: hasFix
          ? const DeviceFix(
              latitude: 30.5728,
              longitude: 104.0668,
              accuracyMeters: 12,
              source: 'network',
            )
          : null,
    );

DeviceLocationService _locationService(
  StubDeviceLocationSource source, {
  required WeatherLocation? resolvesTo,
  WeatherLocation? estimatesTo,
}) => stubLocationService(
  resolvesTo: resolvesTo,
  estimatesTo: estimatesTo,
  source: source,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('一键定位', () {
    test('成功：换城市、落盘、重拉预报、清空失败原因', () async {
      await _seed();
      final server = _FakeWeatherService();
      final source = _source();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(source, resolvesTo: _located),
      );
      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.location!.name, '杭州');
      final callsBefore = server.calls;

      final failure = await provider.locateCurrentPosition();
      // 定位成功后 provider 是在后台重拉预报的（界面不该等网络），测试里补一次
      // await 把它落定；单飞会返回同一个在飞的 future。
      await provider.ensureFresh();

      expect(failure, isNull);
      expect(provider.lastLocateFailure, isNull);
      expect(provider.isLocating, isFalse);
      // 真实定位成功 → 绝不能标成估算。
      expect(provider.lastLocateWasEstimated, isFalse);
      expect(provider.location!.name, '成都市');
      expect(provider.location!.district, '武侯区');
      expect(provider.location!.displayName, '成都市 · 武侯区');
      // 换了城市 → 旧预报作废并重拉，且请求打在新坐标上。
      expect(server.calls, greaterThan(callsBefore));
      expect(server.forecastRequests.last.latitude, _located.latitude);
      // 也落了盘：重启后不必重新定位。
      final persisted = await WeatherPreferences.loadLocation();
      expect(persisted!.district, '武侯区');
    });

    test('失败：记录原因，且**不动**用户原来选好的城市', () async {
      await _seed();
      final server = _FakeWeatherService();
      final source = _source();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(source, resolvesTo: null),
      );
      await provider.initialize();
      await provider.ensureFresh();
      final original = provider.location!;

      final failure = await provider.locateCurrentPosition();

      expect(failure, DeviceLocationFailure.addressUnavailable);
      expect(provider.lastLocateFailure, DeviceLocationFailure.addressUnavailable);
      // 失败时也不该残留上一次的「估算」标记。
      expect(provider.lastLocateWasEstimated, isFalse);
      expect(provider.location!.name, original.name);
      expect(provider.location!.latitude, original.latitude);
      final persisted = await WeatherPreferences.loadLocation();
      expect(persisted!.name, original.name);
    });

    test('实时定位拿不到 → 退到 IP 估算，并把结果标记为估算', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(
          _source(hasFix: false),
          resolvesTo: _located,
          estimatesTo: _located,
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.location!.name, '杭州');

      final failure = await provider.locateCurrentPosition();
      await provider.ensureFresh();

      expect(failure, isNull);
      // 这一步是关键：界面靠它决定要不要加「按网络估算」的提示。
      expect(provider.lastLocateWasEstimated, isTrue);
      expect(provider.location!.name, '成都市');
      // 估算同样是有效结果：照常换城市、落盘。
      final persisted = await WeatherPreferences.loadLocation();
      expect(persisted!.name, '成都市');
    });

    test('实时定位与 IP 估算都拿不到 → timeout，且不动原城市', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(
          _source(hasFix: false),
          resolvesTo: _located,
          // estimatesTo 默认 null：模拟网络估算也不可用。
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        await provider.locateCurrentPosition(),
        DeviceLocationFailure.timeout,
      );
      expect(provider.lastLocateWasEstimated, isFalse);
      expect(provider.location!.name, '杭州');
    });

    test('系统定位开关没开时透传 serviceDisabled', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(
          _source(serviceEnabled: false),
          resolvesTo: _located,
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        await provider.locateCurrentPosition(),
        DeviceLocationFailure.serviceDisabled,
      );
      expect(provider.location!.name, '杭州');
    });

    test('连点两次只跑一次（单飞）', () async {
      await _seed();
      final server = _FakeWeatherService();
      final source = _source();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(source, resolvesTo: _located),
      );
      await provider.initialize();
      await provider.ensureFresh();

      final first = provider.locateCurrentPosition();
      final second = provider.locateCurrentPosition();
      final results = await Future.wait([first, second]);

      expect(source.fixCalls, 1);
      expect(results, [isNull, isNull]);
    });

    test('定位期间 isLocating 为 true 并通知监听者，结束后复位', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        locationService: _locationService(
          _source(),
          resolvesTo: _located,
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      var notifications = 0;
      provider.addListener(() => notifications++);

      final future = provider.locateCurrentPosition();
      // 同步就能看到「进行中」——界面据此立刻禁用入口。
      expect(provider.isLocating, isTrue);

      await future;
      expect(provider.isLocating, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('失败后再点会重试，成功后清空失败原因', () async {
      await _seed();
      final server = _FakeWeatherService();
      var resolves = false;
      final provider = WeatherProvider(
        service: server,
        locationService: DeviceLocationService(
          reverseGeocode: (_, _) async => resolves ? _located : null,
          networkGeocode: () async => null,
          source: _source(),
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        await provider.locateCurrentPosition(),
        DeviceLocationFailure.addressUnavailable,
      );
      expect(provider.lastLocateFailure, isNotNull);

      resolves = true;
      expect(await provider.locateCurrentPosition(), isNull);
      expect(provider.lastLocateFailure, isNull);
      expect(provider.location!.name, '成都市');
    });
  });

  group('初始化', () {
    test('没有城市时 summaryForCourse 返回 null 且一次请求都不发', () async {
      await _seed(location: null);
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 0);
      expect(_summaryOf(provider), isNull);
      expect(provider.status, WeatherStatus.idle);
    });

    test('开关关闭时不发请求，summaryForCourse 返回 null', () async {
      await _seed(enabled: false);
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 0);
      expect(_summaryOf(provider), isNull);
    });

    test('有城市且开关打开时拉一次，之后能取到摘要', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(provider.status, WeatherStatus.ready);
      final summary = _summaryOf(provider);
      expect(summary, isNotNull);
      expect(summary!.category, WeatherCategory.lightRain);
      expect(summary.precipitationProbability, 60);
      expect(summary.showPrecipitationProbability, isTrue);
    });

    test('缓存被读回，重启后不必等网络就有数据', () async {
      final cached = _forecast(fetchedAt: DateTime.now());
      await _seed(forecast: cached);

      final hanging = _FakeWeatherService()
        ..forecastGate = Completer<void>();
      final provider = WeatherProvider(service: hanging);

      await provider.initialize();
      // 刻意不 await ensureFresh：验证首帧就有数据，不等网络。
      expect(_summaryOf(provider), isNotNull);
    });

    test('缓存城市与所选城市不一致时被丢弃', () async {
      final cached = _forecast(
        latitude: _chengdu.latitude,
        longitude: _chengdu.longitude,
        fetchedAt: DateTime.now(),
      );
      // 所选城市用 _seed 的默认值（杭州），而缓存是成都的。
      await _seed(forecast: cached);

      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        // 把时钟推远，让「过期就刷」在这次 initialize 里不会补上数据。
        clock: () => DateTime.now().add(const Duration(hours: 4)),
      );

      await provider.initialize();
      expect(provider.forecast, isNull);
    });

    test('重复 initialize 只生效一次', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
    });

    test('未 initialize 时 summaryForCourse 返回 null 而不是抛', () {
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);
      expect(_summaryOf(provider), isNull);
    });
  });

  group('预留位判据 isAwaitingData', () {
    /// 一次永不返回的请求，用来把 provider 停在「正在加载」上。
    WeatherProvider hangingProvider({Completer<void>? pending}) {
      final gate = pending ?? Completer<void>();
      return WeatherProvider(
        service: _FakeWeatherService()..forecastGate = gate,
      );
    }

    test('已选城市、正在拉、没有预报 → true（界面据此留位）', () async {
      await _seed();
      final gate = Completer<void>();
      final provider = hangingProvider(pending: gate);

      await provider.initialize();

      expect(provider.forecast, isNull);
      expect(provider.status, WeatherStatus.loading);
      expect(provider.isAwaitingData, isTrue);

      // 数据到了就不再留位：那一行本来就画得出内容，留着只是白占地方。
      gate.complete();
      await provider.ensureFresh();

      expect(provider.status, WeatherStatus.ready);
      expect(provider.isAwaitingData, isFalse);
    });

    test('没选城市 → false（数据不会自己来，留位会变成永久空行）', () async {
      await _seed(location: null);
      final provider = hangingProvider();

      await provider.initialize();

      expect(provider.isAwaitingData, isFalse);
    });

    test('总开关关着 → false', () async {
      await _seed(enabled: false);
      final provider = hangingProvider();

      await provider.initialize();

      expect(provider.isAwaitingData, isFalse);
    });

    test('请求失败且无缓存 → false（退避期内那 15 分钟不会自己好）', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(provider.status, WeatherStatus.failed);
      expect(provider.forecast, isNull);
      expect(provider.isAwaitingData, isFalse);
    });

    test('有缓存预报时即便正在刷新也是 false（画得出内容就不留位）', () async {
      final cached = _forecast(fetchedAt: DateTime.now());
      await _seed(forecast: cached);
      final provider = hangingProvider();

      await provider.initialize();

      expect(provider.forecast, isNotNull);
      expect(provider.isAwaitingData, isFalse);
    });

    test('未 initialize 时为 false（开关还没读出来，不给没开天气的人凭空留空行）',
        () {
      final provider = hangingProvider();
      expect(provider.isAwaitingData, isFalse);
    });
  });

  group('刷新策略', () {
    test('ensureFresh 连调三次只发一次（单飞）', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      final first = provider.ensureFresh();
      final second = provider.ensureFresh();
      final third = provider.ensureFresh();
      await Future.wait([first, second, third]);

      expect(server.calls, 1);
    });

    test('未连接 withU 时不发请求；登录后下一次 ensureFresh 立刻重试', () async {
      await _seed();
      final server = _FakeWeatherService()..sessionAvailable = false;
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 0);
      expect(provider.status, WeatherStatus.failed);
      expect(provider.forecast, isNull);

      server.sessionAvailable = true;
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('登录态变为已连接时立刻补拉一次', () async {
      await _seed();
      final server = _FakeWeatherService()..sessionAvailable = false;
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 0);

      server.sessionAvailable = true;
      provider.onSessionChanged(true);
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('TTL 内不再发请求', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(
        service: server,
        clock: () => DateTime.now().add(const Duration(hours: 2)),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.ensureFresh();
      await provider.ensureFresh();
      expect(server.calls, 1);
    });

    test('超过 TTL 会重拉', () async {
      await _seed();
      final server = _FakeWeatherService();
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      offset = const Duration(hours: 4);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });

    test('预报窗口走完会重拉', () async {
      await _seed();
      final server = _FakeWeatherService();
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      // 窗口是今天 0 点起 96 小时，推到第 100 小时即已走完。
      offset = const Duration(hours: 100);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });
  });

  group('失败降级', () {
    test('失败且无缓存：状态为 failed，摘要为 null，不抛', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(provider.status, WeatherStatus.failed);
      expect(_summaryOf(provider), isNull);
      expect(provider.forecast, isNull);
    });

    test('失败但有缓存：旧数据继续用，卡片不受影响', () async {
      final cached = _forecast(
        fetchedAt: DateTime.now().subtract(const Duration(hours: 6)),
      );
      await _seed(forecast: cached);
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(provider.status, WeatherStatus.failed);
      expect(_summaryOf(provider), isNotNull);
    });

    test('失败后进入退避，退避期内不再撞服务器', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.ensureFresh();
      await provider.ensureFresh();
      expect(server.calls, 1);
    });

    test('退避过期后会再试', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      offset = WeatherProvider.failureRetryDelay + const Duration(minutes: 1);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });

    test('retry 清掉退避并立即重试', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.retry();
      expect(server.calls, 2);
    });

    test('retry 在恢复成功后转为 ready', () async {
      await _seed();
      final server = _FakeWeatherService(fail: true);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.status, WeatherStatus.failed);

      server.fail = false;
      await provider.retry();
      expect(provider.status, WeatherStatus.ready);
      expect(_summaryOf(provider), isNotNull);
    });
  });

  group('设置变更', () {
    test('打开开关时补拉数据', () async {
      await _seed(enabled: false);
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      expect(server.calls, 0);

      await provider.setEnabled(true);
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('关闭开关后 summaryForCourse 立即返回 null', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(_summaryOf(provider), isNotNull);

      await provider.setEnabled(false);
      expect(_summaryOf(provider), isNull);
    });

    test('换城市会作废旧缓存并立刻重拉', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);
      expect(server.forecastRequests.single.latitude, _hangzhou.latitude);

      await provider.setLocation(_chengdu);
      await provider.ensureFresh();

      expect(server.calls, 2);
      expect(server.forecastRequests.last.latitude, _chengdu.latitude);
      expect(_summaryOf(provider), isNotNull);
    });

    test('换城市后磁盘上留下的必须是新城市的数', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      final beforeSwitch = await WeatherPreferences.loadForecast();
      expect(beforeSwitch!.latitude, closeTo(_hangzhou.latitude, 1e-6));

      await provider.setLocation(_chengdu);
      await provider.ensureFresh();

      // 假服务端把请求坐标回填进响应，所以落盘的坐标就是「这份数据是谁的」。
      final onDisk = await WeatherPreferences.loadForecast();
      expect(onDisk, isNotNull);
      expect(onDisk!.latitude, closeTo(_chengdu.latitude, 1e-6));
      expect(onDisk.longitude, closeTo(_chengdu.longitude, 1e-6));
    });

    test('换城市时在飞的旧城市响应不得冒充新城市', () async {
      // provider 自己的注释说这是「最坏的一种错」：跨启动那一道
      // matchesLocation 守卫能挡住，同一次会话里挡不住 —— 因为
      // `ensureFresh` 的单飞槽还挂着旧城市那条请求，
      // setLocation 拿到的就是它，旧响应回来后既进内存又落盘。
      await _seed();
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final service = _FakeWeatherService();
      service.onForecast = (location) async {
        if (service.calls == 1) {
          if (!firstStarted.isCompleted) {
            firstStarted.complete();
          }
          await releaseFirst.future;
        }
        return _forecast(
          latitude: location.latitude,
          longitude: location.longitude,
        );
      };
      final provider = WeatherProvider(service: service);

      await provider.initialize();
      await firstStarted.future;
      await provider.setLocation(_chengdu);
      // 旧城市（杭州）的响应现在才到达。
      releaseFirst.complete();
      await provider.ensureFresh();

      final memory = provider.forecast;
      expect(memory, isNotNull);
      expect(
        memory!.latitude,
        closeTo(_chengdu.latitude, 1e-6),
        reason: '在飞的旧城市响应被写进内存，课表卡会拿杭州的天气冒充成都',
      );
      final onDisk = await WeatherPreferences.loadForecast();
      expect(
        onDisk!.latitude,
        closeTo(_chengdu.latitude, 1e-6),
        reason: '同样那份旧城市数据还会落盘',
      );
      expect(service.calls, greaterThanOrEqualTo(2));
    });

    test('选同一个地点不重拉（幂等）', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.setLocation(_hangzhou);
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('重复设置同一个开关值不触发请求', () async {
      await _seed(enabled: false);
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.setEnabled(false);
      await provider.ensureFresh();

      expect(server.calls, 0);
    });

    test('设置变更会通知监听者', () async {
      await _seed(enabled: false);
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);
      await provider.initialize();

      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setEnabled(true);
      expect(notifications, greaterThan(0));
    });
  });

  group('城市搜索转发', () {
    test('服务端不可用时返回空列表且不转发', () async {
      await _seed();
      final server = _FakeWeatherService(configured: false);
      final provider = WeatherProvider(service: server);
      await provider.initialize();
      await provider.ensureFresh();
      final callsBefore = server.calls;

      expect(await provider.searchLocations('杭州'), isEmpty);
      expect(server.calls, callsBefore);
      expect(server.searchQueries, isEmpty);
    });

    test('转发给 service 并返回候选', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);
      await provider.initialize();

      final results = await provider.searchLocations('杭州');
      expect(results, isNotEmpty);
      expect(results.first.name, '杭州');
      expect(results.first.adcode, '330100');
      expect(server.searchQueries, ['杭州']);
    });

    test('关键字不足两个字符时转发也不发请求', () async {
      await _seed();
      final server = _FakeWeatherService();
      // 刻意不 initialize：避免后台「过期就刷」混进请求计数。
      final provider = WeatherProvider(service: server);

      expect(await provider.searchLocations('杭'), isEmpty);
      expect(await provider.searchLocations('  '), isEmpty);
      expect(server.calls, 0);
      expect(server.searchQueries, isEmpty);
    });
  });

  group('summaryForCourse 入参防御', () {
    test('畸形的时间串返回 null', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        provider.summaryForCourse(
          date: _today,
          startTime: 'oops',
          endTime: '09:35',
        ),
        isNull,
      );
      expect(
        provider.summaryForCourse(
          date: _today,
          startTime: '08:00',
          endTime: '25:00',
        ),
        isNull,
      );
    });

    test('预报窗口之外的日子返回 null', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        provider.summaryForCourse(
          date: _today.add(const Duration(days: 30)),
          startTime: '08:00',
          endTime: '09:35',
        ),
        isNull,
      );
    });
  });

  group('服务端实况（currentWeather）', () {
    test('刷新会带回实况', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(provider.currentWeather, isNotNull);
      expect(provider.currentWeather!.text, '晴');
      expect(provider.currentWeather!.temperatureC, 23);
    });

    test('服务端不可用时实况为 null（预报仍可用）', () async {
      await _seed();
      final server = _FakeWeatherService(configured: false);
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();

      expect(provider.currentWeather, isNull);
      expect(_summaryOf(provider), isNotNull);
    });

    test('换城市后会重取实况（不残留旧城市的数）', () async {
      await _seed();
      final server = _FakeWeatherService();
      final provider = WeatherProvider(service: server);

      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.currentWeather, isNotNull);
      final before = server.currentRequests.length;

      await provider.setLocation(_chengdu);
      await provider.ensureFresh();

      expect(server.currentRequests.length, greaterThan(before));
      expect(provider.currentWeather, isNotNull);
    });
  });
}