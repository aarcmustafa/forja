import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// نموذج المباراة
class SportMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String sport;
  final DateTime startTime;  // ✅ التوقيت المحلي (بعد التحويل)
  final String status;
  final String? homeScore;
  final String? awayScore;
  final String? channel;
  final String? homeLogo;
  final String? awayLogo;

  const SportMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.sport,
    required this.startTime,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.channel,
    this.homeLogo,
    this.awayLogo,
  });

  bool get isLive =>
      status == '1H' ||
      status == '2H' ||
      status == 'HT' ||
      status == 'ET' ||
      status == 'P' ||
      status == 'LIVE';

  bool get isFinished =>
      status == 'FT' || status == 'AET' || status == 'PEN';

  bool get isUpcoming => !isLive && !isFinished;

  /// ✅ هل اليوم؟
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// ✅ هل غدًا؟
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return startTime.year == tomorrow.year &&
        startTime.month == tomorrow.month &&
        startTime.day == tomorrow.day;
  }

  /// ✅ هل خلال الساعة القادمة؟
  bool get isVerySoon {
    final diff = startTime.difference(DateTime.now());
    return diff.inMinutes > 0 && diff.inMinutes <= 60;
  }

  /// ✅ هل خلال 6 ساعات؟
  bool get isSoon {
    final diff = startTime.difference(DateTime.now());
    return diff.inMinutes > 0 && diff.inHours < 6;
  }

  String get timeUntilStart {
    if (isLive) return 'الآن';
    if (isFinished) return 'انتهت';

    final diff = startTime.difference(DateTime.now());
    if (diff.isNegative) return 'بدأت';

    if (diff.inDays > 0) return 'بعد ${diff.inDays} يوم';
    if (diff.inHours > 0) {
      return 'بعد ${diff.inHours}س ${diff.inMinutes % 60}د';
    }
    return 'بعد ${diff.inMinutes}د';
  }

  /// ✅ الوقت بتوقيت محلي (بعد التحويل)
  String get formattedTime {
    final h = startTime.hour.toString().padLeft(2, '0');
    final m = startTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get scoreText {
    if (homeScore == null || awayScore == null) return 'VS';
    if (homeScore!.isEmpty || awayScore!.isEmpty) return 'VS';
    return '$homeScore - $awayScore';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'home': homeTeam,
        'away': awayTeam,
        'league': league,
        'sport': sport,
        'startTime': startTime.toIso8601String(),
        'status': status,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'channel': channel,
        'homeLogo': homeLogo,
        'awayLogo': awayLogo,
      };

  factory SportMatch.fromJson(Map<String, dynamic> json) => SportMatch(
        id: json['id'] as String? ?? '',
        homeTeam: json['home'] as String? ?? '',
        awayTeam: json['away'] as String? ?? '',
        league: json['league'] as String? ?? '',
        sport: json['sport'] as String? ?? 'Soccer',
        startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as String? ?? 'NS',
        homeScore: json['homeScore'] as String?,
        awayScore: json['awayScore'] as String?,
        channel: json['channel'] as String?,
        homeLogo: json['homeLogo'] as String?,
        awayLogo: json['awayLogo'] as String?,
      );
}
/// خدمة جلب المباريات
class SportsService {
  static const String _baseUrl = 'https://www.thesportsdb.com/api/v1/json/3';
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const String _boxName = 'sports_cache';
  static const Duration _cacheValidity = Duration(minutes: 15);

  final Dio _dio;
  Box? _box;

