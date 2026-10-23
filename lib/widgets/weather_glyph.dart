import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 天气那一行行首画的东西。
///
/// 天气现象这一族走**自绘字形**（[WeatherGlyphIcon] 里的 `CustomPainter`）：
///
/// - Material 的图标表里没有「云 + 雨」这种组合字形，它给的是单个水滴、雨伞、
///   雪花这些零件，于是「小雨」只能画成一粒水滴、「阵雨」只能画成一把伞——形状
///   与现象对不上；
/// - 那一族零件图标只有描边版，缩到窄卡上的十来个点就只剩一圈灰线。
///
/// 自绘字形按 24×24 的设计网格摆位（见 `_WeatherGlyphPainter` 的 `_grid`），
/// 缩放到任何边长，三个渲染面共用同一套比例，也不引入图标字体或 SVG 资源。
///
/// 前 20 项与 `WeatherCategory` 一一对应（顺序也一致），映射见
/// `lib/widgets/course_weather_display.dart` 的 `weatherGlyphFor`。后两项不是天气
/// 现象，而是同一行可能出现的另外两种内容：它们继续用 Material 图标，那两个形状
/// 本来就有现成的，且与同一张卡上相邻信息行（时间 / 地点）的图标同族。
///
/// 颜色是**固定的一套天气配色**（云冷灰、水蓝、冰青、太阳与闪电暖黄），不跟随主题：
/// 天气现象的含义不该随主题变。能不能在任意卡面看清，交给形状外面那圈墨色轮廓，
/// 见 [_WeatherGlyphPainter] 的 `_haloWidth`。
enum WeatherGlyph {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  freezingDrizzle,
  lightRain,
  rain,
  heavyRain,
  freezingRain,
  rainShowers,
  heavyRainShowers,
  lightSnow,
  snow,
  heavySnow,
  snowGrains,
  snowShowers,
  thunderstorm,
  thunderstormHail,
  temperature,
  probability,
}

/// 天气行行首的图标：天气现象画自绘字形，温度与降水概率回落 Material 图标。
///
/// 尺寸与 [ink] 都由调用方给，本部件不读主题的排版设置：三个渲染面的前景色来源各不
/// 相同（课卡是随卡面自动翻黑白的墨色、详情弹窗是次要文字色），这里只负责把一个
/// 字形画满给定的正方形。
class WeatherGlyphIcon extends StatelessWidget {
  const WeatherGlyphIcon({
    super.key,
    required this.glyph,
    required this.size,
    this.ink,
  });

  final WeatherGlyph glyph;

  /// 字形的边长。字形按这个边长等比缩放，而不是「固定画布再留白」。
  final double size;

  /// 墨色：自绘字形用它画形状外面那圈轮廓，温度 / 概率两个 Material 图标直接用它
  /// 上色。缺省时与 [Icon] 同一条回落链（[IconTheme] → 主题正文色）。
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    return switch (glyph) {
      WeatherGlyph.temperature => Icon(Icons.thermostat, size: size, color: ink),
      WeatherGlyph.probability => Icon(Icons.percent, size: size, color: ink),
      _ => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          // 自绘字形不能用可空墨色，这里按 [Icon] 的口径先把墨色定下来。
          painter: _WeatherGlyphPainter(
            glyph: glyph,
            ink:
                ink ??
                IconTheme.of(context).color ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    };
  }
}

/// 天气现象的两套配色，按课卡墨色的明暗选一套。
///
/// 色相固定（云冷灰、水蓝、冰青、太阳与闪电暖黄），只有明度整档换：白墨说明卡面
/// 偏深，用亮的那套；黑墨说明卡面偏浅，用压深的那套。两套都要各自在自己那类卡面上
/// 有足够对比，所以「深卡上的云」和「浅卡上的云」不是同一个灰。
@immutable
class _GlyphPalette {
  const _GlyphPalette({
    required this.cloud,
    required this.sun,
    required this.sunRay,
    required this.rain,
    required this.ice,
    required this.bolt,
  });

