import 'package:dio/dio.dart';

/// نموذج المباراة
class SportMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String sport;
  final DateTime startTime;
  final String status; // "NS" (لم تبدأ), "1H", "HT", "2H", "FT"
  final String? homeScore;
  final String? awayScore;
  final String? channel; // اسم القناة الناقلة
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

  /// هل المباراة جارية الآن؟
  bool get isLive {
    return status == '1H' ||
        status == '2H' ||
        status == 'HT' ||
        status == 'ET' ||
        status == 'P' ||
        status == 'LIVE';
  }

  /// هل انتهت؟
  bool get isFinished => status == 'FT' || status == 'AET' || status == 'PEN';

  /// هل قادمة؟
  bool get isUpcoming => !isLive && !isFinished;

  /// هل تبدأ خلال 6 ساعات؟
  bool get isSoon {
    final diff = startTime.difference(DateTime.now());
    return diff.inMinutes > 0 && diff.inHours < 6;
  }

  /// الوقت المتبقي
  String get timeUntilStart {
    if (isLive) return 'الآن';
    if (isFinished) return 'انتهت';

    final diff = startTime.difference(DateTime.now());
    if (diff.isNegative) return 'بدأت';

    if (diff.inHours > 0) {
      return 'بعد ${diff.inHours}س ${diff.inMinutes % 60}د';
    }
    return 'بعد ${diff.inMinutes}د';
  }

  /// الوقت بصيغة HH:mm
  String get formattedTime {
    final h = startTime.hour.toString().padLeft(2, '0');
    final m = startTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// النتيجة كنص
  String get scoreText {
    if (homeScore == null || awayScore == null) return 'VS';
    return '$homeScore - $awayScore';
  }
}

/// خدمة جلب المباريات
class SportsService {
  static const String _baseUrl = 'https://www.thesportsdb.com/api/v1/json/3';
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  final Dio _dio;

  SportsService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': vlcUserAgent,
            'Accept': 'application/json',
          },
        ));

  /// جلب مباريات اليوم لكرة القدم
  Future<List<SportMatch>> getTodayFootballMatches() async {
    try {
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final url = '$_baseUrl/eventsday.php?d=$date&s=Soccer';
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

      // ترتيب حسب وقت البدء
      matches.sort((a, b) => a.startTime.compareTo(b.startTime));

      return matches;
    } catch (e) {
      // ignore: avoid_print
      print('فشل جلب المباريات: $e');
      return [];
    }
  }
  
  /// تحويل JSON إلى SportMatch
  SportMatch? _parseMatch(dynamic event) {
    if (event is! Map) return null;

    final id = event['idEvent']?.toString() ?? '';
    final home = event['strHomeTeam']?.toString() ?? '';
    final away = event['strAwayTeam']?.toString() ?? '';

    if (id.isEmpty || home.isEmpty || away.isEmpty) return null;

    // وقت البدء
    final dateStr = event['dateEvent']?.toString() ?? '';
    final timeStr = event['strTime']?.toString() ?? '00:00:00';

    DateTime startTime;
    try {
      final date = DateTime.parse(dateStr);
      final timeParts = timeStr.split(':');
      startTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(timeParts[0]) ?? 0,
        int.tryParse(timeParts[1]) ?? 0,
      );
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

  /// ✅ فلترة المباريات المهمة (الدوريات الكبرى)
  List<SportMatch> filterImportant(List<SportMatch> matches) {
    // الكلمات المفتاحية للدوريات المهمة في المنطقة العربية
    const importantLeagues = [
      'champions league', 'europa league', 'premier league',
      'la liga', 'serie a', 'bundesliga', 'ligue 1',
      'world cup', 'africa cup', 'arab cup', 'saudi',
      'egyptian', 'moroccan', 'algerian', 'tunisian',
      'botola', 'ligue professionnelle', 'qatar', 'uae',
      'afc champions', 'caf', 'fifa', 'uefa',
      'دوري', 'كأس', 'أبطال',
    ];

    final filtered = matches.where((m) {
      final text = '${m.league.toLowerCase()} ${m.homeTeam.toLowerCase()} ${m.awayTeam.toLowerCase()}';
      for (final keyword in importantLeagues) {
        if (text.contains(keyword)) return true;
      }
      // إذا كانت المباراة جارية أو قريبة → أظهرها
      if (m.isLive) return true;
      if (m.isSoon) return true;
      return false;
    }).toList();

    return filtered;
  }

  void dispose() {
    _dio.close();
  }
}
