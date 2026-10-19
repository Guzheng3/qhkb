import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qhkb/services/qhkb_app_update_service.dart';
import 'package:qhkb/services/qhkb_couple_config.dart';

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  test('parses a valid withU update release', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
    });
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'title': 'withU 1.2.3',
            'body': 'fixed scheduling sync',
            'download_url': 'https://qhkb.example.com/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
            'updated_at': '2026-09-07T10:00:00+08:00',
            'force_update': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.2.3');
    expect(result.latestRelease?.title, 'withU 1.2.3');
    expect(result.latestRelease?.forceUpdate, isFalse);
    expect(result.latestRelease?.expectedApkSha256, _sha256);
    expect(requestedUri?.path, '/api/app_update.php');
  });

  test('non-forced ignored version stays silent', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
      QhkbAppUpdateService.ignoredVersionPrefsKey: '1.2.3',
    });
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'https://qhkb.example.com/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isFalse);
  });

  test('forced update overrides the ignored version', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
      QhkbAppUpdateService.ignoredVersionPrefsKey: '1.2.3',
    });
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'https://qhkb.example.com/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
            'force_update': true,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
    expect(result.latestRelease?.forceUpdate, isTrue);
  });

  test('rejects non-HTTPS or malformed downloads', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
    });
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'http://insecure.example.com/app.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isFalse);
  });

  test('rejects download hosts outside the configured withU domain', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
    });
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'https://cdn.example.com/qhkb-1.2.3.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isFalse);
  });

  test('allows HTTP on the same local Android emulator host', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'http://10.0.2.2:8080',
      }),
    });
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'http://10.0.2.2:8080/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
    expect(
      result.latestRelease?.downloadUrl,
      'http://10.0.2.2:8080/uploads/qhkb-1.2.3.apk',
    );
  });

  test('HTTP failures return null', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://qhkb.example.com',
      }),
    });
    final client = MockClient((request) async {
      throw Exception('offline');
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNull);
  });

  test('version comparison orders normal and prerelease versions', () {
    expect(QhkbAppUpdateService.isRemoteNewer('1.2.3', '1.2.2'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('1.0.10', '1.0.9'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('1.2.0', '1.2.0-rc1'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('1.2.0', '1.2.0'), isFalse);
    expect(QhkbAppUpdateService.isRemoteNewer('1.2.0-rc1', '1.2.0'), isFalse);
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.2.0-beta', '1.2.0-alpha'),
      isTrue,
    );
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.2.0-rc.10', '1.2.0-rc.9'),
      isTrue,
    );
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.2.0-rc.2', '1.2.0-rc.10'),
      isFalse,
    );
  });

  test('compares the four-segment release versions this project ships', () {
    // versionName 是四段号（5.2.0.5），pub_semver 解析不了它，曾导致新版本
    // 一律比不出来、云端更新永远提示「已是最新」。
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0.5', '5.2.0.4'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0.4', '5.2.0.5'), isFalse);
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0.10', '5.2.0.9'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0.5', '5.2.0.5'), isFalse);
    expect(QhkbAppUpdateService.isRemoteNewer('v5.2.0.5', '5.2.0.4'), isTrue);
  });

  test('ranks a four-segment version above the three-segment baseline', () {
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0.5', '5.2.0'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('5.2.0', '5.2.0.5'), isFalse);
    expect(QhkbAppUpdateService.isRemoteNewer('1.1.11', '1.1.10.6'), isTrue);
    expect(QhkbAppUpdateService.isRemoteNewer('1.1.10.6', '1.1.11'), isFalse);
  });

  test('maps the pubspec prerelease form onto the fourth segment', () {
    // docs/RELEASE.md 约定：1.1.10-6+36 与 1.1.10.6 视为同一版本。
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.1.10-6+36', '1.1.10.6'),
      isFalse,
    );
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.1.10.6', '1.1.10-6+36'),
      isFalse,
    );
    expect(
      QhkbAppUpdateService.isRemoteNewer('1.1.10-7+37', '1.1.10.6'),
      isTrue,
    );
  });

  test('probes built-in mirrors and selects the faster one', () async {
    SharedPreferences.setMockInitialValues({});
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      if (request.method == 'HEAD') {
        // Simulate the HTTPS mirror responding faster.
        await Future<void>.delayed(
          request.url.host == 'withu.qinghan.vip'
              ? const Duration(milliseconds: 40)
              : Duration.zero,
        );
        return http.Response('', 200);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url':
                'https://qhkb.qinghan.vip/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
    final updateCalls = requestedUrls
        .where((uri) => uri.path == '/api/app_update.php')
        .toList();
    expect(updateCalls, hasLength(1));
    expect(updateCalls.first.host, 'qhkb.qinghan.vip');
  });

  test('custom non-built-in baseUrl skips probing', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'https://my-custom-server.com',
      }),
    });
    final requestedUrls = <Uri>[];
    final requestedMethods = <String>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      requestedMethods.add(request.method);
      if (request.method == 'HEAD') {
        return http.Response('', 200);
      }
      return http.Response(
        jsonEncode({'success': true, 'has_update': false}),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    await service.checkForUpdates(currentVersion: '1.2.2');

    expect(requestedMethods, everyElement('GET'));
    expect(requestedUrls, hasLength(1));
    expect(requestedUrls.first.host, 'my-custom-server.com');
  });

  test('accepts HTTP download URLs for built-in hosts', () async {
    SharedPreferences.setMockInitialValues({
      QhkbCoupleConfig.prefsKey: jsonEncode({
        'baseUrl': 'http://withu.qinghan.vip/',
      }),
    });
    final client = MockClient((request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 200);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'has_update': true,
          'release': {
            'version': '1.2.3',
            'download_url': 'http://withu.qinghan.vip/uploads/qhkb-1.2.3.apk',
            'sha256': _sha256,
          },
        }),
        200,
      );
    });
    final service = QhkbAppUpdateService(client: client);

    final result = await service.checkForUpdates(currentVersion: '1.2.2');

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
    expect(
      result.latestRelease?.downloadUrl,
      'http://withu.qinghan.vip/uploads/qhkb-1.2.3.apk',
    );
  });
}
