/// Modules that can be included when exporting course statistics.
enum StatisticsExportModule {
  overview,
  achievements,
  stories,
  dailyDistribution,
  natureRatio,
  ranking,
}

/// User choices from the statistics export sheet (image only).
class StatisticsExportOptions {
  const StatisticsExportOptions({required this.modules});

  final Set<StatisticsExportModule> modules;

  /// All modules available for export.
  static const Set<StatisticsExportModule> allModules =
      <StatisticsExportModule>{
        StatisticsExportModule.overview,
        StatisticsExportModule.achievements,
        StatisticsExportModule.stories,
        StatisticsExportModule.dailyDistribution,
        StatisticsExportModule.natureRatio,
        StatisticsExportModule.ranking,
      };

  /// Default selection: everything except course ranking (long and optional).
  static const Set<StatisticsExportModule> defaultModules =
      <StatisticsExportModule>{
        StatisticsExportModule.overview,
        StatisticsExportModule.achievements,
        StatisticsExportModule.stories,
        StatisticsExportModule.dailyDistribution,
        StatisticsExportModule.natureRatio,
      };

  static StatisticsExportOptions defaults() {
    return const StatisticsExportOptions(modules: defaultModules);
  }

  bool get hasModules => modules.isNotEmpty;

  StatisticsExportOptions copyWith({Set<StatisticsExportModule>? modules}) {
    return StatisticsExportOptions(modules: modules ?? this.modules);
  }
}

/// Brand URLs shown on the export-only header / footer.
abstract final class StatisticsExportBrand {
  static const websiteUrl = 'https://qhkb.qinghan.vip/';
  // Deliberately NOT localized: these CJK characters are part of the IDN itself
  // (its punycode form is the line above), so translating them would break the
  // domain. Registered in tool/cjk_hardcode_baseline.txt for that reason.
  static const websiteDisplay = 'qhkb.qinghan.vip';
  static const githubUrl = 'https://github.com/Guzheng3/qhkb';
  static const githubDisplay = 'github.com/Guzheng3/qhkb';
}
