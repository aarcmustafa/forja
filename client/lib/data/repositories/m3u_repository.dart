import 'package:dio/dio.dart';
import '../models/channel.dart';
import 'xtream_client.dart';

/// مستودع موحّد — Xtream API + M3U مباشر + VLC UA
class M3uRepository {
  // ==========================================================
  //  User Agents للتجربة بالتتابع
  // ==========================================================
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const List<String> fallbackUserAgents = [
    'VLC/3.0.20 LibVLC/3.0.20',
    'IPTV Smarters Pro',
    'okhttp/4.9.0',
    'TiviMate/4.7.0',
    'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];

  // ==========================================================
  //  استخراج Referer من الرابط
  // ==========================================================
  static String extractReferer(String url) {
    try {
      final uri = Uri.parse(url);
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portPart/';
    } catch (_) {
      return '';
    }
  }

  static String extractOrigin(String url) {
    try {
      final uri = Uri.parse(url);
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portPart';
    } catch (_) {
      return '';
    }
  }

  static Map<String, String> standardHeaders(String url) {
    final referer = extractReferer(url);
    return {
      'User-Agent': vlcUserAgent,
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      if (referer.isNotEmpty) 'Referer': referer,
      if (referer.isNotEmpty) 'Origin': extractOrigin(url),
    };
  }

  // ==========================================================
  //  الحالة
  // ==========================================================
  final Dio _dio;
  final Map<String, List<Channel>> _cache = {};

  M3uRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 180),
              sendTimeout: const Duration(seconds: 30),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (status) => status != null && status < 500,
              headers: {
                'User-Agent': vlcUserAgent,
                'Accept': '*/*',
                'Accept-Encoding': 'gzip, deflate',
                'Connection': 'keep-alive',
                'Icy-MetaData': '1',
              },
            ));

  // ==========================================================
  //  الدالة الرئيسية — تحميل من رابط (Hybrid)
  // ==========================================================
  Future<List<Channel>> loadFromUrl(
    String url, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(url)) {
      return _cache[url]!;
    }

    // ✅ كشف Xtream تلقائياً
    final credentials = XtreamDetector.extract(url);
    if (credentials != null) {
      // 🎯 Xtream API (أسرع 30 مرة)
      final channels = await _loadFromXtream(credentials);
      _cache[url] = channels;
      return channels;
    }

    // 📄 M3U مباشر (workers.dev etc)
    final channels = await _loadFromM3u(url);
    _cache[url] = channels;
    return channels;
  }
  
// ==========================================================
//  تحميل من Xtream API
// ==========================================================
Future<List<Channel>> _loadFromXtream(
  XtreamCredentials credentials,
) async {
  final client = XtreamClient(credentials);
  final all = <Channel>[];

  try {
    // 1) القنوات المباشرة
    try {
      final liveCats = await client.getLiveCategories();
      final live = await client.getLiveStreams(categories: liveCats);
      all.addAll(live);
      // ignore: avoid_print
      print('✅ Xtream Live: ${live.length} قناة');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ فشل جلب القنوات: $e');
    }

    // 2) الأفلام (VOD)
    try {
      final vodCats = await client.getVodCategories();
      final vod = await client.getVodStreams(categories: vodCats);
      all.addAll(vod);
      // ignore: avoid_print
      print('✅ Xtream VOD: ${vod.length} فيلم');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ فشل جلب الأفلام: $e');
    }

    // 3) المسلسلات
    try {
      final seriesCats = await client.getSeriesCategories();
      final series = await client.getSeries(categories: seriesCats);
      all.addAll(series);
      // ignore: avoid_print
      print('✅ Xtream Series: ${series.length} مسلسل');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ فشل جلب المسلسلات: $e');
    }

    // إذا فشل كل شيء → ارجع فارغاً
    if (all.isEmpty) {
      // ignore: avoid_print
      print('❌ Xtream: لم تُجلب أي بيانات، سنستخدم M3U');
      // Fallback إلى M3U
      return await _loadFromM3u(
        '${credentials.server}/get.php?username=${credentials.username}&password=${credentials.password}&type=m3u_plus&output=m3u8',
      );
    }

    return all;
  } finally {
    client.dispose();
  }
}

// ==========================================================
//  تحميل من M3U (مع Fallback UA)
// ==========================================================
Future<List<Channel>> _loadFromM3u(String url) async {
  final data = await _fetchWithFallback(url);

  if (data == null || data.isEmpty) {
    throw Exception('فشل تحميل الملف بعد تجربة كل User-Agents');
  }

  return parseM3uContent(data);
}

