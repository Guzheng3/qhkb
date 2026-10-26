import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_http_client.dart';
import 'qhkb_couple_config.dart';
import 'qhkb_couple_session_store.dart';

class QhkbCoupleApiException implements Exception {
  final String code;
  final String? serverMessage;

  /// 服务端响应体里的稳定错误码（如天气接口的 `weather_not_configured`）。
  ///
  /// 与 [code] 分开：后者是客户端归并后的类别（会话过期 / 网络失败等），
  /// 前者保留服务端原值，供需要区分具体业务错误的调用方使用。
  final String? serverError;

  const QhkbCoupleApiException(
    this.code, {
    this.serverMessage,
    this.serverError,
  });

  @override
  String toString() =>
      'QhkbCoupleApiException: $code'
      '${serverError == null ? '' : ' ($serverError)'}'
      '${serverMessage == null ? '' : ': $serverMessage'}';
}

class QhkbCoupleUser {
  final int id;
  final String username;
  final String nickname;
  final String role;
  final String? avatar;

  const QhkbCoupleUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.role,
    this.avatar,
  });

  factory QhkbCoupleUser.fromJson(Map<String, dynamic> json) {
    return QhkbCoupleUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }

  String get displayName {
    final trimmedNickname = nickname.trim();
    return trimmedNickname.isEmpty ? username : trimmedNickname;
  }
}

class QhkbCoupleLoginResult {
  final QhkbCoupleSession session;
  final QhkbCoupleUser user;
  final QhkbCoupleUser? partner;

  const QhkbCoupleLoginResult({
    required this.session,
    required this.user,
    this.partner,
  });
}

class QhkbCoupleAuthService {
  QhkbCoupleAuthService({
    http.Client? client,
    QhkbCoupleConfigStore? configStore,
    QhkbCoupleSessionStore? sessionStore,
    this.requestTimeout,
  }) : _client = client ?? createAppHttpClient(),
       _configStore = configStore ?? const QhkbCoupleConfigStore(),
       _sessionStore = sessionStore ?? const QhkbCoupleSessionStore() {
    _ownsClient = client == null && !isSharedAppHttpClient(_client);
  }

  /// 覆盖所有请求的超时上限（测试注入用）。为 null 时按 action 取
  /// [_timeoutForAction] 的默认值。
  ///
  /// 没有超时的话，黑洞连接会一直挂在 TCP 层默认超时上（可达一两分钟）。
  final Duration? requestTimeout;

  /// 注销：小请求，且只影响「服务端未确认」的提示，短一点让流程早点落定。
  static const Duration logoutTimeout = Duration(seconds: 8);

  /// 登录：小请求，但用户在等结果，别急着判失败。
  static const Duration loginTimeout = Duration(seconds: 20);

  /// 天气：只读小请求；天气是装饰性信息，不值得让单飞槽挂 60 秒。
  static const Duration weatherTimeout = Duration(seconds: 15);

  /// 其余请求（bootstrap / 课表拉取与上传 / 历史 / 回滚）：可能携带最多 2MB 的
  /// 课表内容，慢网下需要更宽裕。
  static const Duration defaultTimeout = Duration(seconds: 60);

  /// 本次请求该用哪个超时。
  Duration timeoutForAction(String action) {
    final override = requestTimeout;
    if (override != null) {
      return override;
    }
    return switch (action) {
      'logout' => logoutTimeout,
      'login' => loginTimeout,
      'weather' => weatherTimeout,
      _ => defaultTimeout,
    };
  }

  final http.Client _client;
  final QhkbCoupleConfigStore _configStore;
  final QhkbCoupleSessionStore _sessionStore;
  late final bool _ownsClient;

  /// 并发的相同读取合并成一次，但**不做长期缓存**：会话的唯一真相源是
  /// [QhkbCoupleSessionStore]。本类的实例不止一个（首页 provider、设置页、
  /// 登录弹窗、自动同步各持一份），一旦各自缓存，别的实例登录或退出后这里就
  /// 会继续拿着旧凭证发请求，甚至用旧会话的 401 把新登录的凭证删掉。
  Future<QhkbCoupleSession?>? _pendingLoad;

  Future<QhkbCoupleConfig> loadConfig() => _configStore.load();

  Future<QhkbCoupleSession?> loadSession() async {
    final pending = _pendingLoad;
    if (pending != null) {
      return pending;
    }
    final load = _sessionStore.load();
    _pendingLoad = load;
    try {
      return await load;
    } finally {
      if (identical(_pendingLoad, load)) {
        _pendingLoad = null;
      }
    }
  }