  final Color cloud;
  final Color sun;
  final Color sunRay;
  final Color rain;
  final Color ice;
  final Color bolt;

  /// 深色卡面（白墨）用的一套。
  static const _GlyphPalette onDark = _GlyphPalette(
    cloud: Color(0xFFDCE6F2),
    sun: Color(0xFFFFD24A),
    sunRay: Color(0xFFFFB300),
    rain: Color(0xFF5CB8F5),
    ice: Color(0xFF8FD8F2),
    bolt: Color(0xFFFFC107),
  );

  /// 浅色卡面（黑墨）用的一套：整体压深，浅色填充在浅卡上会糊掉。
  static const _GlyphPalette onLight = _GlyphPalette(
    cloud: Color(0xFF8FA6BF),
    sun: Color(0xFFF2A900),
    sunRay: Color(0xFFD98E00),
    rain: Color(0xFF1E86D6),
    ice: Color(0xFF2E9BC9),
    bolt: Color(0xFFE0A000),
  );
}

/// 自绘天气字形。
///
/// 每个形状都画两遍：先按 [_haloWidth] 加粗描一圈**墨色**轮廓，再填上它自己的颜色。
/// 轮廓用的是课卡那支自动翻黑白的墨色，所以「卡面是用户自选的任意颜色」这件事不会
/// 把某个形状吞掉——浅卡上深色的云、深卡上发亮的雪、橙黄卡上的太阳，边界都靠它兜住；
/// 填充本身再按墨色明暗从 [_GlyphPalette] 里选一套，保证颜色对得上卡面。
/// 两遍必须紧挨着画同一条路径：轮廓是描在路径上的，靠形状自己的填充盖掉内圈那一半，
/// 留下的才是「外面多一圈」。
///
/// 形状全部按 24×24 网格写死坐标，绘制前整体缩放到实际边长——每个字形的相对比例
/// 因此与尺寸无关：窄卡上 10 点的图标与详情弹窗里 18 点的图标是同一套比例。
/// 各字形的墨迹都收在网格内，四周至少留一格余量，描边的圆头不至于溢出给定方块而
/// 蹭到旁边的文字。
///
/// 形状之间的间距按「详情弹窗那档尺寸下分得开」定：窄卡上只有十来个像素，同族的
/// 雨丝、雪花、冰粒之间的缝必然不足一个像素而被抗锯齿抹平，那一刻起能辨认的是整个
/// 轮廓（云下面挂的是斜丝、圆点还是星形），不再数得清几条。
class _WeatherGlyphPainter extends CustomPainter {
  const _WeatherGlyphPainter({required this.glyph, required this.ink});

  final WeatherGlyph glyph;

  /// 墨色：画轮廓用，也用来决定取哪套配色。
  final Color ink;

  /// 轮廓宽度（24 网格）：每个形状往外交出这么多格。
  ///
  /// 0.6 是两头折中的结果：窄卡上 10 点约合 0.25 像素，只够把边「定」出来，不会把
  /// 图标变成一圈描线；而橙黄这类与太阳撞色的卡面上，靠它才分得开。
  static const double _haloWidth = 0.6;

  /// 这一遍用哪套配色。
  _GlyphPalette get _palette =>
      ink.computeLuminance() > 0.5 ? _GlyphPalette.onDark : _GlyphPalette.onLight;

  /// 设计网格边长。
  static const double _grid = 24;

  /// 云的高度是宽度的这个比例。
  ///
  /// 取 0.62 而不是更扁的 0.5：云是这个字形族的主体，太扁会像一条横杠。
  static const double _cloudHeightRatio = 0.62;

  /// 云下那一族（雨 / 雪 / 冰粒 / 雷）共用的云：宽度与中心纵坐标。
  ///
  /// 固定下来是为了让这一族字形的重心落在同一处——相邻两节课的图标一个偏高、
  /// 一个偏低会很显眼。
  static const double _cloudWidth = 17;
  static const double _cloudCenterY = 9.3;

