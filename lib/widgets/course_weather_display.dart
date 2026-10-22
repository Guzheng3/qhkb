import 'package:flutter/material.dart';

import '../domain/weather_logic.dart';
import '../l10n/app_localizations.dart';
import '../l10n/weather_category_localizer.dart';
import 'weather_glyph.dart';

/// 天气现象 → 字形。
///
/// 放在 widget 层而不是 domain：字形本身就是 `lib/widgets/weather_glyph.dart` 里的
/// 一套自绘形状，而 `lib/domain` 被 `test/architecture/dependency_guards_test.dart`
/// 禁止依赖 UI 框架与 widget 层。
///
/// 映射是穷尽的（`switch` 覆盖 `WeatherCategory` 的每一项）：将来加一档天气现象，
/// 这里会直接编译不过，而不是悄悄回落成某个不相干的形状。
WeatherGlyph weatherGlyphFor(WeatherCategory category) => switch (category) {
  WeatherCategory.clear => WeatherGlyph.clear,
  WeatherCategory.mainlyClear => WeatherGlyph.mainlyClear,
  WeatherCategory.partlyCloudy => WeatherGlyph.partlyCloudy,
  WeatherCategory.overcast => WeatherGlyph.overcast,
  WeatherCategory.fog => WeatherGlyph.fog,
  WeatherCategory.drizzle => WeatherGlyph.drizzle,
  WeatherCategory.freezingDrizzle => WeatherGlyph.freezingDrizzle,
  WeatherCategory.lightRain => WeatherGlyph.lightRain,
  WeatherCategory.rain => WeatherGlyph.rain,
  WeatherCategory.heavyRain => WeatherGlyph.heavyRain,
  WeatherCategory.freezingRain => WeatherGlyph.freezingRain,
  WeatherCategory.rainShowers => WeatherGlyph.rainShowers,
  WeatherCategory.heavyRainShowers => WeatherGlyph.heavyRainShowers,
  WeatherCategory.lightSnow => WeatherGlyph.lightSnow,
  WeatherCategory.snow => WeatherGlyph.snow,
  WeatherCategory.heavySnow => WeatherGlyph.heavySnow,
  WeatherCategory.snowGrains => WeatherGlyph.snowGrains,
  WeatherCategory.snowShowers => WeatherGlyph.snowShowers,
  WeatherCategory.thunderstorm => WeatherGlyph.thunderstorm,
  WeatherCategory.thunderstormHail => WeatherGlyph.thunderstormHail,
};

/// 天气行要画的东西：一个图标 + 一行已经本地化好的文字。
///
/// 做成值对象而不是两个并列参数（`weatherGlyph` + `weatherText`），是因为它俩必须
/// 同进同出——三个渲染面（日视图课卡、周视图课卡、课程详情弹窗）都只判断
/// 「有没有这个对象」，不会出现「有文字没图标」的半截状态。
///
/// [isReserved] 为 true 时表示「先占住位置、内容到了再填」：数据还没到手，但这一格
/// 确实该有天气（判据是 `WeatherProvider.isAwaitingData`）。见 [CourseWeatherDisplay.reserved]
/// 与 [reserveWeatherSpace]。
@immutable
class CourseWeatherDisplay {
  const CourseWeatherDisplay({required this.glyph, required this.text})
    : isReserved = false;

  /// 预留的空位：图标用来撑高度、文字留空，整体由调用方包进 [reserveWeatherSpace]。
  ///
  /// 文字给**空串**而不是空格：三个面给文字的约束都不看内容（等宽栅格 / 单行
  /// 省略号 / 单行标题），一个空串照样占一行高度，与真行等高。
  const CourseWeatherDisplay.reserved()
    : glyph = weatherPlaceholderGlyph,
      text = '',
      isReserved = true;

  final WeatherGlyph glyph;
  final String text;

  /// 这是不是一块「先占位置、内容到了再填」的空位。
  final bool isReserved;

  @override
  bool operator ==(Object other) =>
      other is CourseWeatherDisplay &&
      other.glyph == glyph &&
      other.text == text &&
      other.isReserved == isReserved;

  @override
  int get hashCode => Object.hash(glyph, text, isReserved);
}

/// 这一行的图标：由**第一个勾上的内容项**认领（「认领」原则见
/// [courseWeatherDisplayFor]）。
///
/// 优先级 = 设置页里三项的排列顺序 = 文字里的拼接顺序，三处保持一致，用户读到的
/// 顺序与看到的图标不会打架。
///
/// 走到这里时至少有一项会渲染，所以一定有项目能认领图标；三项全关的情形在调用方
/// 就已经返回 null 了。
WeatherGlyph _glyphFor({
  required WeatherCategory category,
  required bool showPhenomenon,
  required bool showTemperature,
}) {
  if (showPhenomenon) {
    return weatherGlyphFor(category);
  }
  if (showTemperature) {
    return WeatherGlyph.temperature;
  }
  // 只剩降水概率这一项（且已确认可用，否则整行不渲染）。
  //
  // 用百分号而不是雨点：雨点是「下雨」那一族字形的一部分，用户刚把现象关掉，
  // 再画个雨点等于把现象从后门放回来。
  return WeatherGlyph.probability;
}

/// 「数据还没到、但这一格该留位置」时占位用的字形。
///
/// **它永远不会被画出来**（调用点把整行包进 [reserveWeatherSpace]），存在的唯一
/// 理由是撑住与真天气行一样的高度。
const WeatherGlyph weatherPlaceholderGlyph = WeatherGlyph.overcast;

