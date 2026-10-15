import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';
import 'xtream_client.dart';

/// مستودع رياضي محسّن
/// - Xtream Live فقط (رياضة)
/// - M3U مع Fallback مبسّط (بدون طباعة مزعجة)
/// - تحليل M3U في Isolate
class M3uRepository {
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  // UAs احتياطية محدودة
  static const List<String> fallbackUserAgents = [
    'VLC/3.0.20 LibVLC/3.0.20',
    'IPTV Smarters Pro',
  ];

  static const int maxInMemoryEntries = 15;
  static const int maxBestUaEntries = 50;

  static const String _boxName = 'best_user_agents';
  static const String _kBestUas = 'uas_map';

  Box? _uaBox;
  bool _uaInitialized = false;

  Future<void> _initUaBox() async {
    if (_uaInitialized) return;
    try {
      await Hive.initFlutter();
      _uaBox = await Hive.openBox(_boxName);
      _uaInitialized = true;
    } catch (_) {
      _uaInitialized = false;
    }
  }

  Future<String?> _getBestUa(String url) async {
    await _initUaBox();
    if (_uaBox == null) return null;
    try {
      final raw = _uaBox!.get(_kBestUas);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      return map[url]?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveBestUa(String url, String ua) async {
    await _initUaBox();
    if (_uaBox == null) return;
    try {
      final raw = _uaBox!.get(_kBestUas);
      final Map<String, dynamic> map =
          raw is Map ? Map<String, dynamic>.from(raw) : {};
      map[url] = ua;
      await _uaBox!.put(_kBestUas, map);
      await _trimUaCache();
    } catch (_) {}
  }

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

  final Dio _dio;
  final Map<String, List<Channel>> _cache = {};

  M3uRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 25),
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
  //  الدالة الرئيسية
  // ==========================================================
  Future<List<Channel>> loadFromUrl(
    String url, {
    bool forceRefresh = false,
  }) async {
    _trimInMemoryCache();

    if (!forceRefresh && _cache.containsKey(url)) {
      return _cache[url]!;
    }

    final credentials = XtreamDetector.extract(url);
    if (credentials != null) {
      final channels = await _loadFromXtream(credentials);
      _cache[url] = channels;
      _trimInMemoryCache();
      return channels;
    }

    final channels = await _loadFromM3u(url);
    _cache[url] = channels;
    _trimInMemoryCache();
    return channels;
  }

  // ==========================================================
  //  إدارة الكاش
  // ==========================================================
  void _trimInMemoryCache() {
    if (_cache.length <= maxInMemoryEntries) return;
    final toRemove = _cache.length - maxInMemoryEntries;
    final keysToRemove = _cache.keys.take(toRemove).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  Future<void> _trimUaCache() async {
    await _initUaBox();
    if (_uaBox == null) return;
    try {
      final raw = _uaBox!.get(_kBestUas);
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      if (map.length <= maxBestUaEntries) return;
      final toRemove = map.length - maxBestUaEntries;
      final keysToRemove = map.keys.take(toRemove).toList();
      for (final key in keysToRemove) {
        map.remove(key);
      }
      await _uaBox!.put(_kBestUas, map);
    } catch (_) {}
  }

  Future<void> maintainCache() async {
    _trimInMemoryCache();
    await _trimUaCache();
  }

  Future<void> resetAllCache() async {
    _cache.clear();
    await _initUaBox();
    if (_uaBox != null) {
      try {
        await _uaBox!.delete(_kBestUas);
      } catch (_) {}
    }
  }

  void resetUrlCache(String url) {
    _cache.remove(url);
  }

  Map<String, dynamic> getCacheInfo() {
    return {
      'inMemoryEntries': _cache.length,
      'inMemoryLimit': maxInMemoryEntries,
      'uaCacheReady': _uaInitialized,
    };
  }
  
// ==========================================================
//  تحميل من Xtream — Live رياضي فقط
// ==========================================================
Future<List<Channel>> _loadFromXtream(
  XtreamCredentials credentials,
) async {
  final client = XtreamClient(credentials);
  final all = <Channel>[];

  try {
    // القنوات المباشرة فقط
    try {
      final liveCats = await client.getLiveCategories();
      final live = await client.getLiveStreams(categories: liveCats);

      // فلترة رياضية
      final sport = live.where((c) => isSportChannel(c)).toList();
      all.addAll(sport);
    } catch (_) {}

    // Fallback إلى M3U إذا فشل كل شيء
    if (all.isEmpty) {
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
//  تحميل من M3U — مع Isolate + Fallback مبسّط
// ==========================================================
Future<List<Channel>> _loadFromM3u(String url) async {
  final data = await _fetchWithFallback(url);

  if (data == null || data.isEmpty) {
    return const [];
  }

  // تحليل في Isolate (لا يجمّد الواجهة)
  final all = await compute(parseM3uContent, data);

  // فلترة رياضية
  return all.where((c) => isSportChannel(c)).toList();
}

// ==========================================================
//  Fallback مبسّط: cached + VLC + IPTV Smarters فقط
// ==========================================================
Future<String?> _fetchWithFallback(String url) async {
  // 1) جرّب أفضل UA محفوظ أولاً
  final bestUa = await _getBestUa(url);
  if (bestUa != null) {
    final data = await _tryFetch(url, bestUa);
    if (data != null) return data;
  }

  // 2) جرّب VLC
  const vlcUa = 'VLC/3.0.20 LibVLC/3.0.20';
  final data1 = await _tryFetch(url, vlcUa);
  if (data1 != null) {
    await _saveBestUa(url, vlcUa);
    return data1;
  }

  // 3) جرّب IPTV Smarters كاحتياطي وحيد
  const iptvUa = 'IPTV Smarters Pro';
  final data2 = await _tryFetch(url, iptvUa);
  if (data2 != null) {
    await _saveBestUa(url, iptvUa);
    return data2;
  }

  // فشل كلي
  return null;
}

Future<String?> _tryFetch(String url, String ua) async {
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
      return response.data;
    }
    return null;
  } catch (_) {
    return null;
  }
}
  
  // ==========================================================
  //  كل دوال التحليل static (مطلوبة لـ compute)
  // ==========================================================

  static List<Channel> parseM3uContent(String content) {
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

  static Map<String, String> _parseExtInf(String line) {
    final info = <String, String>{};
    final regex = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');
    for (final match in regex.allMatches(line)) {
      info[match.group(1)!] = match.group(2)!;
    }
    return info;
  }

  static String _extractName(String line) {
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex == -1 || commaIndex == line.length - 1) {
      return 'قناة';
    }
    return line.substring(commaIndex + 1).trim();
  }

  static Channel _buildChannel({
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
    final countryCode = _inferCountry(name, group);
    final priority = _calculatePriority(url);

    final extras = <String, String>{};
    if (customReferer.isNotEmpty) extras['referer'] = customReferer;
    if (customUA.isNotEmpty) extras['user_agent'] = customUA;

    return Channel(
      id: _generateId(name, url),
      name: _cleanName(name),
      logo: logo,
      streamUrl: url,
      group: group,
      category: category,
      language: 'ara',
      countryCode: countryCode,
      contentType: 'live',
      isWorking: true,
      priority: priority,
      tvgId: tvgId,
      extras: extras,
    );
  }

  // ==========================================================
  //  فحص رياضي (static)
  // ==========================================================
  static bool isSportChannel(Channel c) {
    if (c.category == 'sport') return true;

    final text = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';

    const sportKeywords = [
      'bein', 'sport', 'ssc', 'رياض', 'كورة', 'alkass',
      'dubai sport', 'ad sport', 'ksa sport', 'alwan',
      'sky sport', 'espn', 'dazn', 'nba', 'nfl',
      'shahid sport', 'shasha', '1001', 'sportv',
      'فورمولا', 'moto', 'ufc', 'wwe', 'fight',
      'fifa', 'uefa', 'caf', 'afc',
    ];

    for (final keyword in sportKeywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  // ==========================================================
  //  التصنيف — رياضة فقط
  // ==========================================================
  static String _inferCategory(String name, String group) {
    return 'sport';
  }

  static String _inferCountry(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (text.contains('saudi') ||
        text.contains('ksa') ||
        text.contains('سعودي')) {
      return 'SA';
    }
    if (text.contains('emarat') ||
        text.contains('uae') ||
        text.contains('امارات') ||
        text.contains('dubai') ||
        text.contains('abu dhabi')) {
      return 'AE';
    }
    if (text.contains('egypt') || text.contains('مصر')) return 'EG';
    if (text.contains('morocco') || text.contains('مغرب')) return 'MA';
    if (text.contains('algeria') || text.contains('جزائر')) return 'DZ';
    if (text.contains('tunisia') || text.contains('تونس')) return 'TN';
    if (text.contains('iraq') || text.contains('عراق')) return 'IQ';
    if (text.contains('kuwait') || text.contains('كويت')) return 'KW';
    if (text.contains('qatar') || text.contains('قطر')) return 'QA';
    if (text.contains('jordan') || text.contains('أردن')) return 'JO';

    final codeMatch = RegExp(
      r'\b(SA|AE|EG|MA|DZ|TN|IQ|KW|QA|JO)\b',
    ).firstMatch(group.toUpperCase());
    if (codeMatch != null) return codeMatch.group(1)!;

    return '';
  }

  // ==========================================================
  //  أدوات مساعدة (static)
  // ==========================================================
  static String _generateId(String name, String url) {
    return '${name.hashCode}_${url.hashCode}';
  }

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^\s*[-•·|]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _calculatePriority(String url) {
    int priority = 0;
    final lower = url.toLowerCase();

    if (lower.contains('.m3u8')) {
      priority += 15;
    } else if (lower.contains('.ts')) {
      priority += 10;
    } else if (lower.contains('.mpd')) {
      priority += 8;
    }

    if (lower.startsWith('https://')) priority += 5;
    if (lower.contains('token=') || lower.contains('exp=')) priority += 3;
    if (lower.contains('4k') || lower.contains('uhd')) priority += 6;
    if (lower.contains('1080') || lower.contains('fhd')) priority += 4;
    if (lower.contains('720') || RegExp(r'\bhd\b').hasMatch(lower)) {
      priority += 2;
    }

    return priority;
  }

  // ==========================================================
  //  أدوات عامة
  // ==========================================================
  void clearCache() => _cache.clear();
  void dispose() => _dio.close();
}
