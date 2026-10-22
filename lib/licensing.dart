import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local trial and signed-license state. The private signing key must never ship
/// with the app; only the Ed25519 public key is embedded here.
class VideoForgeLicensing {
  VideoForgeLicensing(this._prefs);

  final SharedPreferences _prefs;
  static const trialDays = 7;
  static const clockTolerance = Duration(hours: 1);
  static const _trialStartKey = 'videoforge.license.trialStartUtc';
  static const _lastTimeKey = 'videoforge.license.lastObservedUtc';
  static const _lastNetworkCheckKey = 'videoforge.license.lastNetworkCheckUtc';
  static const _networkCheckInterval = Duration(hours: 24);
  static const _clockBlockedKey = 'videoforge.license.clockBlocked';
  static const _licenseKey = 'videoforge.license.signedToken';
  static const _installIdKey = 'videoforge.license.installId';
  // Raw 32-byte Ed25519 public key, URL-safe base64 without padding.
  static const _serverPublicKeyB64 = 'GnsZ29_XWf1j40y-R0mWNjWmRryjPmhqltGN7M_KroY';
  static const _activationEndpoint = String.fromEnvironment('LICENSE_SERVER_URL', defaultValue: '');
  static const _timeHosts = <String>[
    'https://ya.ru/',
    'https://www.google.com/',
    'https://www.microsoft.com/',
    'https://www.cloudflare.com/',
    'https://www.apple.com/',
  ];

  DateTime? trustedNow;
  DateTime? trialEndsAt;
  bool clockBlocked = false;
  String? activeLicenseId;
  String status = 'Проверяем лицензию…';
  bool isLicensed = false;
  bool initialized = false;
  String? installId;

