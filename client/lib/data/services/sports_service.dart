import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ═══════════════════════════════════════════════════════════
//  نموذج المباراة
// ═══════════════════════════════════════════════════════════
class SportMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String sport;
  final DateTime startTime;
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
      status == '1H' || status == '2H' || status == 'HT' ||
      status == 'ET' || status == 'P' || status == 'LIVE';

  bool get isFinished =>
      status == 'FT' || status == 'AET' || status == 'PEN';

  bool get isUpcoming => !isLive && !isFinished;

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isTomorrow {
    final t = DateTime.now().add(const Duration(days: 1));
    return startTime.year == t.year &&
        startTime.month == t.month &&
        startTime.day == t.day;
  }

  bool get isVerySoon {
    final diff = startTime.difference(DateTime.now());
    return diff.inMinutes > 0 && diff.inMinutes <= 60;
  }

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
        startTime:
            DateTime.tryParse(json['startTime'] as String? ?? '') ??
                DateTime.now(),
        status: json['status'] as String? ?? 'NS',
        homeScore: json['homeScore'] as String?,
        awayScore: json['awayScore'] as String?,
        channel: json['channel'] as String?,
        homeLogo: json['homeLogo'] as String?,
        awayLogo: json['awayLogo'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════
//  خدمة جلب المباريات
// ═══════════════════════════════════════════════════════════
class SportsService {
  static const String _baseUrl =
      'https://www.thesportsdb.com/api/v1/json/3';
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

  // ══════════════════════════════════════════════════════════
  //  جلب المباريات (اليوم + غدًا) مع كاش
  // ══════════════════════════════════════════════════════════
  Future<List<SportMatch>> getTodayFootballMatches({
    bool forceRefresh = false,
  }) async {
    await _initCache();
    final cacheKey = 'matches_${_dateKey(DateTime.now())}';

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

    final today = await _fetchForDate(DateTime.now());
    final tomorrow = await _fetchForDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    final all = <SportMatch>[...today, ...tomorrow];
    all.sort((a, b) => a.startTime.compareTo(b.startTime));

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
          final m = _parseMatch(event);
          if (m != null) matches.add(m);
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
      final utc = DateTime.utc(
        date.year, date.month, date.day,
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

  // ══════════════════════════════════════════════════════════
  //  فلترة بالمستويات حسب الأولوية
  //  🥇 المنتخب الجزائري > 🥈 كأس العالم > 🥉 AFCON مع الجزائر
  //  > 4) الدوريات الأوروبية الكبرى
  // ══════════════════════════════════════════════════════════
  List<SportMatch> filterImportant(List<SportMatch> matches) {
    final filtered = matches.where((m) => _getPriority(m) < 999).toList();

    filtered.sort((a, b) {
      final pa = _getPriority(a);
      final pb = _getPriority(b);
      if (pa != pb) return pa.compareTo(pb);

      final aLive = a.isLive ? 0 : 1;
      final bLive = b.isLive ? 0 : 1;
      if (aLive != bLive) return aLive.compareTo(bLive);

      return a.startTime.compareTo(b.startTime);
    });

    return filtered;
  }

  int _getPriority(SportMatch m) {
    // 🥇 المنتخب الجزائري
    if (_isAlgeriaNational(m)) {
      if (m.isLive) return 0;
      return 10;
    }

    // 🥈 كأس العالم
    if (_isWorldCup(m)) {
      if (m.isLive) return 100;
      return 110;
    }

    // 🥉 كأس أمم إفريقيا مع الجزائر
    if (_isAfconWithAlgeria(m)) {
      if (m.isLive) return 200;
      return 210;
    }

    // 4) الدوريات الأوروبية الكبرى
    if (_isTopEuropeanLeague(m)) {
      if (m.isLive) return 400;
      return 410;
    }

    // ❌ مستبعد (الأندية الجزائرية + كل الباقي)
    return 999;
  }

  // 🇩🇿 المنتخب الجزائري
  bool _isAlgeriaNational(SportMatch m) {
    final patterns = [
      RegExp(r'\balgeria\b', caseSensitive: false),
      RegExp(r'\balgérie\b', caseSensitive: false),
      RegExp(r'\bالجزائر\b'),
    ];
    for (final p in patterns) {
      if (p.hasMatch(m.homeTeam) || p.hasMatch(m.awayTeam)) return true;
    }
    return false;
  }

  // 🏆 كأس العالم
  bool _isWorldCup(SportMatch m) {
    final league = m.league.toLowerCase();

    if (league.contains('fifa world cup') &&
        !league.contains('club') &&
        !league.contains('women') &&
        !league.contains('u17') &&
        !league.contains('u20') &&
        !league.contains('u23')) {
      return true;
    }
    if (league == 'world cup') return true;

    if (league.contains('world cup qualification') ||
        league.contains('world cup qualifiers')) {
      return true;
    }
    return false;
  }

  // 🌍 كأس أمم إفريقيا مع الجزائر
  bool _isAfconWithAlgeria(SportMatch m) {
    final league = m.league.toLowerCase();
    final isAfcon = league.contains('africa cup') ||
        league.contains('afcon') ||
        league.contains('caf africa cup') ||
        league.contains('africa cup of nations') ||
        league.contains('كأس أمم إفريقيا') ||
        league.contains('كأس الأمم الإفريقية');
    if (!isAfcon) return false;
    return _isAlgeriaNational(m);
  }

  // 🏆 الدوريات الأوروبية الكبرى
  bool _isTopEuropeanLeague(SportMatch m) {
    final league = m.league.toLowerCase().trim();
    if (league.isEmpty) return false;

    if (league.contains('brazilian')) return false;
    if (league.contains('egyptian')) return false;
    if (league.contains('saudi')) return false;
    if (league.contains('japanese')) return false;
    if (league.contains('chinese')) return false;
    if (league.contains('korean')) return false;
    if (league.contains('american') || league.contains('mls')) return false;
    if (league.contains('mexican')) return false;
    if (league.contains('argentinian') || league.contains('argentina')) {
      return false;
    }
    if (league.contains('turkish')) return false;
    if (league.contains('russian')) return false;
    if (league.contains('greek')) return false;
    if (league.contains('ukrainian')) return false;

    if (league.contains('uefa champions league')) return true;
    if (league.contains('uefa europa league')) return true;
    if (league.contains('uefa europa conference league')) return true;
    if (league.contains('uefa conference league')) return true;

    if (league.contains('english premier league')) return true;
    if (league == 'premier league') return true;
    if (league.contains('spanish la liga')) return true;
    if (league == 'la liga') return true;
    if (league.contains('italian serie a')) return true;
    if (league == 'serie a') return true;
    if (league.contains('german bundesliga')) return true;
    if (league == 'bundesliga') return true;
    if (league.contains('french ligue 1')) return true;
    if (league == 'ligue 1') return true;
    if (league.contains('portuguese primeira liga')) return true;
    if (league == 'primeira liga') return true;
    if (league.contains('dutch eredivisie')) return true;
    if (league == 'eredivisie') return true;

    return false;
  }

  void dispose() {
    _dio.close();
  }
}
