import 'package:dio/dio.dart';
import '../models/channel.dart';

/// كشف بيانات Xtream من الرابط
class XtreamCredentials {
  final String server;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.server,
    required this.username,
    required this.password,
  });

  /// URL كامل لـ player_api.php
  String apiUrl(String action, {Map<String, String>? extra}) {
    final params = <String, String>{
      'username': username,
      'password': password,
      'action': action,
      ...?extra,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$server/player_api.php?$query';
  }

  @override
  String toString() => 'Xtream($server | $username)';
}

/// كاشف Xtream — يستخرج البيانات من الرابط
class XtreamDetector {
  /// هل الرابط Xtream؟
  static bool isXtream(String url) {
    final lower = url.toLowerCase();
    return lower.contains('get.php') ||
        lower.contains('player_api.php') ||
        lower.contains('type=m3u_plus');
  }

  /// استخراج بيانات Xtream من URL
  static XtreamCredentials? extract(String url) {
    if (!isXtream(url)) return null;

    try {
      final uri = Uri.parse(url);

      // استخراج username/password من query params
      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];

      if (username == null || password == null) return null;
      if (username.isEmpty || password.isEmpty) return null;

      // بناء server URL (scheme + host + port)
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      final server = '${uri.scheme}://${uri.host}$portPart';

      return XtreamCredentials(
        server: server,
        username: username,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }
}

/// عميل Xtream API
class XtreamClient {
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  final Dio _dio;
  final XtreamCredentials credentials;

  XtreamClient(this.credentials)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
          headers: {
            'User-Agent': vlcUserAgent,
            'Accept': 'application/json, */*',
            'Connection': 'keep-alive',
          },
        ));

  // ==========================================================
  //  طلب JSON عام
  // ==========================================================
  Future<dynamic> _get(String action, {Map<String, String>? extra}) async {
    try {
      final url = credentials.apiUrl(action, extra: extra);
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Xtream $action فشل: $e');
      return null;
    }
  }

  // ==========================================================
  //  التحقق من الحساب
  // ==========================================================
  Future<bool> testConnection() async {
    final data = await _get('');
    if (data == null) return false;
    if (data is Map && data['user_info'] != null) {
      final status = data['user_info']['status'];
      return status == 'Active';
    }
    return false;
  }

  // ==========================================================
  //  جلب التصنيفات
  // ==========================================================
  Future<Map<String, String>> getLiveCategories() async {
    final data = await _get('get_live_categories');
    return _parseCategories(data);
  }

  Future<Map<String, String>> getVodCategories() async {
    final data = await _get('get_vod_categories');
    return _parseCategories(data);
  }

  Future<Map<String, String>> getSeriesCategories() async {
    final data = await _get('get_series_categories');
    return _parseCategories(data);
  }

  Map<String, String> _parseCategories(dynamic data) {
    if (data is! List) return {};
    final result = <String, String>{};
    for (final item in data) {
      if (item is Map) {
        final id = item['category_id']?.toString() ?? '';
        final name = item['category_name']?.toString() ?? '';
        if (id.isNotEmpty) result[id] = name;
      }
    }
    return result;
  }
  
// ==========================================================
//  جلب القنوات المباشرة
// ==========================================================
Future<List<Channel>> getLiveStreams({
  Map<String, String>? categories,
}) async {
  final data = await _get('get_live_streams');
  if (data is! List) return [];

  final result = <Channel>[];
  for (final item in data) {
    if (item is! Map) continue;
    try {
      final channel = _parseLiveStream(item, categories);
      if (channel != null) result.add(channel);
    } catch (_) {}
  }
  return result;
}

Channel? _parseLiveStream(
  Map<dynamic, dynamic> item,
  Map<String, String>? categories,
) {
  final streamId = item['stream_id']?.toString() ?? '';
  final name = item['name']?.toString() ?? '';
  if (streamId.isEmpty || name.isEmpty) return null;

  final logo = item['stream_icon']?.toString() ?? '';
  final categoryId = item['category_id']?.toString() ?? '';
  final categoryName = categories?[categoryId] ?? '';

  // ✅ بناء رابط البث (HTTP/HTTPS)
  final ext = item['container_extension']?.toString() ?? 'ts';
  final streamUrl = _buildStreamUrl('live', streamId, ext);

  // تحليل التصنيف
  final category = _inferCategory(name, categoryName);
  final language = _inferLanguage(name, categoryName);
  final country = _inferCountry(name, categoryName);

  return Channel(
    id: 'xtream_live_$streamId',
    name: name,
    logo: logo,
    streamUrl: streamUrl,
    group: categoryName.isEmpty ? 'غير مصنف' : categoryName,
    category: category,
    language: language,
    countryCode: country,
    contentType: 'live',
    isWorking: true,
    priority: 100,
    tvgId: item['epg_channel_id']?.toString() ?? '',
  );
}

// ==========================================================
//  جلب الأفلام (VOD)
// ==========================================================
Future<List<Channel>> getVodStreams({
  Map<String, String>? categories,
}) async {
  final data = await _get('get_vod_streams');
  if (data is! List) return [];

  final result = <Channel>[];
  for (final item in data) {
    if (item is! Map) continue;
    try {
      final movie = _parseVodStream(item, categories);
      if (movie != null) result.add(movie);
    } catch (_) {}
  }
  return result;
}

