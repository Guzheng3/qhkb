import 'dart:convert';

/// 一个地点（天气数据的地理坐标载体）。
///
/// 只保留「选城市」需要的字段：显示名、行政区、国家、经纬度、时区、行政区编码。
/// [admin1] 是区分同名地点的依据之一。
///
/// 数据来源：服务端的地点搜索与定位反查（带 [district] 与 [adcode]）。
/// [adcode] 供实况天气按行政区查询使用；预报只用经纬度。
class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
    this.district,
    this.timezone,
    this.adcode,
  });

  final String name;

  /// 一级行政区（省 / 州）。
  final String? admin1;

  final String? country;

  /// 区 / 县一级。手动搜索与定位反查都可能填。
  final String? district;

  final double latitude;
  final double longitude;

  /// IANA 时区名，如 `Asia/Shanghai`；缺失时按设备时区处理。
  ///
  /// 服务端未返回时区时为 null，由服务端按坐标自行解析。
  final String? timezone;

  /// 行政区划编码（六位），实况天气按它查询时需要。
  final String? adcode;

  /// 经纬度差小于该值即视为同一地点（换城市判定用）。
  static const double samePlaceTolerance = 1e-4;

  /// 结果列表的副标题：行政区 + 国家，跳过空值与与主标题重复的值。
  String get regionLabel {
    final parts = <String>[];
    for (final value in [admin1, country]) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty || trimmed == name || parts.contains(trimmed)) {
        continue;
      }
      parts.add(trimmed);
    }
    return parts.join(' · ');
  }

  /// 设置页那一行尾随显示的紧凑地名。
  ///
  /// 有 [district] 时给出「市 · 区」（例如「杭州市 · 拱墅区」）——定位场景下用户
  /// 要的就是这个精度；尾随区域窄，省市区全串会被截断。没有 district 时只显示市名。
  String get displayName {
    final trimmedDistrict = district?.trim() ?? '';
    if (trimmedDistrict.isEmpty || trimmedDistrict == name) {
      return name;
    }
    return '$name · $trimmedDistrict';
  }

  /// 是否与 [other] 指向同一地点。
  ///
  /// 只比经纬度，不比名字：同一地点在不同语言下的名字不同。
  bool isSamePlaceAs(WeatherLocation other) {
    return (latitude - other.latitude).abs() < samePlaceTolerance &&
        (longitude - other.longitude).abs() < samePlaceTolerance;
  }

  WeatherLocation copyWith({String? adcode}) {
    return WeatherLocation(
      name: name,
      admin1: admin1,
      country: country,
      district: district,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      adcode: adcode ?? this.adcode,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'admin1': admin1,
    'country': country,
    'district': district,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'adcode': adcode,
  };

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('weather location: missing name');
    }
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('weather location: missing coordinates');
    }
    final admin1 = json['admin1'];
    final country = json['country'];
    // district / adcode 是后加的字段：老数据里没有这些键，读到 null 即可，不需要迁移。
    final district = json['district'];
    final timezone = json['timezone'];
    final adcode = json['adcode'];
    return WeatherLocation(
      name: name,
      admin1: admin1 is String ? admin1 : null,
      country: country is String ? country : null,
      district: district is String ? district : null,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone is String ? timezone : null,
      adcode: adcode is String ? adcode : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析持久化的地点；数据损坏时返回 null（不抛，调用方按「未设置城市」处理）。
  static WeatherLocation? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return WeatherLocation.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

/// 预报序列里的一个逐小时点。
///
/// 字段语义（聚合算法依赖它，服务端契约须沿用这套口径，勿改）：
/// - [time] 为 `T` 时，[temperatureC] 与 [weatherCode] 是 **T 时刻的瞬时值**；
/// - [precipitationMm]、[snowfallCm]、[precipitationProbability] 是
///   **`(T-1h, T]` 区间的累计量 / 概率**。
///
/// 任何字段都可能为 null：某个变量在某个时刻缺报是正常的，聚合时逐字段跳过。
class HourlyWeatherPoint {
  const HourlyWeatherPoint({
    required this.time,
    this.temperatureC,
    this.precipitationProbability,
    this.precipitationMm,
    this.snowfallCm,
    this.weatherCode,
  });

  /// 墙钟时刻（不带时区偏移）。与课程时间同为墙钟语义，直接比较。
  final DateTime time;

  final double? temperatureC;

  /// 降水概率，0~100。
  final int? precipitationProbability;

  /// 降水量（雨 + 阵雨 + 雪的水当量），mm。
  final double? precipitationMm;

  /// 降雪量，cm。
  final double? snowfallCm;

  /// WMO 天气现象码。
  final int? weatherCode;
}

/// 一个地点的多日逐小时预报。
///
/// [hourly] 保证按 [HourlyWeatherPoint.time] 升序——聚合算法依赖有序性做二分。
class WeatherForecast {
  WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
    required List<HourlyWeatherPoint> hourly,
  }) : hourly = _sortedCopy(hourly);

  /// 拷贝并按时间升序排序。
  ///
  /// 刻意不写成 `[...hourly]..sort(...)`：级联调用会让列表字面量推断不出元素
  /// 类型，比较闭包的参数退化成 dynamic，`--fatal-infos` 下直接判错。
  static List<HourlyWeatherPoint> _sortedCopy(
    List<HourlyWeatherPoint> points,
  ) {
    final copy = List<HourlyWeatherPoint>.of(points);
    copy.sort((a, b) => a.time.compareTo(b.time));
    return List<HourlyWeatherPoint>.unmodifiable(copy);
  }

  final double latitude;
  final double longitude;

  /// 抓取时刻（本地墙钟）。
  final DateTime fetchedAt;

  final List<HourlyWeatherPoint> hourly;

  /// 窗口起始小时。
  DateTime? get windowStart => hourly.isEmpty ? null : hourly.first.time;

  /// 窗口结束小时。
  DateTime? get windowEnd => hourly.isEmpty ? null : hourly.last.time;

  /// 预报是否覆盖 [time]（含端点）。
  bool covers(DateTime time) {
    if (hourly.isEmpty) {
      return false;
    }
    return !time.isBefore(hourly.first.time) && !time.isAfter(hourly.last.time);
  }

  /// 到 [now] 为止，这份预报的窗口是否已经走完（跨天后需要重拉）。
  bool hasLapsedAt(DateTime now) {
    final end = windowEnd;
    return end == null || now.isAfter(end);
  }

  /// 是否是 [location] 的预报。
  bool matchesLocation(WeatherLocation location) {
    return (latitude - location.latitude).abs() <
            WeatherLocation.samePlaceTolerance &&
        (longitude - location.longitude).abs() <
            WeatherLocation.samePlaceTolerance;
  }

  /// 列式序列化：逐小时字段拆成 6 个平行数组，体积约为逐点对象的 1/3。
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    'time': [for (final point in hourly) _wallClockIso(point.time)],
    'temperature_2m': [for (final point in hourly) point.temperatureC],
    'precipitation_probability': [
      for (final point in hourly) point.precipitationProbability,
    ],
    'precipitation': [for (final point in hourly) point.precipitationMm],
    'snowfall': [for (final point in hourly) point.snowfallCm],
    'weather_code': [for (final point in hourly) point.weatherCode],
  };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final fetchedAtMs = (json['fetchedAt'] as num?)?.toInt();
    if (latitude == null || longitude == null || fetchedAtMs == null) {
      throw const FormatException('weather forecast: missing header');
    }
    return _fromColumns(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      columns: json,
    );
  }

  /// 解析服务端 `mode=hourly` 的 `data`。
  ///
  /// 结构与旧 Open-Meteo 响应同构（`latitude` / `longitude` / `hourly` 列式
  /// 数组），这样聚合与缓存逻辑不用改。经纬度优先用 [requestLatitude] /
  /// [requestLongitude]：服务端可能回填格点或城市中心坐标，而
  /// [matchesLocation] 要拿它和用户所选城市比较，用请求坐标才不会误判换城。
  factory WeatherForecast.fromHourlyResponse(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
    double? requestLatitude,
    double? requestLongitude,
  }) {
    final hourly = json['hourly'];
    if (hourly is! Map) {
      throw const FormatException('weather forecast: missing hourly block');
    }
    final latitude =
        requestLatitude ?? (json['latitude'] as num?)?.toDouble();
    final longitude =
        requestLongitude ?? (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('weather forecast: missing coordinates');
    }
    return _fromColumns(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: fetchedAt,
      columns: Map<String, dynamic>.from(hourly),
    );
  }

  static WeatherForecast _fromColumns({
    required double latitude,
    required double longitude,
    required DateTime fetchedAt,
    required Map<String, dynamic> columns,
  }) {
    final times = _column(columns['time']);
    final temperatures = _column(columns['temperature_2m']);
    final probabilities = _column(columns['precipitation_probability']);
    final precipitation = _column(columns['precipitation']);
    final snowfall = _column(columns['snowfall']);
    final codes = _column(columns['weather_code']);

    final hourly = <HourlyWeatherPoint>[];
    for (var i = 0; i < times.length; i++) {
      final rawTime = times[i];
      if (rawTime is! String) {
        continue;
      }
      final time = DateTime.tryParse(rawTime);
      if (time == null) {
        continue;
      }
      hourly.add(
        HourlyWeatherPoint(
          time: time,
          temperatureC: _doubleAt(temperatures, i),
          precipitationProbability: _intAt(probabilities, i),
          precipitationMm: _doubleAt(precipitation, i),
          snowfallCm: _doubleAt(snowfall, i),
          weatherCode: _intAt(codes, i),
        ),
      );
    }

    return WeatherForecast(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: fetchedAt,
      hourly: hourly,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析缓存的预报；数据损坏或没有任何小时点时返回 null。
  static WeatherForecast? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final forecast = WeatherForecast.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return forecast.hourly.isEmpty ? null : forecast;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _column(Object? raw) =>
      raw is List ? raw : const <dynamic>[];

  static double? _doubleAt(List<dynamic> column, int index) {
    if (index >= column.length) {
      return null;
    }
    final value = column[index];
    return value is num ? value.toDouble() : null;
  }

  static int? _intAt(List<dynamic> column, int index) {
    if (index >= column.length) {
      return null;
    }
    final value = column[index];
    return value is num ? value.round() : null;
  }

  /// 不带偏移量的墙钟 ISO 串。
  ///
  /// 不能用 `toIso8601String()`：本地时间会带上 `.000` 尾巴，UTC 时间还会加
  /// `Z`；显式拼装能保证「存进去什么墙钟，读出来就是什么墙钟」。
  static String _wallClockIso(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}'
        'T${two(time.hour)}:${two(time.minute)}';
  }
}

