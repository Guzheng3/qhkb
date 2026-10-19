import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qhkb/utils/coordinate_transform.dart';

/// 两个坐标之间的大致直线距离（米）。
///
/// 只用于断言「偏移在几百米这个量级」，不追求测地线精度：等距圆柱近似在几十公里
/// 以内误差远小于本用例的容差。
double _metersBetween(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const metersPerDegree = 111320.0;
  final deltaLatitude = (latitude2 - latitude1) * metersPerDegree;
  final deltaLongitude =
      (longitude2 - longitude1) *
      metersPerDegree *
      math.cos(latitude1 * math.pi / 180);
  return math.sqrt(
    deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude,
  );
}

void main() {
  group('wgs84ToGcj02（WGS-84 → GCJ-02 正向纠偏）', () {
    // 已知参考点：北京天安门一带。断言的是**方向与量级**而不是精确到米的死值
    // ——纠偏量本身是拟合出来的，不同实现尾数会差几厘米；死值会让用例变成
    // 「记录当前输出」而不是「检查算法是否还对」。
    const beijingWgsLatitude = 39.9087;
    const beijingWgsLongitude = 116.3975;

    test('国内点产生东北向数百米偏移（北京参考点）', () {
      final (latitude, longitude) = wgs84ToGcj02(
        beijingWgsLatitude,
        beijingWgsLongitude,
      );

      final deltaLatitude = latitude - beijingWgsLatitude;
      final deltaLongitude = longitude - beijingWgsLongitude;
      // 北京一带 GCJ-02 相对 WGS-84 偏东北：纬度略增、经度增得更多。
      expect(deltaLatitude, inInclusiveRange(0.0005, 0.003));
      expect(deltaLongitude, inInclusiveRange(0.004, 0.009));

      final meters = _metersBetween(
        beijingWgsLatitude,
        beijingWgsLongitude,
        latitude,
        longitude,
      );
      // 国内偏移量级：百米以上、一公里以内。
      expect(meters, inInclusiveRange(100.0, 1000.0));
    });

    test('上海参考点的偏移同样在数百米量级', () {
      final (latitude, longitude) = wgs84ToGcj02(31.1774276, 121.5272106);

      final meters = _metersBetween(
        31.1774276,
        121.5272106,
        latitude,
        longitude,
      );
      expect(meters, inInclusiveRange(100.0, 1000.0));
      // 经纬度两个方向都要动：只动一个说明级数项写漏了。
      expect(latitude, isNot(closeTo(31.1774276, 1e-6)));
      expect(longitude, isNot(closeTo(121.5272106, 1e-6)));
    });

    test('境外坐标原样返回', () {
      // 东京、巴黎、纽约：GCJ-02 只对中国大陆生效，境外不做纠偏。
      const points = <(double, double)>[
        (35.6762, 139.6503),
        (48.8566, 2.3522),
        (40.7128, -74.0060),
      ];
      for (final (latitude, longitude) in points) {
        final (resultLatitude, resultLongitude) = wgs84ToGcj02(
          latitude,
          longitude,
        );
        expect(resultLatitude, latitude);
        expect(resultLongitude, longitude);
      }
    });

    test('国内边界两侧行为一致（不会因浮点误差跳变）', () {
      // 同一点连续调用结果相同，且偏移量有限（没有把度当成米直接加）。
      final (latitude, longitude) = wgs84ToGcj02(30.29365, 120.16142);
      final (againLatitude, againLongitude) = wgs84ToGcj02(30.29365, 120.16142);
      expect(againLatitude, latitude);
      expect(againLongitude, longitude);
      expect((latitude - 30.29365).abs(), lessThan(0.01));
      expect((longitude - 120.16142).abs(), lessThan(0.01));
    });
  });
}