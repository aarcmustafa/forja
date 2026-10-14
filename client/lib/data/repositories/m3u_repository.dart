import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';
import 'xtream_client.dart';

/// مستودع رياضي — Xtream Live + M3U + Fallback UA + Retry 5xx
/// ✅ لا يرسل Referer/Origin (يتجنب 511 من Cloudflare)
class M3uRepository {
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  /// ✅ okhttp أولاً — يقبله Xtream
  static const List<String> fallbackUserAgents = [
    'okhttp/4.9.0',
    'IPTV Smarters Pro',
    'TiviMate/4.7.0',
    'VLC/3.0.20 LibVLC/3.0.20',
    'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 180),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: true,
              maxRedirects: 10,
              persistentConnection: true,
              validateStatus: (_) => true,
              headers: {
                'User-Agent': vlcUserAgent,
                'Accept': '*/*',
                'Accept-Encoding': 'gzip, deflate',
                'Connection': 'keep-alive',
                'Icy-MetaData': '1',
              },
            )) {
    _dio.interceptors.add(_CrossProtocolRedirectInterceptor(_dio));
  }

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
  
Future<List<Channel>> _loadFromXtream(
  XtreamCredentials credentials,
) async {
  final client = XtreamClient(credentials);
  final all = <Channel>[];

  try {
    try {
      final liveCats = await client.getLiveCategories();
      final live = await client.getLiveStreams(categories: liveCats);
      final sport = live.where((c) => _isSportChannel(c)).toList();
      all.addAll(sport);
    } catch (_) {}

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

bool _isSportChannel(Channel c) {
  if (c.category == 'sport') return true;
  final name = c.name.toLowerCase();
  final group = c.group.toLowerCase();
  final text = '$name $group';

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

Future<List<Channel>> _loadFromM3u(String url) async {
  final data = await _fetchWithFallback(url);
  if (data == null || data.isEmpty) {
    throw Exception('فشل تحميل الملف');
  }
  final all = parseM3uContent(data);
  return all.where((c) => _isSportChannel(c)).toList();
}

Future<String?> _fetchWithFallback(String url) async {
  final bestUa = await _getBestUa(url);
  if (bestUa != null) {
    final data = await _tryFetch(url, bestUa);
    if (data != null) return data;
  }

  for (int i = 0; i < fallbackUserAgents.length; i++) {
    final ua = fallbackUserAgents[i];
    final data = await _tryFetch(url, ua);

    if (data != null) {
      await _saveBestUa(url, ua);
      return data;
    }

    final delayMs = 500 * (i + 1);
    await Future.delayed(Duration(milliseconds: delayMs));
  }
  return null;
}

/// ✅ لا Referer/Origin — يتجنب 511 من Cloudflare
Future<String?> _tryFetch(String url, String ua) async {
  const maxAttempts = 3;

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final headers = <String, String>{
        'User-Agent': ua,
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Icy-MetaData': '1',
      };

      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (_) => true,
        ),
      );

      final code = response.statusCode ?? 0;

      if (code == 200 &&
          response.data != null &&
          response.data!.isNotEmpty) {
        return response.data;
      }

      // 3xx
      if (code >= 300 && code < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          try {
            final redirectUri =
                Uri.parse(url).resolve(location).toString();
            final redirectResponse = await _dio.get<String>(
              redirectUri,
              options: Options(
                responseType: ResponseType.plain,
                headers: headers,
                followRedirects: true,
                maxRedirects: 10,
                validateStatus: (_) => true,
              ),
            );
            if (redirectResponse.statusCode == 200 &&
                redirectResponse.data != null &&
                redirectResponse.data!.isNotEmpty) {
              return redirectResponse.data;
            }
          } catch (_) {}
        }
      }

      // 5xx — retry
      if (code >= 500 && code < 600) {
        await Future.delayed(
          Duration(milliseconds: 800 * (attempt + 1)),
        );
        continue;
      }

      // 429 — retry
      if (code == 429) {
        await Future.delayed(
          Duration(milliseconds: 1500 * (attempt + 1)),
        );
        continue;
      }

      // 511 / 403 — لا نعيد المحاولة
      return null;
    } catch (_) {
      if (attempt < maxAttempts - 1) {
        await Future.delayed(
          Duration(milliseconds: 500 * (attempt + 1)),
        );
      }
    }
  }
  return null;
}
  
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
      return 'قناة';
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

    final customUA = info['user-agent'] ?? info['http-user-agent'] ?? '';

    final category = _inferCategory(name, group);
    final countryCode = _inferCountry(name, group);
    final priority = _calculatePriority(url);

    final extras = <String, String>{};
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

  String _inferCategory(String name, String group) {
    return 'sport';
  }

  String _inferCountry(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (text.contains('saudi') || text.contains('ksa') ||
        text.contains('سعودي')) return 'SA';
    if (text.contains('emarat') || text.contains('uae') ||
        text.contains('امارات') || text.contains('dubai') ||
        text.contains('abu dhabi')) return 'AE';
    if (text.contains('egypt') || text.contains('مصر')) return 'EG';
    if (text.contains('morocco') || text.contains('مغرب')) return 'MA';
    if (text.contains('algeria') || text.contains('جزائر')) return 'DZ';
    if (text.contains('tunisia') || text.contains('تونس')) return 'TN';
    if (text.contains('iraq') || text.contains('عراق')) return 'IQ';
    if (text.contains('kuwait') || text.contains('كويت')) return 'KW';
    if (text.contains('qatar') || text.contains('قطر')) return 'QA';
    if (text.contains('jordan') || text.contains('أردن')) return 'JO';

    final codeMatch = RegExp(
            r'\b(SA|AE|EG|MA|DZ|TN|IQ|KW|QA|JO)\b')
        .firstMatch(group.toUpperCase());
    if (codeMatch != null) return codeMatch.group(1)!;

    return '';
  }

  String _generateId(String name, String url) {
    return '${name.hashCode}_${url.hashCode}';
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^\s*[-•·|]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
    }

    if (lower.startsWith('https://')) priority += 5;
    if (lower.contains('token=') || lower.contains('exp=')) priority += 3;
    if (lower.contains('4k') || lower.contains('uhd')) priority += 6;
    if (lower.contains('1080') || lower.contains('fhd')) priority += 4;
    if (lower.contains('720') || lower.contains('hd')) priority += 2;

    return priority;
  }

  void clearCache() => _cache.clear();
  void dispose() => _dio.close();
}

class _CrossProtocolRedirectInterceptor extends Interceptor {
  final Dio _dio;

  _CrossProtocolRedirectInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final response = err.response;
      if (response == null) {
        return handler.next(err);
      }

      final code = response.statusCode ?? 0;
      if (code < 300 || code >= 400) {
        return handler.next(err);
      }

      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        return handler.next(err);
      }

      final currentUri = response.requestOptions.uri;
      final redirectUri = currentUri.resolve(location);

      final retryResponse = await _dio.get(
        redirectUri.toString(),
        options: Options(
          responseType: response.requestOptions.responseType,
          headers: response.requestOptions.headers,
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (_) => true,
        ),
      );

      return handler.resolve(retryResponse);
    } catch (_) {
      return handler.next(err);
    }
  }
}