/// 一个地点的**实况**天气。
///
/// 与 [WeatherForecast] 分开：实况只描述「此刻」，没有逐小时序列。服务端当前
/// 返回的天气现象是**中文文本**（如「晴」「多云」），文案随语言变化的部分交给
/// domain 的 `weatherCategoryFromText` 映射后再本地化，这里只原样保留 [text]。
/// 若服务端契约改为返回数值码，在这里补解析分支，不要改动展示层。
class CurrentWeather {
  const CurrentWeather({
    required this.text,
    required this.temperatureC,
    this.humidity,
    this.windDirection,
    this.windPower,
    this.reportTime,
    this.wmoCode,
  });

  /// 服务端返回的天气现象原文（中文），如「晴」「小雨」。
  final String text;

  /// 实时气温（摄氏度，四舍五入到整数）。
  final int temperatureC;

  /// 空气湿度（百分比）；缺报为 null。
  final int? humidity;

  /// 风向描述；缺报为 null。
  final String? windDirection;

  /// 风力级别；缺报为 null。
  final String? windPower;

  /// 数据发布时间；缺报为 null。
  final String? reportTime;

  /// 服务端由和风图标码映射出的 WMO 码；缺报为 null。
  ///
  /// 有它时优先用它归类（比中文文本稳定），没有时才回落到 [text]。
  final int? wmoCode;

