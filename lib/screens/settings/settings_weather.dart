part of '../timetable_settings_screen.dart';

/// 天气设置：数据来源（定位 / 城市 / 实况）、显示位置、显示内容、失败重试、
/// 覆盖范围说明与数据来源署名。
///
/// 卡片上刻意不显示任何错误态（一屏 5~8 张卡，错误提示会变成视觉灾难），
/// 所以这里是把「为什么没有天气」讲清楚的唯一出口，也是未连接 withU 时给出
/// 「不可用」提示的唯一入口。
///
/// 结构遵循设置页惯例：**每个区块 = `HyperosSectionGap` + `HyperosSectionLabel`
/// + 一个 `HyperosListGroup`**，说明文字（`HyperosSectionDescription`）挂在它所属的
/// 那个区块之后。
class _WeatherSettingsScreen extends StatelessWidget {
  const _WeatherSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weather = context.watch<WeatherProvider?>();
    final session = context.watch<QhkbCoupleSessionProvider?>();
    final timetable = context.watch<TimetableProvider>();
    final settings = timetable.settings;
    // 天气没开时下面那些显示项一律无效（数据都不会拉），整组禁用而不是藏起来：
    // 用户能看到「原来还有这些选项」，也知道为什么点不动。
    final enabled = weather?.enabled ?? false;
    // 天气数据经 withU 的 action=weather 获取，必须先连接 withU；未连接时
    // 城市搜索 / 定位 / 实况都不可用。
    final connected = session?.isLoggedIn ?? false;
    final current = weather?.currentWeather;
    // 开关与显示项的落盘失败会 reject（updateSettings 里 await 持久化无 try/catch），
    // 这里统一兜住并提示，避免「开关看起来生效、重启回旧值」。
    Future<void> update(TimetableSettings next) async {
      try {
        await timetable.updateSettings(next);
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        showAppToast(context, message: l10n.saveFailed, kind: AppToastKind.error);
      }
    }

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.weatherSettingsTitle),
      child: HyperosListView(
        pageStorageKey: const PageStorageKey<String>('settings-weather'),
        children: [
          // 「数据来源」排在最前：没有城市就一条天气都取不到，先把「数据从哪来」
          // 这件事办完，后面那些显示开关才有意义。
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionSourceTitle),
          HyperosListGroup(
            children: [
              // 一键定位放在城市行之前：它比「手动搜索」更常用，也是「我不想挑
              // 城市，直接用我在的地方」的默认路径。
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  Icons.my_location_rounded,
                  HyperosIconColors.blue,
                ),
                title: l10n.weatherUseCurrentLocation,
                endActions: [
                  if (weather?.isLocating ?? false)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
                // 定位中整行禁用：系统级动作会弹权限框、要十几秒，防重复触发。
                // 未连接 withU 时定位也无意义（反查不可用），一并禁用。
                onClick: (weather == null || !connected || weather.isLocating)
                    ? null
                    : () => unawaited(_locateWeather(context, weather)),
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  Icons.location_on_rounded,
                  HyperosIconColors.teal,
                ),
                title: l10n.weatherCityLabel,
                endActions: [
                  Text(
                    // displayName 而不是 name：定位来的地点带区级，显示「杭州市 ·
                    // 拱墅区」；手动搜索的没有区级，就只显示市名。
                    weather?.location?.displayName ?? l10n.weatherCityNotSet,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: (weather == null || !connected)
                    ? null
                    : () => HyperosNavigation.push(
                        context,
                        settings: const RouteSettings(
                          name: '/settings/weather/city',
                        ),
                        builder: (_) => const WeatherCityPickerScreen(),
                      ),
              ),
              // 取数失败时的重试。放在数据来源区块内：它本来就是「这份数据没拿到」
              // 的补救动作。
              if (connected && weather?.status == WeatherStatus.failed)
                _MiuixSettingsPreference(
                  startAction: _settingsIconBadge(
                    Icons.refresh_rounded,
                    HyperosIconColors.orange,
                  ),
                  title: l10n.weatherStatusFailed,
                  endActions: [
                    Text(
                      l10n.weatherRetryAction,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                  onClick: () => unawaited(weather!.retry()),
                ),
            ],
          ),
          // 实况（服务端）：有才显示，作为来源区块的一条补充说明。
          if (current != null)
            HyperosSectionDescription(
              text: _currentWeatherSummary(l10n, current),
            ),
          // 未连接 withU 时给明确提示；连接后显示服务端数据来源说明。
          HyperosSectionDescription(
            text: connected
                ? l10n.weatherAttribution
                : l10n.weatherWithuRequired,
          ),

          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionDisplayTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.weatherEnableTitle,
                subtitle: l10n.weatherEnableSubtitle,
                value: enabled,
                onChanged: weather == null
                    ? null
                    : (value) => unawaited(
                        _toggleWeather(
                          context,
                          weather,
                          value,
                          connected: connected,
                        ),
                      ),
              ),
              // 「显示在哪」三个开关与总开关同组：它们回答的都是「显不显示」，
              // 与下一组「显示什么内容」是两件事。
              HyperosSwitchTile(
                title: l10n.weatherShowOnDayCardTitle,
                value: settings.weatherShowOnDayCard,
                onChanged: enabled
                    ? (value) =>
                          update(settings.copyWith(weatherShowOnDayCard: value))
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.weatherShowOnWeekCardTitle,
                // 周网格的格子只放得下一项，这件事挂在行上而不是堆进区块末尾的脚注。
                subtitle: l10n.weatherShowOnWeekCardSubtitle,
                value: settings.weatherShowOnWeekCard,
                onChanged: enabled
                    ? (value) =>
                          update(settings.copyWith(weatherShowOnWeekCard: value))
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.weatherShowOnSheetTitle,
                value: settings.weatherShowOnSheet,
                onChanged: enabled
                    ? (value) =>
                          update(settings.copyWith(weatherShowOnSheet: value))
                    : null,
              ),
            ],
          ),
          // 「预报只覆盖 16 天」解释的是「为什么有些日子看不到天气」，属于显示区块的脚注。
          HyperosSectionDescription(text: l10n.weatherCoverageNote),

          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionContentTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.weatherShowPhenomenonTitle,
                subtitle: l10n.weatherShowPhenomenonSubtitle,
                value: settings.weatherShowPhenomenon,
                onChanged: enabled
                    ? (value) =>
                          update(settings.copyWith(weatherShowPhenomenon: value))
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.weatherShowTemperatureTitle,
                value: settings.weatherShowTemperature,
                onChanged: enabled
                    ? (value) => update(
                        settings.copyWith(weatherShowTemperature: value),
                      )
                    : null,
              ),
              HyperosSwitchTile(
                title: l10n.weatherShowProbabilityTitle,
                subtitle: l10n.weatherShowProbabilitySubtitle,
                value: settings.weatherShowProbability,
                onChanged: enabled
                    ? (value) => update(
                        settings.copyWith(weatherShowProbability: value),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 把实况拼成一行「当前天气 · 现象 温度 · 湿度%」。
///
/// 服务端实况的现象是中文文本，先映射成 [WeatherCategory] 再本地化，保证非中文
/// 语言下也显示本地文案；风力方向若返回中文（如「西北」），无法本地化，不展示。
String _currentWeatherSummary(AppLocalizations l10n, CurrentWeather current) {
  final wmoCode = current.wmoCode;
  final category = wmoCode == null
      ? weatherCategoryFromText(current.text)
      : weatherCategoryFromWmo(wmoCode);
  final label = WeatherCategoryLocalizer.label(l10n, category);
  final parts = <String>[
    label,
    l10n.weatherTemperatureValue(current.temperatureC),
    if (current.humidity != null) l10n.weatherCurrentHumidity(current.humidity!),
  ];
  return '${l10n.weatherSectionCurrent} · '
      '${parts.join(l10n.weatherSummarySeparator)}';
}

/// 开关天气。**打开时如果还没有城市，主动定位一次**——否则用户会停在
/// 「开关开着、卡片上却什么都没有」的状态，还得自己去找「使用当前位置」。
///
/// 只在「打开 + 没有城市」这一个组合下触发，两个边界都不能少：
/// - 已有城市时绝不去动它——用户手选的城市比定位更可信，也不该被覆盖；
/// - 关闭时什么都不做——关掉还要弹一个权限框是纯粹的打扰。
///
/// 未连接 withU 时不触发定位：反查地名同样不可用，弹了权限框也拿不到结果。
Future<void> _toggleWeather(
  BuildContext context,
  WeatherProvider weather,
  bool enabled, {
  required bool connected,
}) async {
  await weather.setEnabled(enabled);
  // await 之后 context 可能已失效（用户在这期间切走了页面）。
  if (!context.mounted || !enabled || weather.location != null) {
    return;
  }
  if (!connected) {
    return;
  }
  await _locateWeather(context, weather);
}

/// 一键定位。成功后**留在原地**——那一行的尾随值已经变成新地点，本身就是反馈，
/// 再弹一次是噪音；失败才提示。
Future<void> _locateWeather(
  BuildContext context,
  WeatherProvider weather,
) async {
  // l10n 必须在 await 之前取：await 之后 context 可能已失效。
  final l10n = AppLocalizations.of(context)!;
  final failure = await weather.locateCurrentPosition();
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    showAppToast(
      context,
      message: WeatherLocationFailureLocalizer.message(l10n, failure),
      kind: AppToastKind.warning,
    );
    return;
  }
  // 按网络 IP 估算出来的位置要如实标注：它可能指到运营商网关所在城市，
  // 不能让它冒充真实定位。
  if (weather.lastLocateWasEstimated) {
    showAppToast(context, message: l10n.weatherLocationEstimated);
  }
}