  SportsService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': vlcUserAgent,
            'Accept': 'application/json',
          },
        ));

  Future<void> _initCache() async {
    if (_box != null) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
    } catch (_) {}
  }

  // ==========================================================
  //  جلب المباريات (اليوم + غدًا) مع كاش
  // ==========================================================
  Future<List<SportMatch>> getTodayFootballMatches({
    bool forceRefresh = false,
  }) async {
    await _initCache();

    final cacheKey = 'matches_${_dateKey(DateTime.now())}';

    // 1) حاول من الكاش
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

    // 2) اجلب من API — اليوم وغدًا
    final today = await _fetchForDate(DateTime.now());
    final tomorrow = await _fetchForDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    final all = <SportMatch>[...today, ...tomorrow];
    all.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 3) احفظ في الكاش
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
    try {
      final d = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final url = '$_baseUrl/eventsday.php?d=$d&s=Soccer';
      final response = await _dio.get(url);

      if (response.statusCode != 200 || response.data == null) return [];

      final events = response.data['events'];
      if (events is! List) return [];

      final matches = <SportMatch>[];
      for (final event in events) {
        try {
          final match = _parseMatch(event);
          if (match != null) matches.add(match);
        } catch (_) {}
      }
      return matches;
    } catch (_) {
      return [];
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ==========================================================
  //  ✅ تحويل JSON → SportMatch (مع توقيت محلي صحيح)
  // ==========================================================
  SportMatch? _parseMatch(dynamic event) {
    if (event is! Map) return null;

    final id = event['idEvent']?.toString() ?? '';
    final home = event['strHomeTeam']?.toString() ?? '';
    final away = event['strAwayTeam']?.toString() ?? '';
    if (id.isEmpty || home.isEmpty || away.isEmpty) return null;

    final dateStr = event['dateEvent']?.toString() ?? '';
    final timeStr = event['strTime']?.toString() ?? '00:00:00';

    DateTime startTime;
    try {
      final date = DateTime.parse(dateStr);
      final parts = timeStr.split(':');

      // ✅ TheSportsDB يُرجع UTC — نحوّله لمحلي
      final utc = DateTime.utc(
        date.year,
        date.month,
        date.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      startTime = utc.toLocal();
    } catch (_) {
      startTime = DateTime.now();
    }

    return SportMatch(
      id: id,
      homeTeam: home,
      awayTeam: away,
      league: event['strLeague']?.toString() ?? '',
      sport: 'Soccer',
      startTime: startTime,
      status: event['strStatus']?.toString() ?? 'NS',
      homeScore: event['intHomeScore']?.toString(),
      awayScore: event['intAwayScore']?.toString(),
      channel: event['strTVStation']?.toString(),
      homeLogo: event['strHomeTeamBadge']?.toString(),
      awayLogo: event['strAwayTeamBadge']?.toString(),
    );
  }

  void dispose() {
    _dio.close();
  }
}
  // ==========================================================
  //  ✅ فلترة المباريات المهمة (مُوسَّعة)
  // ==========================================================
  List<SportMatch> filterImportant(List<SportMatch> matches) {
    // ══════════════════════════════════════════════════════
    //  دوريات كبرى (إنجليزية)
    // ══════════════════════════════════════════════════════
    const majorLeaguesEn = [
      // أوروبا
      'champions league', 'europa league', 'conference league',
      'premier league', 'la liga', 'serie a', 'bundesliga',
      'ligue 1', 'eredivisie', 'primeira liga',
      // عالمية
      'world cup', 'club world cup', 'fifa',
      // عربية
      'afc champions', 'afc cup', 'caf champions', 'caf confederation',
      'arab cup', 'arab club',
      // الدوريات العربية
      'saudi', 'egyptian', 'moroccan', 'algerian', 'tunisian',
      'botola', 'ligue professionnelle', 'qatar', 'uae', 'kuwait',
      'stars league', 'roshn', 'mobilis',
      // عام
      'uefa', 'caf', 'afc',
    ];

    // ══════════════════════════════════════════════════════
    //  دوريات عربية (بالعربية — إن وردت)
    // ══════════════════════════════════════════════════════
    const majorLeaguesAr = [
      'دوري', 'كأس', 'أبطال', 'الرابطة',
      'السعودي', 'المصري', 'المغربي', 'الجزائري', 'التونسي',
      'الممتاز', 'المحترفين',
    ];

    return matches.where((m) {
      // ✅ 1) المباشر دائمًا
      if (m.isLive) return true;

      // ✅ 2) المباريات اليوم أو غدًا: اقبلها دائمًا
      if (m.isToday || m.isTomorrow) return true;

      // ✅ 3) فلترة حسب الدوري (إن كانت مباراة بعيدة)
      final text = '${m.league} ${m.homeTeam} ${m.awayTeam}'.toLowerCase();

      for (final k in majorLeaguesEn) {
        if (text.contains(k)) return true;
      }
      for (final k in majorLeaguesAr) {
        if (text.contains(k)) return true;
      }

      // ✅ 4) إن لم تُطابق أي دوري → اقبلها (لا تقصيها)
      // نُبقي كل المباريات لأن المستخدم يريد رؤيتها
      return true;
    }).toList();
  }
}
