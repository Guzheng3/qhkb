import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/domain/weather_logic.dart';
import 'package:qhkb/l10n/app_localizations.dart';
import 'package:qhkb/l10n/weather_category_localizer.dart';

/// 全部 6 个语言的 locale（zh 的三个变体靠 countryCode 区分）。
const _locales = <String, Locale>{
  'zh': Locale('zh'),
  'zh_HK': Locale('zh', 'HK'),
  'zh_TW': Locale('zh', 'TW'),
  'en': Locale('en'),
  'ja': Locale('ja'),
  'ko': Locale('ko'),
};

void main() {
  test('每个分类在每种语言下都有非空文案', () {
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      for (final category in WeatherCategory.values) {
        final label = WeatherCategoryLocalizer.label(l10n, category);
        expect(label.trim(), isNotEmpty, reason: '${entry.key} / $category');
      }
    }
  });

  test('中文下 20 个分类文案互不相同（防拷贝粘贴错行）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final labels = {
      for (final category in WeatherCategory.values)
        WeatherCategoryLocalizer.label(l10n, category),
    };
    expect(labels.length, WeatherCategory.values.length);
  });

  test('各语言的关键现象翻译抽查', () {
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh')),
        WeatherCategory.lightRain,
      ),
      '小雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh')),
        WeatherCategory.snow,
      ),
      '中雪',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('en')),
        WeatherCategory.lightRain,
      ),
      'Light rain',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('ja')),
        WeatherCategory.thunderstorm,
      ),
      '雷雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('ko')),
        WeatherCategory.clear,
      ),
      '맑음',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh', 'HK')),
        WeatherCategory.rainShowers,
      ),
      '陣雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh', 'TW')),
        WeatherCategory.rainShowers,
      ),
      '陣雨',
    );
  });

  test('每种语言的现象名都替换掉了占位符', () {
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      final label = WeatherCategoryLocalizer.label(
        l10n,
        WeatherCategory.lightRain,
      );
      expect(label, isNot(contains('{')), reason: entry.key);
      expect(label.trim(), isNotEmpty, reason: entry.key);
    }
  });
}