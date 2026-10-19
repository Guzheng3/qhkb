import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/l10n/app_localizations_zh.dart';
import 'package:qhkb/l10n/app_localizations_en.dart';
import 'package:qhkb/l10n/app_localizations_ja.dart';
import 'package:qhkb/l10n/app_localizations_ko.dart';

void main() {
  group('Localization completeness', () {
    test('qhkbCoupleUsernameLabel exists in all supported locales', () {
      final zh = AppLocalizationsZh();
      expect(
        zh.qhkbCoupleUsernameLabel,
        isNotEmpty,
        reason: 'zh: qhkbCoupleUsernameLabel should not be empty',
      );

      final en = AppLocalizationsEn();
      expect(
        en.qhkbCoupleUsernameLabel,
        isNotEmpty,
        reason: 'en: qhkbCoupleUsernameLabel should not be empty',
      );

      final ja = AppLocalizationsJa();
      expect(
        ja.qhkbCoupleUsernameLabel,
        isNotEmpty,
        reason: 'ja: qhkbCoupleUsernameLabel should not be empty',
      );

      final ko = AppLocalizationsKo();
      expect(
        ko.qhkbCoupleUsernameLabel,
        isNotEmpty,
        reason: 'ko: qhkbCoupleUsernameLabel should not be empty',
      );
    });

    test('ARB files contain qhkbCoupleUsernameLabel key', () {
      final arbFiles = [
        'lib/l10n/app_zh.arb',
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ja.arb',
        'lib/l10n/app_ko.arb',
        'lib/l10n/app_zh_TW.arb',
        'lib/l10n/app_zh_HK.arb',
      ];

      for (final arbFile in arbFiles) {
        final file = File(arbFile);
        if (!file.existsSync()) {
          continue;
        }

        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(
          json.containsKey('qhkbCoupleUsernameLabel'),
          isTrue,
          reason: '$arbFile should contain qhkbCoupleUsernameLabel',
        );
        expect(
          json['qhkbCoupleUsernameLabel'],
          isNotEmpty,
          reason: '$arbFile: qhkbCoupleUsernameLabel should not be empty',
        );
      }
    });
  });
}