/// 把一行天气包成「预留的空位」：**留着位置，但不画、不出声、不接触摸**。
///
/// [reserved] 为 false 时原样返回 [child]，所以调用点可以直接把真行/占位行一起
/// 传进来，不必写条件展开。
///
/// 为什么用 [Visibility] 而不是 `SizedBox(height: …)`：这一行的高度在三个面各不
/// 相同（日视图是图标行，周视图按字号推导），写死数字必然有某个面对不上，而「对不上」
/// 的表现正是这次要消灭的那一下顶动。
///
/// 三个 maintain 标记必须一起给（本版 Flutter 的 `Visibility` 有断言：
/// `maintainSize` 要求 `maintainAnimation`，后者要求 `maintainState`）。真正起作用的
/// 是 `maintainSize`——它让子树照常参与布局却整棵跳过绘制。语义与触摸**刻意**用
/// 默认值（false）：空位对读屏软件不存在，也点不到。
Widget reserveWeatherSpace({required bool reserved, required Widget child}) {
  if (!reserved) {
    return child;
  }
  return Visibility(
    visible: false,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: child,
  );
}

/// 这一行的文字写多长。
///
/// 三个渲染面的宽度差着一个量级：日视图课卡与课程详情弹层宽得能写一整句，
/// 而周视图的格子（7 天模式下扣掉图标只剩约 27 点，默认字号 8 时约合三个汉字）
/// 连长一点的单一项都勉强。所以宽度不同的面取不同的密度。
enum WeatherTextDensity {
  /// 勾上的项全写，用分隔符连成一句（`小雨 · 23° · 60%`）。
  full,

  /// 只写一项，**温度优先**；温度没勾时退回图标认领者那一项的文字。
  ///
  /// 为什么温度优先：它是三项里最短的（`23°`），也是唯一一个「一眼就能用」的
  /// 数——现象已经由图标表达了，再写一遍等于同一件事说两遍。
  ///
  /// 为什么「退回」是 `parts.first` 而不是另写一套优先级：图标认领者本来就是
  /// 第一个勾上的项（现象 → 温度 → 概率），温度没勾时它落到的正是 `parts.first`，
  /// 于是「文字写哪一项」与「图标是谁」在 compact 下始终同源，不会打架。
  compact,
}

/// 摘要 + 三个内容开关 → 要画的那一行；不该画时返回 null。
///
/// **「认领」原则**：这一行画出来的每一样东西，都必须有一个勾上的开关认领它，
/// 认领不到的东西不画。文字各归各的开关；图标只有一个位置，所以按固定优先级
/// （现象 → 温度 → 概率）由第一个勾上的项认领，形状跟着那一项走
/// （天气字形 / 温度计 / 百分号），见 [_glyphFor]。
///
/// 这条原则的价值在于把三种「整行消失」统一成同一句话，而不是三个特例：
/// - [summary] 为 null（没开天气 / 没挂 provider / 该日超出 16 天预报窗口）
///   —— 一条数据都没有，没有东西可被认领；
/// - 三个开关全关 —— 没有任何勾上的项；
/// - 只勾了降水概率而它不可用（全缺报 / 低于显示阈值）—— 唯一勾上的项产不出东西。
///
/// 调用方据此**整行不渲染**，不留空档。唯一的例外是「这一格确实该有天气、只是数据
/// 还没到」（`WeatherProvider.isAwaitingData`）：那时调用点改画一块**等高但看不见**
/// 的空位（`CourseWeatherDisplay.reserved()` + [reserveWeatherSpace]），数据到达时
/// 只换内容、不动几何。
///
/// [textDensity] 只改**文字写几项**，不改「画不画」——两种密度下整行消失的条件、
/// 以及图标认领的结果完全一致（见 [WeatherTextDensity]）。所以它不影响任何
/// 「有没有天气行」的判定，只是同一个值对象在窄面少写几个字。
CourseWeatherDisplay? courseWeatherDisplayFor({
  required AppLocalizations l10n,
  required CourseWeatherSummary? summary,
  required bool showPhenomenon,
  required bool showTemperature,
  required bool showProbability,
  WeatherTextDensity textDensity = WeatherTextDensity.full,
}) {
  if (summary == null) {
    return null;
  }
  if (!showPhenomenon && !showTemperature && !showProbability) {
    return null;
  }
  final probability = summary.precipitationProbability;
  final probabilityUsable =
      showProbability &&
      summary.showPrecipitationProbability &&
      probability != null;

  final phenomenonPart = showPhenomenon
      ? WeatherCategoryLocalizer.label(l10n, summary.category)
      : null;
  final temperaturePart = showTemperature
      ? l10n.weatherTemperatureValue(summary.temperatureC)
      : null;
  final probabilityPart = probabilityUsable
      ? l10n.weatherProbabilityValue(probability)
      : null;

  final parts = [
    phenomenonPart,
    temperaturePart,
    probabilityPart,
  ].whereType<String>().toList();
  if (parts.isEmpty) {
    // 只剩「勾了降水概率但这节课没有可用概率」这一种组合会走到这里。
    return null;
  }

  return CourseWeatherDisplay(
    glyph: _glyphFor(
      category: summary.category,
      showPhenomenon: showPhenomenon,
      showTemperature: showTemperature,
    ),
    text: switch (textDensity) {
      WeatherTextDensity.full => parts.join(l10n.weatherSummarySeparator),
      WeatherTextDensity.compact => temperaturePart ?? parts.first,
    },
  );
}