  Future<QhkbCoupleDisplayProfile?> loadDisplayProfile() {
    return _sessionStore.loadDisplayProfile();
  }

  Future<void> saveDisplayProfile(QhkbCoupleDisplayProfile profile) {
    return _sessionStore.saveDisplayProfile(profile);
  }

  Future<QhkbCoupleLoginResult> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (baseUrl.trim().isEmpty ||
        normalizedUsername.isEmpty ||
        password.isEmpty) {
      throw const QhkbCoupleApiException('qhkb_missing_credentials');
    }

    final config = QhkbCoupleConfig(baseUrl: baseUrl.trim());
    final uri = config.apiUri;
    final result = await _request(
      uri: _actionUri(uri, 'login'),
      method: 'POST',
      body: {'username': normalizedUsername, 'password': password},
    );
    final payload = result.payload;

    final rawUser = payload['user'];
    final csrfToken = payload['csrf_token'] as String?;
    if (rawUser is! Map || csrfToken == null || csrfToken.trim().isEmpty) {
      throw const QhkbCoupleApiException('qhkb_invalid_response');
    }

    final sessionId = _cookieValue(result.response, 'PHPSESSID');
    if (sessionId == null || sessionId.isEmpty) {
      throw const QhkbCoupleApiException('qhkb_session_cookie_missing');
    }

    // 密码只用于本次登录请求；会话过期后由服务端凭 withu_device
    // 可信设备 Cookie 自动恢复，不落盘。
    final session = QhkbCoupleSession(
      username: normalizedUsername,
      sessionId: sessionId,
      deviceToken: _cookieValue(result.response, 'withu_device'),
      csrfToken: csrfToken.trim(),
    );
    await _configStore.save(config);
    await _sessionStore.save(session);

    final user = QhkbCoupleUser.fromJson(Map<String, dynamic>.from(rawUser));
    final rawPartner = payload['partner'];
    final partner = rawPartner is Map
        ? QhkbCoupleUser.fromJson(Map<String, dynamic>.from(rawPartner))
        : null;
    await _sessionStore.saveDisplayProfile(
      QhkbCoupleDisplayProfile(
        userNickname: user.displayName,
        partnerNickname: partner?.displayName ?? '',
        userAvatar: user.avatar,
        partnerAvatar: partner?.avatar,
        userGender: QhkbCoupleDisplayProfile.genderFromRole(user.role),
        partnerGender: QhkbCoupleDisplayProfile.genderFromRole(partner?.role),
      ),
    );
    return QhkbCoupleLoginResult(
      session: session,
      user: user,
      partner: partner,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String action, {
    Map<String, String>? query,
  }) async {
    final session = await _requireSession();
    final config = await _configStore.load();
    return (await _request(
      uri: _actionUri(config.apiUri, action, query: query),
      method: 'GET',
      session: session,
    )).payload;
  }

  Future<Map<String, dynamic>> postJson(
    String action,
    Map<String, dynamic> body,
  ) async {
    final session = await _requireSession();
    final config = await _configStore.load();
    return (await _request(
      uri: _actionUri(config.apiUri, action),
      method: 'POST',
      session: session,
      body: {...body, '_token': session.csrfToken},
    )).payload;
  }

  /// 清除本机凭证，不联系服务端。
  ///
  /// 退出登录的第一步：先让本地立即生效，界面不必等服务端往返。
  Future<void> clearLocalCredentials() => _sessionStore.clear();

  /// 请服务端注销 [session]（同时吊销其 withu_device 可信设备），尽力而为，
  /// 返回服务端是否确认。
  ///
  /// 本地凭证可以先清掉：这里用的是调用方捕获的会话快照，不依赖存储。
  /// 注销响应不会回写凭证（`persistSessionUpdates: false`）——否则服务端一旦
  /// 在响应里带上新的 Set-Cookie，刚清掉的凭证会被重新写回去。
  Future<bool> notifyServerLogout(QhkbCoupleSession session) async {
    try {
      final config = await _configStore.load();
      await _request(
        uri: _actionUri(config.apiUri, 'logout'),
        method: 'POST',
        session: session,
        body: {'_token': session.csrfToken},
        persistSessionUpdates: false,
      );
      return true;
    } catch (_) {
      // 服务端不可达、CSRF 过期都不影响本地已经完成的退出。
      return false;
    }
  }