  /// 云下那一排符号的顶端纵坐标（雨丝从这条线往下画）与雨丝的倾斜量。
  static const double _belowTop = 15.2;
  static const double _slant = 0.32;

  /// 闪电的宽与高。
  static const double _boltWidth = 4.8;
  static const double _boltHeight = 6.4;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) {
      return;
    }
    canvas.save();
    // 先挪到方块中心，再按边长缩放：调用方给的是正方形，这里对非正方形也成立。
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / _grid);
    _paintGlyph(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeatherGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.ink != ink;

  /// 按字形拼装。
  ///
  /// 每个分支只调下面那几个构形方法，坐标都是 24 网格里的常量：想知道某个字形长
  /// 什么样，读它那一行就够了。
  void _paintGlyph(Canvas canvas) {
    switch (glyph) {
      case WeatherGlyph.clear:
        _paintSun(canvas, center: const Offset(12, 12), radius: 4.5);
      // 晴间多云 / 多云：太阳躲在云后面。两者只差太阳与云的大小比例，这也是天气
      // 应用里区分这两档的通行画法。
      case WeatherGlyph.mainlyClear:
        _paintSun(canvas, center: const Offset(9, 10.2), radius: 3.4);
        _paintCloud(
          canvas,
          center: const Offset(15, 15.6),
          width: 11.6,
          alpha: 0.95,
        );
      case WeatherGlyph.partlyCloudy:
        _paintSun(canvas, center: const Offset(8.4, 9.6), radius: 3.2);
        _paintCloud(canvas, center: const Offset(14.8, 15.2), width: 12.6);
      // 阴：两朵云。后面那朵压暗并挪向左上，两朵的轮廓才分得开。
      case WeatherGlyph.overcast:
        _paintCloud(
          canvas,
          center: const Offset(9.6, 9.4),
          width: 13.4,
          alpha: 0.55,
        );
        _paintCloud(canvas, center: const Offset(13.8, 14.4), width: 15.4);
      case WeatherGlyph.fog:
        _paintFog(canvas);
      // 降水颗粒这一族（毛毛雨 / 冻毛毛雨 / 米雪）只剩云下那一排东西可辨认：粒子的大小、
      // 疏密与错落是唯一能在小尺寸上分出来的差别。毛毛雨那几粒还刻意错开高度——三粒
      // 并排的圆点会被读成一张脸。
      case WeatherGlyph.drizzle:
        _paintBigCloud(canvas);
        _paintDots(
          canvas,
          points: const [
            Offset(8.2, 17),
            Offset(12, 18.6),
            Offset(15.8, 17),
          ],
          radius: 1.4,
          color: _palette.rain,
        );
      case WeatherGlyph.freezingDrizzle:
        _paintBigCloud(canvas);
        _paintDots(
          canvas,
          points: const [Offset(9, 18)],
          radius: 1.45,
          color: _palette.rain,
        );
        _paintFlake(canvas, center: const Offset(15, 17.9), radius: 2.2);
      // 小雨 / 中雨 / 大雨：雨丝越多越长。云的大小区分不出一眼可辨的差别，条数与
      // 长度是通行画法里唯一「扫一眼就能排大小」的维度。
      case WeatherGlyph.lightRain:
        _paintRain(canvas, xs: const [9.4, 14.8], length: 4.4);
      case WeatherGlyph.rain:
        _paintRain(canvas, xs: const [8, 12, 16.2]);
      case WeatherGlyph.heavyRain:
        _paintRain(canvas, xs: const [6.3, 10.6, 14.9, 19.2], length: 5.2);
      // 冻雨：一滴雨 + 一片雪花，雪花是「会结冰」的那一半信息。
      case WeatherGlyph.freezingRain:
        _paintRain(canvas, xs: const [9.2], flakeAt: 15.4);
      // 阵雨 / 阵雪：太阳、云、云下的雨丝或雪花同框——这是它与「中雨」的唯一区别。
      case WeatherGlyph.rainShowers:
        _paintShowers(canvas, xs: const [10.4, 16.2], snow: false);
      case WeatherGlyph.heavyRainShowers:
        _paintShowers(canvas, xs: const [8.4, 11.2, 15, 17.8], snow: false);
      case WeatherGlyph.snowShowers:
        _paintShowers(canvas, xs: const [10.4, 16.2], snow: true);
      case WeatherGlyph.lightSnow:
        _paintSnow(canvas, xs: const [12], radius: 2.6);
      case WeatherGlyph.snow:
        _paintSnow(canvas, xs: const [8.8, 15.2], radius: 2.5);
      case WeatherGlyph.heavySnow:
        _paintSnow(canvas, xs: const [5.9, 12, 18.1], radius: 2);
      // 米雪：三粒更大、压得更低的冰粒，靠大小与高度与毛毛雨的小点分开。
      case WeatherGlyph.snowGrains:
        _paintBigCloud(canvas);
        _paintDots(
          canvas,
          points: const [
            Offset(7.3, 16.6),
            Offset(12, 18.4),
            Offset(16.7, 16.6),
          ],
          radius: 1.6,
          color: _palette.ice,
        );
      // 雷阵雨：闪电先画、云后画，闪电的根部因此被云吃掉，看着是从云里打出来的。
      case WeatherGlyph.thunderstorm:
        _paintBolt(canvas, origin: const Offset(9.4, 13));
        _paintBigCloud(canvas);
      case WeatherGlyph.thunderstormHail:
        _paintBolt(canvas, origin: const Offset(8.4, 13));
        _paintBigCloud(canvas);
        _paintDots(
          canvas,
          points: const [Offset(15.6, 17.4)],
          radius: 1.8,
          color: _palette.ice,
        );
      // 温度与降水概率由 [WeatherGlyphIcon] 用 Material 图标画掉，走不到这里。
      case WeatherGlyph.temperature || WeatherGlyph.probability:
        return;
    }
  }

  /// 轮廓色：课卡墨色，浓度跟着形状自己的深浅走——阴天后面那朵云压暗，它的轮廓
  /// 也一起淡下去，否则半透明的云会罩上一圈实心黑边。
  Color _haloColor(double alpha) => ink.withValues(alpha: ink.a * alpha);

  /// 给一个实心形状垫轮廓：[path] 加粗描边，随后必须紧接着用 [_fill] 画同一个形状。
  void _haloPath(Canvas canvas, Path path, {double alpha = 1}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = _haloColor(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _haloWidth * 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 给一条线垫轮廓：同一条线画粗一圈。[width] 是线本身的宽度。
  void _haloLine(
    Canvas canvas,
    Offset from,
    Offset to,
    double width, {
    double alpha = 1,
  }) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = _haloColor(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + _haloWidth * 2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 本色填充笔。[alpha] 是这一族自己的深浅（阴的后云 0.55、雾的下横线 0.5……）。
  Paint _fill(Color color, {double alpha = 1}) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;

  /// 本色描边笔；[width] 是 24 网格里的宽度，会随字形一起缩放。
  ///
  /// 圆头端点（[StrokeCap.round]）是必须的：雨丝、雪花、雾条、日芒全是短线，
  /// 平头端点在小尺寸下一端会被抗锯齿啃掉半格，看着像脏点。
  Paint _stroke(double width, Color color, {double alpha = 1}) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// 太阳：实心圆盘 + 八道短日芒（上下左右略长，四个斜向略短）。
  ///
  /// 长短交替比等长更像太阳：等长的八道芒会形成一个规整的齿轮，反而像设置图标。
  /// 八道日芒的轮廓要先一次性铺完，再连同圆盘一起上色：日芒的根部压在圆盘里，
  /// 后铺的轮廓会在盘面上留下几道墨色缺口。
  void _paintSun(
    Canvas canvas, {
    required Offset center,
    required double radius,
  }) {
    // 日芒的起点落在圆盘边线**以内**：圆头端点因此与圆盘连成一体。起点留在盘外会
    // 留下八根短棒与圆盘之间的一圈缝，缩到窄卡上就是四点孤立像素，太阳看着像散架。
    final inner = radius * 1.18;
    final rays = <(Offset, Offset)>[];
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      rays.add((
        center + direction * inner,
        center + direction * (inner + radius * (i.isEven ? 0.72 : 0.48)),
      ));
    }
    final width = radius * 0.5;
    for (final (from, to) in rays) {
      _haloLine(canvas, from, to, width);
    }
    _haloPath(canvas, Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawCircle(center, radius, _fill(_palette.sun));
    for (final (from, to) in rays) {
      canvas.drawLine(from, to, _stroke(width, _palette.sunRay));
    }
  }

  /// 云：一条圆角长条（云底）+ 三个圆瓣（云顶）。
  ///
  /// 三个圆瓣一个比一个靠右、中间那个最高，轮廓才有起伏；三瓣都收在长条两端以内，
  /// 整朵云只有一个外轮廓（同一支画笔一次描边，重叠处不留接缝）。
  void _paintCloud(
    Canvas canvas, {
    required Offset center,
    required double width,
    double alpha = 1,
  }) {
    final height = width * _cloudHeightRatio;
    final left = center.dx - width / 2;
    final top = center.dy - height / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top + height * 0.44, width, height * 0.56),
          Radius.circular(height * 0.28),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(left + width * 0.27, top + height * 0.58),
          radius: height * 0.4,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(left + width * 0.53, top + height * 0.4),
          radius: height * 0.4,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(left + width * 0.75, top + height * 0.6),
          radius: height * 0.4,
        ),
      );
    _haloPath(canvas, path, alpha: alpha);
    canvas.drawPath(path, _fill(_palette.cloud, alpha: alpha));
  }

  /// 云下那一族共用的那朵云。
  void _paintBigCloud(Canvas canvas) {
    _paintCloud(
      canvas,
      center: const Offset(12, _cloudCenterY),
      width: _cloudWidth,
    );
  }

  /// 雨：云 + 若干条斜雨丝。[flakeAt] 不为空时再补一片雪花（冻雨）。
  void _paintRain(
    Canvas canvas, {
    required List<double> xs,
    double length = 4.8,
    double? flakeAt,
  }) {
    _paintBigCloud(canvas);
    for (final x in xs) {
      _paintDrop(canvas, top: Offset(x, _belowTop), length: length);
    }
    if (flakeAt != null) {
      _paintFlake(canvas, center: Offset(flakeAt, 17.4), radius: 2.4);
    }
  }

  /// 雪：云 + 若干片雪花。
  void _paintSnow(
    Canvas canvas, {
    required List<double> xs,
    required double radius,
  }) {
    _paintBigCloud(canvas);
    for (final x in xs) {
      _paintFlake(canvas, center: Offset(x, 17.4), radius: radius);
    }
  }

  /// 阵雨 / 阵雪：太阳、云、云下的雨丝或雪花同框。
  ///
  /// 这一族的云比 [_paintBigCloud] 那朵小一圈，太阳才有地方露出来；否则三样东西
  /// 挤在一起，缩到窄卡上只剩一团墨。云下那一排也压得更低，雪花才不会顶进云里。
  void _paintShowers(
    Canvas canvas, {
    required List<double> xs,
    required bool snow,
  }) {
    _paintSun(canvas, center: const Offset(9, 9.6), radius: 3);
    _paintCloud(canvas, center: const Offset(14.6, 14), width: 11.8);
    for (final x in xs) {
      if (snow) {
        _paintFlake(canvas, center: Offset(x, 19.9), radius: 1.95);
      } else {
        _paintDrop(canvas, top: Offset(x, 18.3), length: 3.6);
      }
    }
  }

  /// 雪花：三条过圆心的短线，六个尖。
  ///
  /// 不画六条独立的短枝：窄卡上（约 2 点）六条枝会粘成一团，三条贯穿线反而还能
  /// 看出是个星形。线宽比别的笔画粗一档（0.45r）：云是实心块，雪花是细线，等粗的
  /// 话雪花在云旁边会明显发灰、看着比云小一号。
  ///
  /// 三条线在圆心重叠，所以同样先铺完轮廓再上色，免得后画的一条把轮廓压在先画的
  /// 那条身上、圆心处攒出一小团墨。
  void _paintFlake(
    Canvas canvas, {
    required Offset center,
    required double radius,
  }) {
    final width = radius * 0.45;
    final segments = <(Offset, Offset)>[];
    for (var i = 0; i < 3; i++) {
      final angle = math.pi / 2 + i * math.pi / 3;
      final offset = Offset(math.cos(angle), math.sin(angle)) * radius;
      segments.add((center - offset, center + offset));
    }
    for (final (from, to) in segments) {
      _haloLine(canvas, from, to, width);
    }
    for (final (from, to) in segments) {
      canvas.drawLine(from, to, _stroke(width, _palette.ice));
    }
  }

  /// 雨丝：一条向右下斜的短线。斜向是雨与冰粒、雾条的分界。
  void _paintDrop(
    Canvas canvas, {
    required Offset top,
    required double length,
  }) {
    final bottom = top + Offset(-length * _slant, length);
    final width = length * 0.4;
    _haloLine(canvas, top, bottom, width);
    canvas.drawLine(top, bottom, _stroke(width, _palette.rain));
  }

  /// 降水颗粒（毛毛雨、米雪、冰雹）：实心圆点。[color] 由调用方给——毛毛雨算雨，
  /// 米雪与冰雹算冰。
  void _paintDots(
    Canvas canvas, {
    required List<Offset> points,
    required double radius,
    required Color color,
  }) {
    for (final point in points) {
      _haloPath(
        canvas,
        Path()..addOval(Rect.fromCircle(center: point, radius: radius)),
      );
    }
    for (final point in points) {
      canvas.drawCircle(point, radius, _fill(color));
    }
  }

  /// 闪电：一个实心的折线多边形。
  ///
  /// 顶点按 [_boltWidth] × [_boltHeight] 的比例给，形状随尺寸缩放；画实心而不描边，
  /// 是因为它在窄卡上只有两三个像素宽，描边多边形会细到看不见。
  void _paintBolt(Canvas canvas, {required Offset origin}) {
    Offset at(double fx, double fy) =>
        origin + Offset(_boltWidth * fx, _boltHeight * fy);
    final points = [
      at(0.6, 0),
      at(0, 0.53),
      at(0.42, 0.53),
      at(0.19, 1),
      at(1, 0.41),
      at(0.54, 0.41),
    ];
    final path = Path()..addPolygon(points, true);
    _haloPath(canvas, path);
    canvas.drawPath(path, _fill(_palette.bolt));
  }

  /// 雾：一朵云 + 云下两条渐短的横线。
  ///
  /// 只画三条横线会被读成一个「菜单」图标；带上一朵云才明确是「贴地的云」。两条线
  /// 一长一短，都与云留出一点空隙，底下的那条更淡——层次靠这两点做出来。
  void _paintFog(Canvas canvas) {
    _paintCloud(canvas, center: const Offset(12, 8.8), width: 15.4);
    _paintBar(canvas, y: 15.6, width: 15, alpha: 0.7);
    _paintBar(canvas, y: 19.4, width: 10.6, alpha: 0.5);
  }

  void _paintBar(
    Canvas canvas, {
    required double y,
    required double width,
    required double alpha,
  }) {
    final from = Offset(12 - width / 2, y);
    final to = Offset(12 + width / 2, y);
    _haloLine(canvas, from, to, 3.1, alpha: alpha);
    canvas.drawLine(from, to, _stroke(3.1, _palette.cloud, alpha: alpha));
  }
}