  bool get isTrialActive => !isLicensed && !clockBlocked && trialEndsAt != null &&
      (trustedNow ?? DateTime.now().toUtc()).isBefore(trialEndsAt!);
  bool get isAllowed => isLicensed || isTrialActive;
  int get trialDaysLeft {
    if (trialEndsAt == null) return 0;
    final remaining = trialEndsAt!.difference(trustedNow ?? DateTime.now().toUtc());
    if (remaining <= Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  Future<void> initialize() async {
    installId = _prefs.getString(_installIdKey);
    if (installId == null || installId!.isEmpty) {
      final random = Random.secure();
      installId = List<int>.generate(24, (_) => random.nextInt(256))
          .map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      await _prefs.setString(_installIdKey, installId!);
    }
    clockBlocked = _prefs.getBool(_clockBlockedKey) ?? false;
    await refreshTimeAndLicense();
  }

  Future<void> refreshTimeAndLicense({bool forceNetworkCheck = false}) async {
    final localNow = DateTime.now().toUtc();
    final lastNetworkCheckMs = _prefs.getInt(_lastNetworkCheckKey);
    final shouldCheckNetwork = forceNetworkCheck || lastNetworkCheckMs == null ||
        localNow.difference(DateTime.fromMillisecondsSinceEpoch(lastNetworkCheckMs, isUtc: true)) >= _networkCheckInterval ||
        localNow.isBefore(DateTime.fromMillisecondsSinceEpoch(lastNetworkCheckMs, isUtc: true));
    final networkTimes = shouldCheckNetwork ? await _fetchNetworkTimes() : <DateTime>[];
    if (shouldCheckNetwork) {
      await _prefs.setInt(_lastNetworkCheckKey, localNow.millisecondsSinceEpoch);
    }
    DateTime effectiveNow = localNow;
    if (networkTimes.isNotEmpty) {
      networkTimes.sort();
      effectiveNow = networkTimes[networkTimes.length ~/ 2];
      final skew = effectiveNow.difference(localNow);
      if (skew > clockTolerance) {
        // Device is more than one hour behind network time.
        clockBlocked = true;
        isLicensed = false;
        activeLicenseId = null;
        await _prefs.remove(_licenseKey);
        await _prefs.setBool(_clockBlockedKey, true);
        status = 'Часы устройства отстают более чем на час. Ключ удалён; выставьте правильное время и повторите проверку.';
      } else if (skew >= -clockTolerance) {
        // Only a reasonably aligned clock clears a previous violation.
        clockBlocked = false;
        await _prefs.setBool(_clockBlockedKey, false);
        status = 'Сетевое время проверено.';
      } else {
        // Device clock is ahead: do not delete the key and do not clear a block.
        status = 'Часы устройства спешат. Ключ не изменён; проверка требует корректных часов.';
      }
    } else {
      status = 'Нет сети: используется время устройства.';
    }

    final previousMs = _prefs.getInt(_lastTimeKey);
    if (previousMs != null) {
      final previous = DateTime.fromMillisecondsSinceEpoch(previousMs, isUtc: true);
      // Offline rollback guard. Keep the highest observed time, never move it back.
      if (networkTimes.isEmpty && localNow.add(const Duration(minutes: 5)).isBefore(previous)) {
        clockBlocked = true;
        isLicensed = false;
        activeLicenseId = null;
        await _prefs.remove(_licenseKey);
        await _prefs.setBool(_clockBlockedKey, true);
        status = 'Обнаружен откат системного времени. Подключитесь к интернету и восстановите правильные часы.';
      }
      if (networkTimes.isEmpty && effectiveNow.isBefore(previous)) {
        // Even a small offline rollback cannot extend the trial: clamp time to
        // the greatest previously observed timestamp.
        effectiveNow = previous;
      }
      if (effectiveNow.isAfter(previous)) {
        await _prefs.setInt(_lastTimeKey, effectiveNow.millisecondsSinceEpoch);
      }
    } else {
      await _prefs.setInt(_lastTimeKey, effectiveNow.millisecondsSinceEpoch);
    }
    trustedNow = effectiveNow;

    var startMs = _prefs.getInt(_trialStartKey);
    if (startMs == null) {
      startMs = effectiveNow.millisecondsSinceEpoch;
      await _prefs.setInt(_trialStartKey, startMs);
    }
    final start = DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
    trialEndsAt = start.add(const Duration(days: trialDays));

    if (!clockBlocked) {
      final token = _prefs.getString(_licenseKey);
      if (token != null) {
        final parsed = await _validateToken(token, effectiveNow);
        isLicensed = parsed != null;
        activeLicenseId = parsed?['licenseId'] as String?;
        if (!isLicensed) await _prefs.remove(_licenseKey);
      } else {
        isLicensed = false;
      }
    } else {
      isLicensed = false;
      activeLicenseId = null;
    }
    if (clockBlocked) {
      // Preserve the more specific clock warning.
    } else if (isLicensed) {
      status = 'Лицензия активна${activeLicenseId == null ? '' : ': $activeLicenseId'}';
    } else if (isTrialActive) {
      status = 'Пробный период: осталось $trialDaysLeft дн.';
    } else {
      status = 'Пробный период завершён. Введите лицензионный ключ.';
    }
    initialized = true;
  }

  Future<List<DateTime>> _fetchNetworkTimes() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    Future<DateTime?> readHost(String host) async {
      try {
        final request = await client.openUrl('HEAD', Uri.parse(host)).timeout(const Duration(seconds: 5));
        request.followRedirects = true;
        final response = await request.close().timeout(const Duration(seconds: 5));
        final dateHeader = response.headers.value(HttpHeaders.dateHeader);
        DateTime? parsed;
        if (response.statusCode >= 200 && response.statusCode < 400 && dateHeader != null) {
          final value = HttpDate.parse(dateHeader).toUtc();
          if (value.isAfter(DateTime.utc(2020)) && value.isBefore(DateTime.now().toUtc().add(const Duration(days: 2)))) parsed = value;
        }
        await response.drain<void>();
        return parsed;
      } catch (_) {
        return null;
      }
    }
    try {
      final responses = await Future.wait(_timeHosts.map(readHost)).timeout(const Duration(seconds: 7), onTimeout: () => <DateTime?>[]);
      final results = responses.whereType<DateTime>().toList();
      // Require at least two independent HTTPS sources to avoid trusting one bad response.
      return results.length >= 2 ? results : <DateTime>[];
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, Object?>?> _validateToken(String token, DateTime now) async {
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3 || parts[0] != 'VFL1') return null;
      final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final signature = base64Url.decode(base64Url.normalize(parts[2]));
      final publicBytes = base64Url.decode(base64Url.normalize(_serverPublicKeyB64));
      final publicKey = SimplePublicKey(publicBytes, type: KeyPairType.ed25519);
      final valid = await Ed25519().verify(payloadBytes, signature: Signature(signature, publicKey: publicKey));
      if (!valid) return null;
      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final expiry = decoded['expiresAt'] as int?;
      final licenseId = decoded['licenseId'] as String?;
      final boundInstallId = decoded['installId'] as String?;
      if (expiry == null || licenseId == null || licenseId.isEmpty) return null;
      if (boundInstallId == null || boundInstallId != installId) return null;
      if (decoded['email'] is! String || (decoded['email'] as String).isEmpty) return null;
      if (decoded['activatedAt'] is! int) return null;
      if (!now.isBefore(DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true))) return null;
      return Map<String, Object?>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<String?> activate(String voucher, String email) async {
    if (clockBlocked) return 'Сначала восстановите правильное время и выполните проверку через интернет.';
    if (_activationEndpoint.isEmpty) {
      return 'Сервер активации не настроен. Соберите приложение с --dart-define=LICENSE_SERVER_URL=https://ваш-домен/v1/activate.';
    }
    final endpoint = Uri.tryParse(_activationEndpoint);
    if (endpoint == null || endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      return 'Адрес сервера активации должен использовать HTTPS.';
    }
    if (email.trim().isEmpty || !email.contains('@')) return 'Введите email, на который выпущен ключ.';
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 10));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(<String, Object>{
          'key': voucher.trim(),
          'email': email.trim().toLowerCase(),
          'installId': installId!,
        }));
        final response = await request.close().timeout(const Duration(seconds: 15));
        final body = await utf8.decoder.bind(response).join();
        Map<String, dynamic> decoded = <String, dynamic>{};
        try { decoded = jsonDecode(body) as Map<String, dynamic>; } catch (_) {}
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final detail = decoded['detail']?.toString();
          return detail ?? 'Сервер отклонил активацию (HTTP ${response.statusCode}).';
        }
        final token = decoded['licenseToken'] as String?;
        if (token == null || token.isEmpty) return 'Сервер вернул некорректный ответ.';
        final parsed = await _validateToken(token, trustedNow ?? DateTime.now().toUtc());
        if (parsed == null || parsed['email']?.toString().toLowerCase() != email.trim().toLowerCase()) {
          return 'Подписанная лицензия недействительна или выпущена для другого email/устройства.';
        }
        await _prefs.setString(_licenseKey, token);
        await refreshTimeAndLicense();
        return isLicensed ? null : status;
      } finally {
        client.close(force: true);
      }
    } on TimeoutException {
      return 'Сервер активации не ответил вовремя. Проверьте интернет и повторите попытку.';
    } on SocketException {
      return 'Нет соединения с сервером активации.';
    } catch (e) {
      return 'Ошибка активации: $e';
    }
  }

  Future<void> clearLicense() async {
    await _prefs.remove(_licenseKey);
    await refreshTimeAndLicense();
  }
}
