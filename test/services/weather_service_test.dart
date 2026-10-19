import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qhkb/models/weather_forecast.dart';
import 'package:qhkb/services/weather_preferences.dart';
import 'package:qhkb/services/weather_service.dart';
import 'package:qhkb/utils/coordinate_transform.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// 测试用的**假**高德 Key。真 Key 从不入库（构建期 `--dart-define=AMAP_KEY` 注入），
/// 这里只是为了让 `isConfigured` 为真、能走到高德的请求与解析分支。
const _fakeAmapKey = 'test-amap-key';

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  country: '中国',
  adcode: '330100',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

/// 真实结构的 Open-Meteo 预报响应（截断到 3 小时）。
Map<String, dynamic> _forecastPayload() => {
  'latitude': 30.263618,
  'longitude': 120.14051,
  'utc_offset_seconds': 28800,
  'timezone': 'Asia/Shanghai',
  'hourly_units': {
    'time': 'iso8601',
    'temperature_2m': '°C',
    'precipitation_probability': '%',
    'precipitation': 'mm',
    'snowfall': 'cm',
    'weather_code': 'wmo code',
  },
  'hourly': {
    'time': ['2026-09-18T08:00', '2026-09-18T09:00', '2026-09-18T10:00'],
    'temperature_2m': [25.1, 25.8, 27.6],
    'precipitation_probability': [8, 0, 42],
    'precipitation': [0.0, 0.0, 0.2],
    'snowfall': [0.0, 0.0, 0.0],
    'weather_code': [3, 2, 61],
  },
};

/// 高德输入提示响应：搜「杭州」会返回多个候选，其中一个公交线路没有坐标。
Map<String, dynamic> _amapTipsPayload() => {
  'status': '1',
  'info': 'OK',
  'infocode': '10000',
  'count': '3',
  'tips': [
    {
      'id': 'B023B0',
      'name': '杭州市',
      'district': '浙江省杭州市',
      'adcode': '330100',
      'location': '120.161400,30.293651',
      'address': '浙江省杭州市',
    },
    {
      // 同名不同地：四川甘孜的杭州村，靠 district / 坐标区分。
      'id': 'B0FFF1',
      'name': '杭州村',
      'district': '四川省甘孜藏族自治州',
      'adcode': '513300',
      'location': '102.195270,30.065170',
    },
    // 畸形条目：公交线路不返回坐标，必须跳过而不是整批失败。
    {'name': '某条公交线路', 'district': '浙江省杭州市'},
  ],
};

/// 高德逆地理响应（杭州市拱墅区）。
Map<String, dynamic> _amapRegeoPayload() => {
  'status': '1',
  'info': 'OK',
  'infocode': '10000',
  'regeocode': {
    'formatted_address': '浙江省杭州市拱墅区',
    'addressComponent': {
      'province': '浙江省',
      'city': '杭州市',
      'district': '拱墅区',
      'adcode': '330105',
      'township': '某街道',
    },
  },
};

/// 高德实况响应。
Map<String, dynamic> _amapLivePayload() => {
  'status': '1',
  'info': 'OK',
  'infocode': '10000',
  'count': '1',
  'lives': [
    {
      'province': '浙江',
      'city': '杭州市',
      'adcode': '330100',
      'weather': '晴',
      'temperature': '23',
      'winddirection': '东南',
      'windpower': '≤3',
      'humidity': '58',
      'reporttime': '2026-09-18 08:00:00',
    },
  ],
};

