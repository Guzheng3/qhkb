import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qhkb/models/weather_forecast.dart';
import 'package:qhkb/services/app_log_service.dart';
import 'package:qhkb/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归钉：天气失败日志把坐标 / 高德 Key 写进可导出的日志。
///
/// `WeatherService._getJson`（weather_service.dart）任何异常都
/// `_logFailure(tag, error, stackTrace)`，而 `_logFailure` 把**异常对象文本**交给
/// `AppLogService.warn(error: …)`，落盘与导出都不做任何抹除。
///
/// 异常文本里为什么一定带坐标 / Key：http 的 `ClientException.toString()` 会把
/// **完整请求 URL**拼进去（`ClientException: $message, uri=$uri`），而本服务的
/// URL 查询串就带 `latitude=&longitude=`（Open-Meteo 预报）、`location=lng,lat`
/// （高德逆地理，拿的是**设备定位**）与 `key=`（高德明文 Key）。`app_runtime.log`
/// 正是让用户导出、发群、附在 issue 里的那份文件。
///
/// 这两类值都必须抹掉：坐标是家 / 学校的精确位置，Key 一旦外流可被他人冒用配额。
/// 抹除实现见 `WeatherService._withoutCoordinates`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tempCoordinates = '30.2936512';
  const tempCoordinatesEast = '120.1614213';

  /// 测试用的**假**高德 Key；真 Key 从不入库。
  const fakeAmapKey = 'test-amap-key';

  late Directory tempDir;
  late MethodChannel pathProviderChannel;

  setUp(() async {
    AppLogService.instance.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('qhkb-weather-log-');
    pathProviderChannel = const MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => tempDir.path,
        );
    // 关掉开关的话本用例只会「假绿」——什么都不写，自然也不含坐标 / Key。
    // 显式打开，不依赖任何 prefs 形状。
    SharedPreferences.setMockInitialValues({});
    await AppLogService.instance.initialize();
    await AppLogService.instance.updateLoggingEnabled(true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 抛出一条**真实形状**的失败：http 会把请求 URL 拼进异常文本。
  ///
  /// 用 `request.url`（服务自己造的那条，含 Key 与坐标），而不是硬编码 URL——
  /// 后者会让「抹除」这件事在 URL 变了之后静默失去意义。
  WeatherService serviceThrowing({String? amapKey}) => WeatherService(
    amapKey: amapKey,
    client: MockClient((request) async {
      throw http.ClientException(
        'Connection failed (OS Error: Network is unreachable, '
        'address = ${request.url.host}, port = 443)',
        request.url,
      );
    }),
  );

  Future<String> writtenLogs() => AppLogService.instance.readAppLogsText();

  test('预报请求失败时，落盘日志不留查询串里的坐标', () async {
    final forecast = await serviceThrowing().fetchForecast(
      const WeatherLocation(
        name: '杭州',
        admin1: '浙江',
        country: '中国',
        latitude: 30.2936512,
        longitude: 120.1614213,
        timezone: 'Asia/Shanghai',
      ),
    );

    expect(forecast, isNull);
    final logs = await writtenLogs();
    // 缝隙被命中的证据：这一行确实写进去了。
    expect(logs, contains('weather_forecast_failed'));
    expect(logs, contains('error='), reason: '失败日志必须仍然留痕');
    expect(logs, isNot(contains(tempCoordinates)));
    expect(logs, isNot(contains(tempCoordinatesEast)));
    expect(logs, isNot(contains('latitude=3')));
    expect(logs, contains('latitude=**'));
    // 丢坐标不等于丢诊断：域名与原因还得在。
    expect(logs, contains('api.open-meteo.com'));
    expect(logs, contains('Network is unreachable'));
  });

  test('设备定位反查失败时，落盘日志不留 GPS 坐标与高德 Key', () async {
    final location = await serviceThrowing(
      amapKey: fakeAmapKey,
    ).reverseGeocode(30.2936512, 120.1614213);

    expect(location, isNull);
    final logs = await writtenLogs();
    expect(logs, contains('weather_reverse_geocode_failed'));
    expect(logs, isNot(contains(tempCoordinates)));
    expect(logs, isNot(contains(tempCoordinatesEast)));
    expect(logs, isNot(contains('location=3')));
    expect(logs, contains('location=**'));
    // Key 同样要抹掉：明文 Key 一旦随日志外流，可被他人冒用配额。
    expect(logs, isNot(contains(fakeAmapKey)));
    expect(logs, contains('key=**'));
    expect(logs, contains('restapi.amap.com'));
  });

  test('IP 估算失败：坐标本就不带，但 Key 仍要抹掉', () async {
    final location = await serviceThrowing(
      amapKey: fakeAmapKey,
    ).networkGeocode();

    expect(location, isNull);
    final logs = await writtenLogs();
    expect(logs, contains('weather_network_geocode_failed'));
    expect(logs, isNot(contains(fakeAmapKey)));
    expect(logs, contains('key=**'));
    expect(
      logs,
      contains('restapi.amap.com/v3/ip'),
      reason: '域名与路径保留，诊断信息不丢',
    );
  });
}