Channel? _parseVodStream(
  Map<dynamic, dynamic> item,
  Map<String, String>? categories,
) {
  final streamId = item['stream_id']?.toString() ?? '';
  final name = item['name']?.toString() ?? '';
  if (streamId.isEmpty || name.isEmpty) return null;

  final logo = item['stream_icon']?.toString() ?? '';
  final categoryId = item['category_id']?.toString() ?? '';
  final categoryName = categories?[categoryId] ?? '';

  // ✅ بناء رابط الفيلم
  final ext = item['container_extension']?.toString() ?? 'mp4';
  final streamUrl = _buildStreamUrl('movie', streamId, ext);

  final category = 'movie';
  final contentType = 'movie';
  final language = _inferLanguage(name, categoryName);
  final country = _inferCountry(name, categoryName);
  final genre = _inferGenre(name, categoryName);
  final year = _extractYear(name);
  final translation = _inferTranslation(name, categoryName);
  final originalName = _extractOriginalName(name);

  return Channel(
    id: 'xtream_vod_$streamId',
    name: _cleanName(name),
    originalName: originalName,
    logo: logo,
    streamUrl: streamUrl,
    group: categoryName.isEmpty ? 'أفلام' : categoryName,
    category: category,
    language: language,
    countryCode: country,
    genre: genre,
    contentType: contentType,
    translation: translation,
    year: year,
    isWorking: true,
    priority: 100,
    tvgId: '',
  );
}

// ==========================================================
//  جلب المسلسلات
// ==========================================================
Future<List<Channel>> getSeries({
  Map<String, String>? categories,
}) async {
  final data = await _get('get_series');
  if (data is! List) return [];

  final result = <Channel>[];
  for (final item in data) {
    if (item is! Map) continue;
    try {
      final series = _parseSeries(item, categories);
      if (series != null) result.add(series);
    } catch (_) {}
  }
  return result;
}

Channel? _parseSeries(
  Map<dynamic, dynamic> item,
  Map<String, String>? categories,
) {
  final seriesId = item['series_id']?.toString() ?? '';
  final name = item['name']?.toString() ?? '';
  if (seriesId.isEmpty || name.isEmpty) return null;

  final logo = item['cover']?.toString() ?? '';
  final categoryId = item['category_id']?.toString() ?? '';
  final categoryName = categories?[categoryId] ?? '';

  // ✅ رابط المسلسل عبر API خاص
  final streamUrl =
      '${credentials.server}/series/${credentials.username}/${credentials.password}/$seriesId';

  final language = _inferLanguage(name, categoryName);
  final country = _inferCountry(name, categoryName);
  final genre = _inferGenre(name, categoryName);
  final year = _extractYear(name);
  final translation = _inferTranslation(name, categoryName);
  final originalName = _extractOriginalName(name);

  return Channel(
    id: 'xtream_series_$seriesId',
    name: _cleanName(name),
    originalName: originalName,
    logo: logo,
    streamUrl: streamUrl,
    group: categoryName.isEmpty ? 'مسلسلات' : categoryName,
    category: 'series',
    language: language,
    countryCode: country,
    genre: genre,
    contentType: 'series',
    translation: translation,
    year: year,
    isWorking: true,
    priority: 100,
    tvgId: '',
    extras: {'xtream_series_id': seriesId},
  );
}

// ==========================================================
//  بناء روابط البث — مهم لـ HTTP/HTTPS
// ==========================================================
/// بناء رابط البث حسب نوع Xtream
///
/// صيغ الروابط:
/// - Live:  {server}/live/{user}/{pass}/{streamId}.{ext}
/// - Movie: {server}/movie/{user}/{pass}/{streamId}.{ext}
/// - Series: {server}/series/{user}/{pass}/{seriesId}.{ext}
String _buildStreamUrl(String type, String streamId, String ext) {
  // استخدام uri.encodeComponent للـ username/password
  // (يحتاج في حالة رموز خاصة)
  final user = Uri.encodeComponent(credentials.username);
  final pass = Uri.encodeComponent(credentials.password);

  // تنظيف ext (بعض السيرفرات ترجع "mp4" بأقواس)
  final cleanExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  final finalExt = cleanExt.isEmpty ? 'ts' : cleanExt;

  return '${credentials.server}/$type/$user/$pass/$streamId.$finalExt';
}

/// بناء رابط بث مخصص (يُستخدم للمسلسلات عند اختيار حلقة)
String buildEpisodeUrl(String episodeId, String ext) {
  final user = Uri.encodeComponent(credentials.username);
  final pass = Uri.encodeComponent(credentials.password);
  return '${credentials.server}/series/$user/$pass/$episodeId.$ext';
}

// ==========================================================
//  جلب حلقات مسلسل
// ==========================================================
Future<Map<String, dynamic>?> getSeriesInfo(String seriesId) async {
  final data = await _get('get_series_info', extra: {
    'series_id': seriesId,
  });
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}
  
  // ==========================================================
  //  معالجة HTTP/HTTPS
  // ==========================================================
  /// تحويل رابط إلى HTTP/HTTPS حسب السيرفر
  String normalizeUrl(String url) {
    // إذا كان الرابط يبدأ بـ https لكن السيرفر HTTP → حوّله
    if (credentials.server.startsWith('http://') &&
        url.startsWith('https://')) {
      return url.replaceFirst('https://', 'http://');
    }
    return url;
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

  // ==========================================================
  //  أدوات مساعدة
  // ==========================================================
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

  bool _contains(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  void dispose() {
    _dio.close();
  }
}