void main() {
  group('fetchForecast（Open-Meteo，不需要 Key）', () {
    test('解析逐小时各字段', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final forecast = await service.fetchForecast(_hangzhou);
      expect(forecast, isNotNull);
      expect(forecast!.hourly.length, 3);

      final first = forecast.hourly.first;
      expect(first.time, DateTime(2026, 9, 18, 8));
      expect(first.temperatureC, closeTo(25.1, 1e-9));
      expect(first.precipitationProbability, 8);
      expect(first.precipitationMm, closeTo(0.0, 1e-9));
      expect(first.snowfallCm, closeTo(0.0, 1e-9));
      expect(first.weatherCode, 3);

      expect(forecast.hourly.last.weatherCode, 61);
      expect(forecast.hourly.last.precipitationProbability, 42);
    });

    test('经纬度取响应回填的格点中心，便于缓存判同城', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      final forecast = await service.fetchForecast(_hangzhou);
      expect(forecast!.latitude, closeTo(30.263618, 1e-9));
      expect(forecast.longitude, closeTo(120.14051, 1e-9));
    });

    test('请求带上必需参数：变量表、城市时区、回溯与窗口天数', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.fetchForecast(_hangzhou);
      expect(captured, isNotNull);
      expect(captured!.host, 'api.open-meteo.com');
      expect(captured!.path, '/v1/forecast');
      expect(
        captured!.queryParameters['hourly'],
        'temperature_2m,precipitation_probability,precipitation,snowfall,weather_code',
      );
      expect(captured!.queryParameters['timezone'], 'Asia/Shanghai');
      expect(captured!.queryParameters['past_days'], '1');
      expect(captured!.queryParameters['forecast_days'], '16');
      expect(captured!.queryParameters['latitude'], '30.29365');
      expect(captured!.queryParameters['longitude'], '120.16142');
    });

    test('城市没带时区时退回 auto', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.fetchForecast(
        const WeatherLocation(name: '杭州', latitude: 30.29, longitude: 120.16),
      );
      expect(captured!.queryParameters['timezone'], 'auto');
    });

    test('**没有高德 Key 也能取预报**（数据源不依赖 Key）', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      expect(service.isConfigured, isFalse);
      final forecast = await service.fetchForecast(_hangzhou);
      expect(forecast, isNotNull);
      expect(captured!.host, 'api.open-meteo.com');
    });

    test('非 200 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('网络异常返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('超时返回 null 而不抛', () async {
      final service = WeatherService(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('畸形 JSON 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('{not json', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('响应是数组而非对象时返回 null', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('[1,2,3]', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('缺 hourly 块返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'latitude': 30.26, 'longitude': 120.14}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('hourly 块里没有任何小时点返回 null', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'latitude': 30.26,
              'longitude': 120.14,
              'hourly': {'time': <String>[]},
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });
  });

  group('searchLocations（高德输入提示）', () {
    WeatherService keyed(MockClient client) =>
        WeatherService(client: client, amapKey: _fakeAmapKey);

    test('解析候选地点，中文名不乱码且保留行政区与 adcode', () async {
      final service = keyed(
        MockClient(
          (_) async =>
              http.Response(jsonEncode(_amapTipsPayload()), 200, headers: _jsonHeaders),
        ),
      );

      final locations = await service.searchLocations('杭州');
      expect(locations.length, 2);
      expect(locations.first.name, '杭州市');
      expect(locations.first.admin1, '浙江省杭州市');
      expect(locations.first.adcode, '330100');
      expect(locations.first.latitude, closeTo(30.293651, 1e-9));
      expect(locations.first.longitude, closeTo(120.161400, 1e-9));
      expect(locations.last.name, '杭州村');
      expect(
        locations.first.isSamePlaceAs(locations.last),
        isFalse,
        reason: '同名不同地必须靠经纬度区分开',
      );
    });

    test('无坐标的条目被跳过', () async {
      final service = keyed(
        MockClient(
          (_) async =>
              http.Response(jsonEncode(_amapTipsPayload()), 200, headers: _jsonHeaders),
        ),
      );
      final locations = await service.searchLocations('杭州');
      expect(
        locations.any((location) => location.name == '某条公交线路'),
        isFalse,
      );
    });

    test('请求打到高德输入提示，带上 key / keywords / datatype', () async {
      Uri? captured;
      final service = keyed(
        MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_amapTipsPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.searchLocations('杭州');
      expect(captured!.host, 'restapi.amap.com');
      expect(captured!.path, '/v3/assistant/inputtips');
      expect(captured!.queryParameters['key'], _fakeAmapKey);
      expect(captured!.queryParameters['keywords'], '杭州');
      expect(captured!.queryParameters['datatype'], 'poi');
    });

    test('未配置 Key 时不发请求、返回空列表', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );

      expect(await service.searchLocations('杭州'), isEmpty);
      expect(calls, 0);
    });

    test('关键字不足两个字符时不发请求', () async {
      var calls = 0;
      final service = keyed(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );

      expect(await service.searchLocations('杭'), isEmpty);
      expect(await service.searchLocations('   '), isEmpty);
      expect(await service.searchLocations(''), isEmpty);
      expect(calls, 0);
    });

    test('高德 status != 1（Key 无效 / 配额用尽）时返回空列表', () async {
      final service = keyed(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '0',
              'info': 'INVALID_USER_KEY',
              'infocode': '10001',
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });

    test('非 200 返回空列表而不抛', () async {
      final service = keyed(
        MockClient((_) async => http.Response('boom', 500)),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });

    test('网络异常返回空列表而不抛', () async {
      final service = keyed(
        MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });
  });

  group('reverseGeocode（高德逆地理）', () {
    WeatherService keyed(MockClient client) =>
        WeatherService(client: client, amapKey: _fakeAmapKey);

    test('解析出省 / 市 / 区与 adcode（杭州结构）', () async {
      final service = keyed(
        MockClient(
          (_) async =>
              http.Response(jsonEncode(_amapRegeoPayload()), 200, headers: _jsonHeaders),
        ),
      );

      final location = await service.reverseGeocode(30.29365, 120.16142);

      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(location.admin1, '浙江省');
      expect(location.district, '拱墅区');
      expect(location.adcode, '330105');
      expect(location.displayName, '杭州市 · 拱墅区');
      // 时区留空，让预报接口用 timezone=auto 按坐标自行解析。
      expect(location.timezone, isNull);
      // 坐标用入参那一份原始 WGS-84，而不是响应回显、也不是纠偏后送高德的那份。
      expect(location.latitude, closeTo(30.29365, 1e-9));
      expect(location.longitude, closeTo(120.16142, 1e-9));
    });

    test('送高德的坐标已纠偏为 GCJ-02，返回的仍是原始 WGS-84', () async {
      Uri? captured;
      final service = keyed(
        MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_amapRegeoPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      // 北京天安门附近的 WGS-84 坐标（设备定位给的就是这个坐标系）。
      const wgsLatitude = 39.9087;
      const wgsLongitude = 116.3975;
      final (gcjLatitude, gcjLongitude) = wgs84ToGcj02(
        wgsLatitude,
        wgsLongitude,
      );

      final location = await service.reverseGeocode(wgsLatitude, wgsLongitude);

      expect(captured!.host, 'restapi.amap.com');
      expect(captured!.path, '/v3/geocode/regeo');
      expect(captured!.queryParameters['key'], _fakeAmapKey);
      // 请求里的坐标是纠偏后的 GCJ-02（经度在前），不是原始 WGS-84。
      expect(
        captured!.queryParameters['location'],
        '$gcjLongitude,$gcjLatitude',
      );
      expect(
        captured!.queryParameters['location'],
        isNot('$wgsLongitude,$wgsLatitude'),
      );
      // 返回给调用方的坐标保持原始 WGS-84：它要交给 Open-Meteo。
      expect(location!.latitude, closeTo(wgsLatitude, 1e-9));
      expect(location.longitude, closeTo(wgsLongitude, 1e-9));
    });

    test('city 缺失时退到 province', () async {
      final service = keyed(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'regeocode': {
                'addressComponent': {
                  'province': '重庆市',
                  'city': '',
                  'district': '铜梁区',
                },
              },
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(29.86, 106.03);
      expect(location!.name, '重庆市');
      expect(location.district, '铜梁区');
      expect(location.displayName, '重庆市 · 铜梁区');
    });

    test('city 是空数组时同样退到 province（直辖区真实返回形状）', () async {
      // 实测线上：北京东城区的 regeo 里 "city": []——是**空数组**而不是空字符串，
      // 只按空串判断会漏掉，于是直辖市反查不出市名。
      final service = keyed(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'regeocode': {
                'addressComponent': {
                  'province': '北京市',
                  'city': <dynamic>[],
                  'district': '东城区',
                  'adcode': '110101',
                  'township': '东华门街道',
                },
                'formatted_address': '北京市东城区东华门街道',
              },
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(39.91007, 116.40387);
      expect(location, isNotNull);
      expect(location!.name, '北京市');
      expect(location.admin1, '北京市');
      expect(location.district, '东城区');
      expect(location.adcode, '110101');
    });

    test('区名与市名相同时不重复记 district', () async {
      final service = keyed(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'regeocode': {
                'addressComponent': {
                  'province': '重庆市',
                  'city': '铜梁区',
                  'district': '铜梁区',
                },
              },
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(29.86, 106.03);
      expect(location!.district, isNull);
      expect(location.displayName, '铜梁区');
    });

    test('地名全空时返回 null', () async {
      final service = keyed(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'regeocode': {
                'addressComponent': {
                  'province': '   ',
                  'city': '',
                  'district': null,
                },
              },
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      expect(await service.reverseGeocode(30.29, 120.16), isNull);
    });

    test('未配置 Key 时不发请求、返回 null', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );

      expect(await service.reverseGeocode(30.29, 120.16), isNull);
      expect(calls, 0);
    });

    test('非 200 返回 null 而不抛', () async {
      final service = keyed(
        MockClient((_) async => http.Response('nope', 503)),
      );
      expect(await service.reverseGeocode(30.29, 120.16), isNull);
    });

    test('网络异常返回 null 而不抛', () async {
      final service = keyed(
        MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(await service.reverseGeocode(30.29, 120.16), isNull);
    });

    test('超时返回 null 而不抛', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response(
            jsonEncode(_amapRegeoPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );
      expect(await service.reverseGeocode(30.29, 120.16), isNull);
    });

    test('畸形 JSON 返回 null 而不抛', () async {
      final service = keyed(
        MockClient(
          (_) async => http.Response('{not json', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.reverseGeocode(30.29, 120.16), isNull);
    });
  });

  group('geocodeAddress（高德正向地理编码）', () {
    test('地名转坐标，取第一条结果', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'geocodes': [
                {
                  'province': '浙江省',
                  'city': '杭州市',
                  'district': '拱墅区',
                  'adcode': '330105',
                  'location': '120.161400,30.293651',
                  'level': '市',
                },
              ],
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.geocodeAddress('杭州市');
      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(location.admin1, '浙江省');
      expect(location.adcode, '330105');
      expect(location.latitude, closeTo(30.293651, 1e-9));
      expect(location.longitude, closeTo(120.161400, 1e-9));
    });

    test('geocodes 为空时返回 null', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': '1', 'geocodes': <Object>[]}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.geocodeAddress('不存在的地名'), isNull);
    });

    test('district 是空数组时按无区处理（市级地名真实返回形状）', () async {
      // 实测线上：按「杭州市」正向地理编码，geocodes[0].district 是空数组 []。
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'geocodes': [
                {
                  'province': '浙江省',
                  'city': '杭州市',
                  'district': <dynamic>[],
                  'adcode': '330100',
                  'location': '120.209903,30.246566',
                  'level': '市',
                },
              ],
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.geocodeAddress('杭州市');
      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(location.district, isNull);
      expect(location.adcode, '330100');
      // location 是 "经度,纬度"，解析后不能把两个顺序弄反。
      expect(location.latitude, closeTo(30.246566, 1e-9));
      expect(location.longitude, closeTo(120.209903, 1e-9));
    });

    test('未配置 Key 时不发请求、返回 null', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );
      expect(await service.geocodeAddress('杭州市'), isNull);
      expect(calls, 0);
    });
  });

  group('networkGeocode（高德 IP 估算）', () {
    test('用城市矩形范围的中心作为估算坐标', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'province': '浙江省',
              'city': '杭州市',
              'adcode': '330100',
              'rectangle': '119.816,29.912;120.583,30.565',
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.networkGeocode();
      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(location.admin1, '浙江省');
      expect(location.adcode, '330100');
      expect(location.latitude, closeTo((29.912 + 30.565) / 2, 1e-6));
      expect(location.longitude, closeTo((119.816 + 120.583) / 2, 1e-6));
    });

    test('矩形范围缺失时退回正向地理编码', () async {
      final uris = <Uri>[];
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient((request) async {
          uris.add(request.url);
          if (request.url.path == '/v3/ip') {
            return http.Response(
              jsonEncode({
                'status': '1',
                'province': '浙江省',
                'city': '杭州市',
                'adcode': '330100',
              }),
              200,
              headers: _jsonHeaders,
            );
          }
          return http.Response(
            jsonEncode({
              'status': '1',
              'geocodes': [
                {
                  'province': '浙江省',
                  'city': '杭州市',
                  'adcode': '330100',
                  'location': '120.161400,30.293651',
                },
              ],
            }),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      final location = await service.networkGeocode();
      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(uris.map((uri) => uri.path), contains('/v3/geocode/geo'));
    });

    test('未配置 Key 时不发请求、返回 null', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );
      expect(await service.networkGeocode(), isNull);
      expect(calls, 0);
    });

    test('status 为 1 但字段全是空数组时返回 null（实测返回形状）', () async {
      // 实测线上：出口 IP 在境外/机房时，/v3/ip 的 status 仍是 "1"（调用成功），
      // 但 province/city/adcode/rectangle 全是空数组。**不能按 status 判有结果**，
      // 否则拿空数组去解析会得到空地名，甚至把空矩形当坐标。
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'info': 'OK',
              'infocode': '10000',
              'province': <dynamic>[],
              'city': <dynamic>[],
              'adcode': <dynamic>[],
              'rectangle': <dynamic>[],
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      expect(await service.networkGeocode(), isNull);
    });
  });

  group('fetchCurrentWeather（高德实况）', () {
    test('按 adcode 查询并解析实况', () async {
      Uri? captured;
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_amapLivePayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      final current = await service.fetchCurrentWeather(_hangzhou);
      expect(current, isNotNull);
      expect(current!.text, '晴');
      expect(current.temperatureC, 23);
      expect(current.humidity, 58);
      expect(captured!.host, 'restapi.amap.com');
      expect(captured!.path, '/v3/weather/weatherInfo');
      expect(captured!.queryParameters['city'], '330100');
      expect(captured!.queryParameters['extensions'], 'base');
      expect(captured!.queryParameters['key'], _fakeAmapKey);
    });

    test('城市没有 adcode 时返回 null 且不发请求', () async {
      var calls = 0;
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );

      expect(
        await service.fetchCurrentWeather(
          const WeatherLocation(
            name: '杭州',
            latitude: 30.29,
            longitude: 120.16,
          ),
        ),
        isNull,
      );
      expect(calls, 0);
    });

    test('未配置 Key 时不发请求、返回 null', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );
      expect(await service.fetchCurrentWeather(_hangzhou), isNull);
      expect(calls, 0);
    });

    test('解析失败返回 null 而不抛', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': '1',
              'lives': [
                // 缺 temperature：解析抛 FormatException，服务要兜住。
                {'weather': '晴'},
              ],
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchCurrentWeather(_hangzhou), isNull);
    });

    test('lives 为空时返回 null', () async {
      final service = WeatherService(
        amapKey: _fakeAmapKey,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': '1', 'lives': <Object>[]}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchCurrentWeather(_hangzhou), isNull);
    });
  });

  group('WeatherPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认关闭，开关可读写', () async {
      expect(await WeatherPreferences.isEnabled(), isFalse);
      await WeatherPreferences.setEnabled(true);
      expect(await WeatherPreferences.isEnabled(), isTrue);
    });

    test('未设置城市时返回 null', () async {
      expect(await WeatherPreferences.loadLocation(), isNull);
    });

    test('城市往返一致（含 adcode）', () async {
      await WeatherPreferences.saveLocation(_hangzhou);
      final restored = await WeatherPreferences.loadLocation();
      expect(restored, isNotNull);
      expect(restored!.name, '杭州');
      expect(restored.admin1, '浙江');
      expect(restored.adcode, '330100');
      expect(restored.timezone, 'Asia/Shanghai');
      expect(restored.latitude, closeTo(30.29365, 1e-9));
    });

    test('城市数据损坏时按未设置处理', () async {
      SharedPreferences.setMockInitialValues({
        WeatherPreferences.locationKey: 'not json',
      });
      expect(await WeatherPreferences.loadLocation(), isNull);
    });

    test('预报往返一致，清空后回到 null', () async {
      final forecast = WeatherForecast.fromOpenMeteoResponse(
        _forecastPayload(),
        fetchedAt: DateTime(2026, 9, 18, 6, 30),
      );
      expect(forecast.hourly.length, 3);

      await WeatherPreferences.saveForecast(forecast);
      final restored = await WeatherPreferences.loadForecast();
      expect(restored, isNotNull);
      expect(restored!.hourly.length, 3);
      expect(restored.hourly.last.time, DateTime(2026, 9, 18, 10));
      expect(restored.hourly.last.precipitationProbability, 42);
      expect(restored.hourly.last.weatherCode, 61);
      expect(restored.fetchedAt, DateTime(2026, 9, 18, 6, 30));

      await WeatherPreferences.clearForecast();
      expect(await WeatherPreferences.loadForecast(), isNull);
    });

    test('预报缓存损坏时按无缓存处理', () async {
      SharedPreferences.setMockInitialValues({
        WeatherPreferences.forecastKey: '{"latitude":1}',
      });
      expect(await WeatherPreferences.loadForecast(), isNull);
    });
  });
}

/// 用一个本地异常类型代替 dart:io 的 SocketException，避免测试文件依赖 IO。
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: simulated network failure';
}