/// تجربة عدة User-Agents حتى يعمل أحدها
Future<String?> _fetchWithFallback(String url) async {
  for (int i = 0; i < fallbackUserAgents.length; i++) {
    final ua = fallbackUserAgents[i];

    try {
      final headers = <String, String>{
        'User-Agent': ua,
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Icy-MetaData': '1',
      };

      final referer = extractReferer(url);
      if (referer.isNotEmpty) {
        headers['Referer'] = referer;
        headers['Origin'] = extractOrigin(url);
      }

      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
        ),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data!.isNotEmpty) {
        // ignore: avoid_print
        print('✅ M3U حمّل بنجاح بـ UA: $ua');
        return response.data;
      }

      // ignore: avoid_print
      print('⚠️ UA[$i] فشل: رمز ${response.statusCode}');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ UA[$i] خطأ: $e');
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }
  return null;
}

// ==========================================================
//  تحليل M3U
// ==========================================================
List<Channel> parseM3uContent(String content) {
  final lines = content.split('\n');
  final channels = <Channel>[];
  Map<String, String>? currentInfo;
  String? currentName;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTM3U')) continue;

    if (line.startsWith('#EXTINF:')) {
      currentInfo = _parseExtInf(line);
      currentName = _extractName(line);
      continue;
    }

    if (line.startsWith('#')) continue;

    if (currentInfo != null && currentName != null) {
      final channel = _buildChannel(
        name: currentName,
        url: line,
        info: currentInfo,
      );
      channels.add(channel);
      currentInfo = null;
      currentName = null;
    }
  }

  return channels;
}

Map<String, String> _parseExtInf(String line) {
  final info = <String, String>{};
  final regex = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');
  for (final match in regex.allMatches(line)) {
    info[match.group(1)!] = match.group(2)!;
  }
  return info;
}

String _extractName(String line) {
  final commaIndex = line.lastIndexOf(',');
  if (commaIndex == -1 || commaIndex == line.length - 1) {
    return 'قناة غير معروفة';
  }
  return line.substring(commaIndex + 1).trim();
}

