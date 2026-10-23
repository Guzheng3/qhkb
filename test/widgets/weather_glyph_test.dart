import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/domain/weather_logic.dart';
import 'package:qhkb/widgets/course_weather_display.dart';
import 'package:qhkb/widgets/weather_glyph.dart';

import '../helpers_test_app.dart';

void main() {
  // 自绘字形只有「画过一次」才能确认它不抛异常：布局与绘制都在 pumpWidget 里跑过
  // 一遍，paint 里的越界、除零、非法几何都会在这里暴露。
  testWidgets('每个字形都能画出来，且占满给定的方块', (tester) async {
    for (final glyph in WeatherGlyph.values) {
      await tester.pumpWidget(
        TestApp(
          home: Center(
            child: WeatherGlyphIcon(
              glyph: glyph,
              size: 20,
              ink: const Color(0xFF334155),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '字形 ${glyph.name} 画不出来');
      expect(
        tester.getSize(find.byType(WeatherGlyphIcon)),
        const Size(20, 20),
        reason: '字形 ${glyph.name} 没有占满方块',
      );
    }
  });

  testWidgets('窄卡尺寸（10 点）下同样可画', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Wrap(
          children: [
            for (final glyph in WeatherGlyph.values)
              WeatherGlyphIcon(
                glyph: glyph,
                size: 10,
                ink: const Color(0xFFFFFFFF),
              ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('墨色亮暗两套配色都能画', (tester) async {
    // 两套配色由墨色明暗选（白墨配深卡、黑墨配浅卡），两条分支都要真的走一遍。
    for (final ink in const [Color(0xFFFFFFFF), Color(0xFF000000)]) {
      await tester.pumpWidget(
        TestApp(
          home: Center(
            child: WeatherGlyphIcon(glyph: WeatherGlyph.rain, size: 24, ink: ink),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '墨色 $ink 下画不出来');
    }
  });

  test('每一档天气现象都有自己的字形', () {
    final glyphs = [
      for (final category in WeatherCategory.values) weatherGlyphFor(category),
    ];

    // 一一对应：既不能两档现象共用一个字形，也不能有哪一档落到温度 / 概率上去。
    expect(glyphs.toSet().length, WeatherCategory.values.length);
    expect(glyphs, isNot(contains(WeatherGlyph.temperature)));
    expect(glyphs, isNot(contains(WeatherGlyph.probability)));
  });
}
