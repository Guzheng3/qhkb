import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qhkb/blackbox_adapters.dart';
import 'package:qhkb/services/app_http_client.dart';
import 'package:qhkb/services/holiday_service.dart';

void main() {
  setUp(resetAppHttpClientForTesting);
  tearDown(resetAppHttpClientForTesting);

  test('creates an owned client before BlackBox setup', () {
    final client = createAppHttpClient();
    expect(client, isA<http.Client>());
    expect(isSharedAppHttpClient(client), isFalse);
    client.close();
  });

  test('installs the observing client as the shared service client', () {
    final adapter = HttpBlackBoxAdapter();
    addTearDown(adapter.client.close);

    setupAppHttpClientForBlackBox(adapter.client);

    final client = createAppHttpClient();
    expect(identical(client, adapter.client), isTrue);
    expect(isSharedAppHttpClient(client), isTrue);
  });

  test('does not close the shared client when a service is disposed', () {
    final adapter = HttpBlackBoxAdapter();
    addTearDown(adapter.client.close);

    setupAppHttpClientForBlackBox(adapter.client);
    final service = HolidayService();

    service.dispose();

    expect(identical(createAppHttpClient(), adapter.client), isTrue);
  });
}
