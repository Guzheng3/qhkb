import 'package:flutter/material.dart';
import 'package:qhkb/l10n/app_localizations.dart';

import '../services/qhkb_couple_config.dart';
import '../ui/hyperos/hyperos.dart';
import 'course_field_picker_sheet.dart';

class QhkbCoupleConnectResult {
  const QhkbCoupleConnectResult({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;
}

class QhkbCoupleConnectSheet extends StatefulWidget {
  const QhkbCoupleConnectSheet({super.key, required this.config});

  final QhkbCoupleConfig config;

  @override
  State<QhkbCoupleConnectSheet> createState() =>
      _QhkbCoupleConnectSheetState();
}

class _QhkbCoupleConnectSheetState extends State<QhkbCoupleConnectSheet> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.config.baseUrl);
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _confirmConnect() {
    final baseUrl = _baseUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (baseUrl.isEmpty || username.isEmpty || password.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      QhkbCoupleConnectResult(
        baseUrl: baseUrl,
        username: username,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PickerSheetScaffold(
      actions: HyperosButton(
        label: l10n.qhkbCoupleConfirmConnect,
        onPressed: _confirmConnect,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.qhkbCoupleLoginSheetTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.qhkbCoupleLoginSheetSubtitle,
            style: HyperosTypography.sectionDescription(context),
          ),
          const SizedBox(height: 16),
          HyperosTextField(
            controller: _baseUrlController,
            label: l10n.qhkbCoupleServerLabel,
            hint: l10n.qhkbCoupleServerHint(widget.config.baseUrl),
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
          ),
        ],
      ),
    );
  }
}
