import 'dart:math' as math;

/// WGS-84 → GCJ-02 正向纠偏，返回 (纬度, 经度)。
///
/// 设备定位（geolocator / 系统 LocationManager）给的是 WGS-84，高德按 GCJ-02
/// 解释坐标；国内两者相差数百米，不纠偏会让逆地理落到邻近的街道或村。
///
/// 用公开的标准算法（Krassovsky 1940 椭球 + 三角级数拟合），不引依赖。
/// 只做正向纠偏，不做反算：本工程里需要 GCJ-02 的场景只有「把坐标交给高德」，
/// 而高德回来的坐标（输入提示、正向地理编码、IP 矩形中心）本来就是 GCJ-02，
/// 不需要再变成别的东西。
(double, double) wgs84ToGcj02(double latitude, double longitude) {
  // 境外不纠偏：GCJ-02 只对中国大陆生效，境外 WGS-84 与 GCJ-02 视为同一坐标。
  if (_isOutsideChina(latitude, longitude)) {
    return (latitude, longitude);
  }

  // Krassovsky 1940 椭球：长半轴（米）与第一偏心率平方。
  const double axis = 6378245;
  const double eccentricitySquared = 0.00669342162296594323;

  var deltaLatitude = _deltaLatitude(longitude - 105.0, latitude - 35.0);
  var deltaLongitude = _deltaLongitude(longitude - 105.0, latitude - 35.0);
  final radianLatitude = latitude / 180.0 * math.pi;
  // 「magic」是标准算法里的中间量：1 - e²·sin²φ。
  var magic = math.sin(radianLatitude);
  magic = 1 - eccentricitySquared * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  // 把级数算出的「米」换算成「度」：纬度方向按子午圈曲率半径，经度方向再除 cos φ。
  deltaLatitude =
      (deltaLatitude * 180.0) /
      (axis * (1 - eccentricitySquared) / (magic * sqrtMagic) * math.pi);
  deltaLongitude =
      (deltaLongitude * 180.0) /
      (axis / sqrtMagic * math.cos(radianLatitude) * math.pi);
  return (latitude + deltaLatitude, longitude + deltaLongitude);
}

/// 是否在中国大陆范围之外（标准算法的粗略矩形框，含港澳台在内按国内处理）。
bool _isOutsideChina(double latitude, double longitude) {
  return longitude < 72.004 ||
      longitude > 137.8347 ||
      latitude < 0.8293 ||
      latitude > 55.8271;
}

/// 纬度方向的米级偏移量（级数拟合项）。
double _deltaLatitude(double x, double y) {
  var delta =
      -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  delta +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  delta +=
      (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  delta +=
      (160.0 * math.sin(y / 12.0 * math.pi) +
          320 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return delta;
}

/// 经度方向的米级偏移量（级数拟合项）。
double _deltaLongitude(double x, double y) {
  var delta =
      300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  delta +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  delta +=
      (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  delta +=
      (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return delta;
}