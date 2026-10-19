import 'package:flutter/material.dart';
import 'package:qhkb/l10n/app_localizations.dart';
import 'package:qhkb/l10n/service_message_localizer.dart';

import '../services/qhkb_couple_auth_service.dart';
import '../services/qhkb_couple_config.dart';
import '../services/qhkb_couple_timetable_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

Future<bool?> showQhkbCoupleLoginSheet({
  required BuildContext context,
  required QhkbCoupleAuthService authService,
  QhkbCoupleConfig? initialConfig,
  required Future<QhkbCouplePullResult> Function(
    QhkbCoupleTimetableService service,
  )
  onPullPartner,
  bool useRootNavigator = false,
}) {
  return showHyperosSheet<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (_) => QhkbCoupleLoginSheet(
      authService: authService,
      initialConfig: initialConfig,
      onPullPartner: onPullPartner,
    ),
  );
}

class QhkbCoupleLoginSheet extends StatefulWidget {
  const QhkbCoupleLoginSheet({
    super.key,
    required this.authService,
    this.initialConfig,
    required this.onPullPartner,
  });

  /// 借用调用方（首页 provider）的认证服务：登录要立刻反映到全局登录态，
  /// 且凭证只有一份。借用方不得 dispose。
  final QhkbCoupleAuthService authService;

  final QhkbCoupleConfig? initialConfig;
  final Future<QhkbCouplePullResult> Function(
    QhkbCoupleTimetableService service,
  )
  onPullPartner;

  @override
  State<QhkbCoupleLoginSheet> createState() => _QhkbCoupleLoginSheetState();
}

class _QhkbCoupleLoginSheetState extends State<QhkbCoupleLoginSheet> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final QhkbCoupleTimetableService _timetableService;
  bool _isSubmitting = false;

  QhkbCoupleAuthService get _authService => widget.authService;

  @override
  void initState() {
    super.initState();
    _timetableService = QhkbCoupleTimetableService(
      authService: widget.authService,
    );
    final config = widget.initialConfig ?? const QhkbCoupleConfig();
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    if (widget.initialConfig == null) {
      _loadSavedConfig();
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    // _authService 由首页 provider 持有，这里不 dispose。
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = await _authService.loadConfig();
    if (!mounted ||
        _baseUrlController.text.trim() != QhkbCoupleConfig.defaultBaseUrl) {
      return;
    }
    _baseUrlController.text = config.baseUrl.isEmpty
        ? QhkbCoupleConfig.defaultBaseUrl
        : config.baseUrl;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final baseUrl = _baseUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (baseUrl.isEmpty || username.isEmpty || password.isEmpty) {
      showAppToast(
        context,
        message: l10n.qhkbCoupleMissingCredentials,
        kind: AppToastKind.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.connect(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
      // 密码只用于这一次登录请求，凭证已经落盘，不必再留在输入框里。
      _passwordController.clear();
      final result = await widget.onPullPartner(_timetableService);
      if (!mounted) {
        return;
      }

      final pullMessage = switch (result.status) {
        QhkbCouplePullStatus.imported => l10n.qhkbCouplePullImported,
        QhkbCouplePullStatus.updated => l10n.qhkbCouplePullUpdated,
        QhkbCouplePullStatus.unchanged => l10n.qhkbCouplePullUnchanged,
        QhkbCouplePullStatus.failed => localizeServiceMessage(
          l10n,
          result.errorCode ?? 'qhkb_request_failed',
        ),
      };
      showAppToast(
        context,
        message: pullMessage,
        kind: result.status == QhkbCouplePullStatus.failed
            ? AppToastKind.error
            : AppToastKind.success,
      );
      // 首次同步失败（对方课表格式不支持、断网…）不影响登录本身：凭证已经落盘，
      // 这里必须关掉弹窗让调用方刷新登录态。停在登录表单会让用户以为没登录成功，
      // 再点一次也只是重复登录。同步失败的原因已由上面的 toast 说明。
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, _errorCode(error)),
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _errorCode(Object error) {
    if (error is QhkbCoupleApiException) {
      return error.code;
    }
    return 'qhkb_request_failed';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSheetFrame(
      maxHeight: MediaQuery.sizeOf(context).height * 0.68,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.qhkbCoupleLoginMenuTitle,
              style: HyperosTypography.sheetTitle(context),
            ),
            const SizedBox(height: 6),
            HyperosSectionDescription(text: l10n.qhkbCoupleLoginPageSubtitle),
            const SizedBox(height: 18),
            HyperosTextField(
              controller: _baseUrlController,
              label: l10n.qhkbCoupleServerLabel,
              hint: QhkbCoupleConfig.defaultBaseUrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            HyperosTextField(
              controller: _usernameController,
              label: l10n.qhkbCoupleUsernameLabel,
              hint: l10n.qhkbCoupleUsernameHint,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            HyperosTextField(
              controller: _passwordController,
              label: l10n.qhkbCouplePasswordLabel,
              hint: l10n.qhkbCouplePasswordHint,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            HyperosButton(
              label: _isSubmitting
                  ? '${l10n.qhkbCoupleLoginAction}...'
                  : l10n.qhkbCoupleLoginAction,
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
