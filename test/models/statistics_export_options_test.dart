import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/models/statistics_export_options.dart';

void main() {
  group('StatisticsExportOptions', () {
    test('defaults exclude ranking and include the rest', () {
      final options = StatisticsExportOptions.defaults();

      expect(options.modules, StatisticsExportOptions.defaultModules);
      expect(options.modules.contains(StatisticsExportModule.ranking), isFalse);
      expect(options.modules.contains(StatisticsExportModule.overview), isTrue);
      expect(options.hasModules, isTrue);
    });

    test('allModules contains every enum value', () {
      expect(
        StatisticsExportOptions.allModules,
        StatisticsExportModule.values.toSet(),
      );
    });

    test('hasModules is false for empty selection', () {
      const options = StatisticsExportOptions(modules: {});
      expect(options.hasModules, isFalse);
    });

    test('copyWith replaces modules set', () {
      final original = StatisticsExportOptions.defaults();
      final updated = original.copyWith(
        modules: {StatisticsExportModule.ranking},
      );

      expect(updated.modules, {StatisticsExportModule.ranking});
      expect(original.modules, isNot(updated.modules));
    });
  });

  group('StatisticsExportBrand', () {
    test('exposes stable public brand urls', () {
      expect(
        StatisticsExportBrand.websiteUrl,
        contains('qhkb.qinghan.vip'),
      );
      expect(StatisticsExportBrand.websiteDisplay, 'qhkb.qinghan.vip');
      expect(StatisticsExportBrand.githubUrl, contains('Guzheng3/qhkb'));
      expect(StatisticsExportBrand.githubDisplay, 'github.com/Guzheng3/qhkb');
    });
  });
}
