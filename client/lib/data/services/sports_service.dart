// ==========================================================
//  ✅ جلب المباريات مع Retry + APIs بديلة
// ==========================================================
Future<List<SportMatch>> getTodayFootballMatches({
  bool forceRefresh = false,
}) async {
  await _initCache();
  final cacheKey = 'matches_${_dateKey(DateTime.now())}';

  // 1) حاول من الكاش أولاً
  if (!forceRefresh && _box != null) {
    try {
      final raw = _box!.get(cacheKey);
      final cachedAt = _box!.get('${cacheKey}_at');
      if (raw is String && cachedAt is int) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
        if (age < _cacheValidity) {
          final list = (jsonDecode(raw) as List)
              .map((e) => SportMatch.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}
  }

  // 2) جرّب اليوم مع retry
  List<SportMatch> today = [];
  List<SportMatch> tomorrow = [];

  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      today = await _fetchForDate(DateTime.now());
      if (today.isNotEmpty) break;
    } catch (_) {
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }

  // 3) جرّب غدًا مع retry
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      tomorrow = await _fetchForDate(
        DateTime.now().add(const Duration(days: 1)),
      );
      if (tomorrow.isNotEmpty) break;
    } catch (_) {
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }

  final all = <SportMatch>[...today, ...tomorrow];
  all.sort((a, b) => a.startTime.compareTo(b.startTime));

  // 4) احفظ في الكاش
  if (_box != null && all.isNotEmpty) {
    try {
      final jsonStr = jsonEncode(all.map((m) => m.toJson()).toList());
      await _box!.put(cacheKey, jsonStr);
      await _box!.put(
        '${cacheKey}_at',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  return all;
}

Future<List<SportMatch>> _fetchForDate(DateTime date) async {
  final d = '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ✅ جرّب عدة مفاتيح API (fallback)
  const apiKeys = ['3', '1', '2'];

  for (final key in apiKeys) {
    try {
      final url = '$_baseUrl$key/eventsday.php?d=$d&s=Soccer';
      final response = await _dio.get(url);

      if (response.statusCode != 200 || response.data == null) continue;

      final events = response.data['events'];
      if (events is! List) continue;

      final matches = <SportMatch>[];
      for (final event in events) {
        try {
          final m = _parseMatch(event);
          if (m != null) matches.add(m);
        } catch (_) {}
      }

      if (matches.isNotEmpty) {
        return matches;
      }
    } catch (_) {
      // جرّب المفتاح التالي
      continue;
    }
  }

  return [];
}