  /// 解析服务端 `mode=now` 的 `data`。
  ///
  /// 字段口径同时兼容两套命名：`weather` / `temperature` / `humidity` /
  /// `winddirection` / `windpower` / `reporttime`（Amap lives[0] 兼容字段）与
  /// `desc` / `temp` / `windDir` / `windScale` / `obsTime`（withU 网页沿用字段）。
  /// `wmo_code` 有则带上，供展示层优先按数值码归类。缺现象或温度时抛
  /// [FormatException]。
  factory CurrentWeather.fromServerJson(Map<String, dynamic> json) {
    final text = json['weather'] ?? json['desc'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('current weather: missing weather text');
    }
    final temperature = json['temperature'] ?? json['temp'];
    final parsed = temperature is String
        ? int.tryParse(temperature.trim())
        : (temperature is num ? temperature.round() : null);
    if (parsed == null) {
      throw const FormatException('current weather: missing temperature');
    }
    final humidityRaw = json['humidity'];
    final humidity = humidityRaw is String
        ? int.tryParse(humidityRaw.trim())
        : (humidityRaw is num ? humidityRaw.round() : null);
    final wmoRaw = json['wmo_code'];
    final wmoCode = wmoRaw is num ? wmoRaw.round() : int.tryParse('$wmoRaw');

    String? textOf(Object? value) {
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return CurrentWeather(
      text: text.trim(),
      temperatureC: parsed,
      humidity: humidity,
      windDirection: textOf(json['winddirection'] ?? json['windDir']),
      windPower: textOf(json['windpower'] ?? json['windScale']),
      reportTime: textOf(json['reporttime'] ?? json['obsTime']),
      wmoCode: wmoCode,
    );
  }
}