Channel _buildChannel({
  required String name,
  required String url,
  required Map<String, String> info,
}) {
  final group = info['group-title'] ?? 'غير مصنف';
  final tvgId = info['tvg-id'] ?? '';
  final logo = info['tvg-logo'] ?? '';

  final customReferer = info['referer'] ?? info['http-referrer'] ?? '';
  final customUA = info['user-agent'] ?? info['http-user-agent'] ?? '';

  final category = _inferCategory(name, group);
  final contentType = _inferContentType(name, group, url);
  final language = _inferLanguage(name, group);
  final countryCode = _inferCountry(name, group);
  final genre = _inferGenre(name, group);
  final translation = _inferTranslation(name, group);
  final year = _extractYear(name);
  final originalName = _extractOriginalName(name);
  final priority = _calculatePriority(url);

  final extras = <String, String>{};
  if (customReferer.isNotEmpty) extras['referer'] = customReferer;
  if (customUA.isNotEmpty) extras['user_agent'] = customUA;

  return Channel(
    id: _generateId(name, url),
    name: _cleanName(name),
    originalName: originalName,
    logo: logo,
    streamUrl: url,
    group: group,
    category: category,
    language: language,
    countryCode: countryCode,
    genre: genre,
    contentType: contentType,
    translation: translation,
    year: year,
    isWorking: true,
    priority: priority,
    tvgId: tvgId,
    extras: extras,
  );
}
  
  // ==========================================================
  //  أدوات مساعدة
  // ==========================================================
  String _generateId(String name, String url) {
    return '${name.hashCode}_${url.hashCode}';
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^\s*[-•·|]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? _extractYear(String name) {
    final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(name);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    if (year == null) return null;
    if (year < 1950 || year > 2030) return null;
    return year;
  }

  String _extractOriginalName(String name) {
    final match =
        RegExp(r'\(([A-Za-z0-9\s\:\-\.\,\!\?]+)\)').firstMatch(name);
    if (match != null) return match.group(1)!.trim();
    if (RegExp(r'^[A-Za-z0-9\s\:\-\.\,\!\?]+$').hasMatch(name)) {
      return name.trim();
    }
    return '';
  }

  // ==========================================================
  //  التصنيف الذكي
  // ==========================================================
  String _inferCategory(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, [
      'bein', 'sport', 'ssc', 'رياض', 'كورة', 'alkass',
      'dubai sport', 'ad sport', 'ksa sport', 'alwan sport',
      'sky sport', 'espn', 'dazn', 'nba', 'nfl',
    ])) return 'sport';

    if (_contains(text, [
      'series', 'serie', 'drama', 'مسلسل', 'مسلسلات', 'دراما',
      'soap', 'telenovela',
    ])) return 'series';

    if (_contains(text, [
      'movie', 'movies', 'cinema', 'film', 'films', 'vod',
      'أفلام', 'فيلم', 'سينما',
    ])) return 'movie';

    if (_contains(text, ['anime', 'أنمي', 'manga'])) return 'movie';

    if (_contains(text, [
      'news', 'أخبار', 'alarabiya', 'jazeera', 'sky news',
      'cnn', 'bbc', 'france 24', 'rt',
    ])) return 'news';

    if (_contains(text, [
      'kid', 'kids', 'cartoon', 'أطفال', 'كرتون', 'spacetoon',
      'mbc3', 'baby', 'junior',
    ])) return 'kids';

    if (_contains(text, [
      'documentary', 'docu', 'وثائقي', 'nat geo', 'discovery',
      'history', 'animal planet',
    ])) return 'documentary';

    if (_contains(text, ['music', 'موسيقى', 'mtv', 'rotana', 'mazzika'])) {
      return 'music';
    }

    if (_contains(text, [
      'quran', 'قرآن', 'islam', 'إسلام', 'دين', 'religious',
      'makkah', 'madinah', 'sunna',
    ])) return 'religious';

    return 'general';
  }

  String _inferContentType(String name, String group, String url) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, ['series', 'serie', 'مسلسل', 'مسلسلات'])) {
      return 'series';
    }
    if (_contains(text, [
      'movie', 'movies', 'film', 'vod', 'أفلام', 'فيلم',
      'cinema', 'anime', 'أنمي',
    ])) return 'movie';

    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('/movie/') || lowerUrl.contains('/vod/')) {
      return 'movie';
    }
    if (lowerUrl.contains('/series/')) return 'series';

    return 'live';
  }

  String _inferLanguage(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, ['anime', 'أنمي', 'manga'])) return 'anime';
    if (_contains(text, ['korean', 'كوري', 'k-drama', 'kdrama'])) {
      return 'kor';
    }
    if (_contains(text, ['japan', 'ياباني', 'j-drama', 'jdrama'])) {
      return 'jpn';
    }
    if (_contains(text, [
      'hindi', 'bollywood', 'هندي', 'الهند', 'india', 'indian',
    ])) return 'hin';
    if (_contains(text, ['turk', 'turkish', 'تركي', 'تركية', 'türk'])) {
      return 'tur';
    }
    if (_contains(text, [
      'foreign', 'اجنبي', 'أجنبي', 'english', 'usa', 'uk',
      'american', 'hollywood', 'west',
    ])) return 'eng';
    if (_contains(text, ['french', 'franc', 'فرنسي'])) return 'fra';
    if (_contains(text, [
      'asian', 'اسيوي', 'أسيوي', 'china', 'chinese', 'صيني',
      'thai', 'تايلندي', 'vietnam', 'philippines',
    ])) return 'asian';

    return 'ara';
  }

  String _inferCountry(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, ['saudi', 'ksa', 'سعودي', 'السعودية'])) return 'SA';
    if (_contains(text, [
      'emarat', 'uae', 'امارات', 'الإمارات', 'dubai', 'abu dhabi',
    ])) return 'AE';
    if (_contains(text, ['egypt', 'مصر', 'مصري', 'cairo'])) return 'EG';
    if (_contains(text, ['morocco', 'مغرب', 'مغربي'])) return 'MA';
    if (_contains(text, ['algeria', 'جزائر', 'جزائري'])) return 'DZ';
    if (_contains(text, ['tunisia', 'تونس', 'تونسي'])) return 'TN';
    if (_contains(text, ['iraq', 'عراق', 'عراقي', 'بغداد'])) return 'IQ';
    if (_contains(text, ['kuwait', 'كويت', 'كويتي'])) return 'KW';
    if (_contains(text, ['qatar', 'قطر', 'قطري'])) return 'QA';
    if (_contains(text, ['jordan', 'أردن', 'اردن'])) return 'JO';
    if (_contains(text, ['lebanon', 'لبنان', 'لبناني'])) return 'LB';
    if (_contains(text, ['syria', 'سوريا', 'سوري'])) return 'SY';
    if (_contains(text, ['yemen', 'يمن', 'يمني'])) return 'YE';
    if (_contains(text, ['oman', 'عمان', 'عُمان'])) return 'OM';
    if (_contains(text, ['bahrain', 'بحرين', 'بحريني'])) return 'BH';
    if (_contains(text, ['sudan', 'سودان', 'سوداني'])) return 'SD';
    if (_contains(text, ['libya', 'ليبيا', 'ليبي'])) return 'LY';
    if (_contains(text, ['palestin', 'فلسطين', 'فلسطيني', 'غزة'])) {
      return 'PS';
    }
    if (_contains(text, ['mauritania', 'موريتانيا'])) return 'MR';

    final codeMatch = RegExp(
            r'\b(SA|AE|EG|MA|DZ|TN|IQ|KW|QA|JO|LB|SY|YE|OM|BH|SD|LY|PS|MR)\b')
        .firstMatch(group.toUpperCase());
    if (codeMatch != null) return codeMatch.group(1)!;

    return '';
  }

  String _inferGenre(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, ['action', 'أكشن', 'اكشن'])) return 'action';
    if (_contains(text, ['drama', 'دراما'])) return 'drama';
    if (_contains(text, ['comedy', 'كوميدي', 'ضحك', 'funny'])) {
      return 'comedy';
    }
    if (_contains(text, ['horror', 'رعب', 'مخيف', 'scary'])) return 'horror';
    if (_contains(text, ['romance', 'رومانس', 'رومانسي', 'love', 'حب'])) {
      return 'romance';
    }
    if (_contains(text, ['thriller', 'إثارة', 'اثارة'])) return 'thriller';
    if (_contains(text, ['sci-fi', 'scifi', 'خيال علمي', 'space'])) {
      return 'scifi';
    }
    if (_contains(text, ['fantasy', 'فانتازيا', 'fairy'])) return 'fantasy';
    if (_contains(text, ['animation', 'رسوم متحركة', 'انيميشن'])) {
      return 'animation';
    }
    if (_contains(text, ['documentary', 'وثائقي', 'docu'])) {
      return 'documentary';
    }
    if (_contains(text, ['family', 'عائلي', 'عائلة'])) return 'family';
    if (_contains(text, ['crime', 'جريمة', 'criminal'])) return 'crime';
    if (_contains(text, ['mystery', 'غموض'])) return 'mystery';
    if (_contains(text, ['war', 'حرب', 'حربي'])) return 'war';
    if (_contains(text, ['history', 'تاريخ', 'تاريخي'])) return 'history';
    if (_contains(text, ['adventure', 'مغامرة'])) return 'adventure';
    if (_contains(text, ['kids', 'أطفال', 'اطفال', 'child'])) return 'kids';

    return '';
  }

  String? _inferTranslation(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';
    if (_contains(text, ['مدبلج', 'dubbed', 'dub', 'مدبلجة'])) {
      return 'dubbed';
    }
    if (_contains(text, ['مترجم', 'مترجمة', 'subtitled', 'sub', 'subs'])) {
      return 'subtitled';
    }
    if (_contains(text, ['original', 'أصلي', 'اصلي'])) return 'original';
    return null;
  }

  int _calculatePriority(String url) {
    int priority = 0;
    final lower = url.toLowerCase();

    if (lower.contains('.m3u8')) {
      priority += 15;
    } else if (lower.contains('.ts')) {
      priority += 10;
    } else if (lower.contains('.mpd')) {
      priority += 8;
    } else if (lower.startsWith('rtsp://')) {
      priority += 6;
    } else if (lower.startsWith('rtmp://')) {
      priority += 5;
    } else if (lower.startsWith('udp://') || lower.startsWith('rtp://')) {
      priority += 4;
    } else if (lower.contains('.mp4') || lower.contains('.mkv')) {
      priority += 3;
    }

    if (lower.startsWith('https://')) priority += 5;
    if (lower.contains('token=') || lower.contains('exp=')) priority += 3;
    if (lower.contains('4k') || lower.contains('uhd')) priority += 6;
    if (lower.contains('1080') || lower.contains('fhd')) priority += 4;
    if (lower.contains('720') || lower.contains('hd')) priority += 2;

    return priority;
  }

  bool _contains(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  // ==========================================================
  //  أدوات
  // ==========================================================
  void clearCache() => _cache.clear();
  void dispose() => _dio.close();
}