  /// 释放网络资源。只有本类的**所有者**可以调用：客户端在 release 构建下
  /// 由本实例持有，[dispose] 之后借用它的 UI 组件再发请求就会失败。
  /// 借用的组件（登录弹窗、设置页、情侣中心）不得调用。
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<({http.Response response, Map<String, dynamic> payload})> _request({
    required Uri uri,
    required String method,
    QhkbCoupleSession? session,
    Map<String, dynamic>? body,
    bool persistSessionUpdates = true,
  }) async {
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (session != null) {
      request.headers['Cookie'] = session.cookieHeader;
      if (method == 'POST') {
        request.headers['X-CSRF-Token'] = session.csrfToken;
      }
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      // .timeout 覆盖连接、发送与读取整段耗时；超时按网络失败处理。
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeoutForAction(_queryAction(uri)));
    } catch (_) {
      throw const QhkbCoupleApiException('qhkb_network_failed');
    }

    // 错误码先由 HTTP 状态码决定，再看响应体。
    // 出错时的响应体经常根本不是 JSON（PHP 致命错误页、网关 502、被跳转到
    // 登录页的 HTML），先解析 body 会把 401 误判成 qhkb_invalid_response：
    // 该作废的会话不作废，该给的提示也给不出来。
    final payload = _decodePayload(response);

    if (response.statusCode != 200) {
      final errorCode = _statusCode(
        response.statusCode,
        action: _queryAction(uri),
      );
      if (persistSessionUpdates &&
          session != null &&
          errorCode == 'qhkb_session_expired') {
        await _sessionStore.clearIfSession(session);
      }
      throw QhkbCoupleApiException(
        errorCode,
        serverMessage: _messageOf(payload),
        serverError: _errorOf(payload),
      );
    }
    if (payload == null) {
      throw const QhkbCoupleApiException('qhkb_invalid_response');
    }
    if (payload['success'] != true) {
      throw QhkbCoupleApiException(
        'qhkb_request_failed',
        serverMessage: _messageOf(payload),
        serverError: _errorOf(payload),
      );
    }

    if (persistSessionUpdates && session != null) {
      await _updateSessionFromResponse(session, response, payload);
    }
    return (response: response, payload: payload);
  }

  /// 解析响应体；不是 JSON 对象时返回 null（由调用方决定如何降级）。
  Map<String, dynamic>? _decodePayload(http.Response response) {
    try {
      final text = utf8.decode(response.bodyBytes);
      if (text.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _messageOf(Map<String, dynamic>? payload) =>
      payload?['message'] as String?;

  String? _errorOf(Map<String, dynamic>? payload) {
    final value = payload?['error'];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<QhkbCoupleSession> _requireSession() async {
    final session = await loadSession();
    if (session == null || !session.isUsable) {
      throw const QhkbCoupleApiException('qhkb_couple_not_connected');
    }
    return session;
  }

  Future<void> _updateSessionFromResponse(
    QhkbCoupleSession session,
    http.Response response,
    Map<String, dynamic> payload,
  ) async {
    if (payload['logged_in'] == false) {
      await _sessionStore.clearIfSession(session);
      throw const QhkbCoupleApiException('qhkb_session_expired');
    }

    final updatedSession = session.copyWith(
      sessionId: _cookieValue(response, 'PHPSESSID'),
      deviceToken: _cookieValue(response, 'withu_device'),
      csrfToken: (payload['csrf_token'] as String?)?.trim(),
    );
    // 服务端可能在响应里换了 PHPSESSID（会话续期）或刷新了 CSRF token，
    // 只有确实拿到新值才回写。
    if (updatedSession.isUsable && updatedSession != session) {
      await _sessionStore.save(updatedSession);
    }
  }

  Uri _actionUri(
    Uri base,
    String action, {
    Map<String, String>? query,
  }) {
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'action': action,
        ...?query,
      },
    );
  }

  String _queryAction(Uri uri) => uri.queryParameters['action'] ?? '';

  String _statusCode(int statusCode, {required String action}) {
    if (statusCode == 401) {
      return action == 'login' ? 'qhkb_auth_failed' : 'qhkb_session_expired';
    }
    if (statusCode == 403) {
      return 'qhkb_couple_account_required';
    }
    // 服务端 400 也用于 CSRF 过期（`_token` 对不上），但 400 同时是「参数不合法」
    // 的正常业务错误，无法只凭状态码区分，因此不在这里作废会话。
    return 'qhkb_http_failed';
  }

  String? _cookieValue(http.Response response, String name) {
    for (final raw
        in response.headersSplitValues['set-cookie'] ?? const <String>[]) {
      final match = RegExp(
        '^\\s*${RegExp.escape(name)}=([^;]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      final value = match?.group(1)?.trim();
      // 空值代表服务端在清这个 Cookie，不能当成「新的空会话」写进存储。
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
