import 'dart:convert';

/// إخفاء روابط M3U داخل التطبيق
/// - مشفّرة بـ Base64
/// - تُفكّ في الذاكرة فقط
class SecureConfig {
  // ==========================================================
  //  الروابط المشفرة Base64
  //  (لتحويل رابط: استخدم موقع base64encode.org)
  // ==========================================================
  static const List<String> _encoded = [
    // ============ روابط مباشرة ============
    // PLAYLIST_1
    'aHR0cHM6Ly9tM3VleHRncm91cC5raWtpMTBra2lpaS53b3JrZXJzLmRldi9mL2d0Mml6cm14bjFuci9MaXZlX0FSLm0zdQ==',
    // PLAYLIST_2
    'aHR0cHM6Ly9tM3VleHRncm91cC5raWtpMTBra2lpaS53b3JrZXJzLmRldi9mL2h0dzBpb2xycmloay9MaXZlX1NQT1JUUy5tM3U=',
    // ============ قنوات رياضية ============
    // PLAYLIST_3
    'aHR0cHM6Ly9tM3VleHRyYWN0b3Iua2lraTEwa2tpaS53b3JrZXJzLmRldi9kb3dubG9hZC8xZjQ4MjI4ZC03NzgzLTQzYTgtODUzMy00MjI4YjRjOWJhNDMvTGl2ZV9BUiUyMF8lMjBBTFdBTiUyMFNQT1JUUy5tM3U4',
    // PLAYLIST_4
    'aHR0cHM6Ly9tM3VleHRyYWN0b3Iua2lraTEwa2tpaS53b3JrZXJzLmRldi9kb3dubG9hZC8xMjdjMmI3Yy0yMWM4LTQyZTktYTkwMy02YWFkMTAwMjk2ODMvTGl2ZV9BUiUyMF8lMjBCRUlOJTIwVE9ELm0zdTg=',
    // PLAYLIST_5
    'aHR0cHM6Ly9tM3VleHRyYWN0b3Iua2lraTEwa2tpaS53b3JrZXJzLmRldi9kb3dubG9hZC9hMzI2MGVkYy00OGQwLTQ2OTYtYWExZS0zZmI2OTE2YjJkNTEvTGl2ZV9BUiUyMF8lMjBCRUlOJTIwU1BPUlRTJTIwOEsLm0zdTg=',
    // PLAYLIST_6
    'aHR0cHM6Ly9tM3VleHRyYWN0b3Iua2lraTEwa2tpaS53b3JrZXJzLmRldi9kb3dubG9hZC8wOGNkZjAwNS0xYTZmLTQ4ZTQtODQ4Ni05MTJhZmE0ZjkxOGQvTGl2ZV9CZU!O' 'JTlBQkUlMjBCRUlOJTIwU1BPUlRTJTIwX19fQkVFX19fLm0zdTg=',
    // ============ Xtream ============
    // PLAYLIST_7
    'aHR0cDovL2Rrc2lwaS5jb206ODAvZ2V0LnBocD91c2VybmFtZT1raXJoYW0yMDI1JnBhc3N3b3JkPU0wQmZUbDJDdEsmdHlwZT1tM3VfcGx1cyZvdXRwdXQ9bTN1OA==',
    // PLAYLIST_8
    'aHR0cDovL3h0cmVhbXV0di5vcmc6ODAvZ2V0LnBocD91c2VybmFtZT03ckZnSDZzRnd5JnBhc3N3b3JkPUhTekR2eHJDeTYmdHlwZT1tM3VfcGx1cyZvdXRwdXQ9bTN1OA==',
    // PLAYLIST_9
    'aHR0cDovL3Byb2QuZHJhZ29ua2V5Lm5ldDoyMDgyL2dldC5waHA/dXNlcm5hbWU9MDAyMjg4NjYmcGFzc3dvcmQ9MnBkOTc0a2g5NSZ0eXBlPW0zdV9wbHVzJm91dHB1dD1tM3U4',
  ];

  /// فك تشفير رابط
  static String _decode(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return '';
    }
  }

  /// استخراج كل الروابط الحقيقية
  static List<String> getPlaylistUrls() {
    final result = <String>[];
    for (final enc in _encoded) {
      final url = _decode(enc);
      if (url.isNotEmpty) result.add(url);
    }
    return result;
  }

  static List<String>? _cache;
  static List<String> get urls {
    _cache ??= getPlaylistUrls();
    return _cache!;
  }
}
