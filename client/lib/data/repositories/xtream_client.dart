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

      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];

      if (username == null || password == null) return null;
      if (username.isEmpty || password.isEmpty) return null;

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

/// عميل Xtream API — ✅ okhttp UA + مهلة قصيرة + بدون Referer
class XtreamClient {
  /// ✅ okhttp أفضل من VLC مع Cloudflare
  static const String userAgent = 'okhttp/4.9.0';

  final Dio _dio;
  final XtreamCredentials credentials;

  XtreamClient(this.credentials)
      : _dio = Dio(BaseOptions(
          // ✅ مهلة قصيرة (5 ثوانٍ)
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 60),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json, */*',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            // ✅ لا Referer ولا Origin (لتجنب 511 من Cloudflare)
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

  final ext = item['container_extension']?.toString() ?? 'ts';
  final streamUrl = _buildStreamUrl('live', streamId, ext);

  final category = _inferCategory(name, categoryName);
  final country = _inferCountry(name, categoryName);

  return Channel(
    id: 'xtream_live_$streamId',
    name: name,
    logo: logo,
    streamUrl: streamUrl,
    group: categoryName.isEmpty ? 'غير مصنف' : categoryName,
    category: category,
    language: 'ara',
    countryCode: country,
    contentType: 'live',
    isWorking: true,
    priority: 100,
    tvgId: item['epg_channel_id']?.toString() ?? '',
  );
}

// ==========================================================
//  بناء روابط البث
// ==========================================================
String _buildStreamUrl(String type, String streamId, String ext) {
  final user = Uri.encodeComponent(credentials.username);
  final pass = Uri.encodeComponent(credentials.password);

  final cleanExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  final finalExt = cleanExt.isEmpty ? 'ts' : cleanExt;

  return '${credentials.server}/$type/$user/$pass/$streamId.$finalExt';
}

// ==========================================================
//  التصنيف
// ==========================================================
String _inferCategory(String name, String group) {
  // كل شيء في هذا التطبيق رياضي
  return 'sport';
}

String _inferCountry(String name, String group) {
  final text = '${name.toLowerCase()} ${group.toLowerCase()}';

  if (text.contains('saudi') || text.contains('ksa') ||
      text.contains('سعودي') || text.contains('السعودية')) {
    return 'SA';
  }
  if (text.contains('emarat') || text.contains('uae') ||
      text.contains('امارات') || text.contains('الإمارات') ||
      text.contains('dubai') || text.contains('abu dhabi')) {
    return 'AE';
  }
  if (text.contains('egypt') || text.contains('مصر') ||
      text.contains('مصري')) {
    return 'EG';
  }
  if (text.contains('morocco') || text.contains('مغرب') ||
      text.contains('مغربي')) {
    return 'MA';
  }
  if (text.contains('algeria') || text.contains('جزائر') ||
      text.contains('جزائري')) {
    return 'DZ';
  }
  if (text.contains('tunisia') || text.contains('تونس') ||
      text.contains('تونسي')) {
    return 'TN';
  }
  if (text.contains('iraq') || text.contains('عراق') ||
      text.contains('عراقي')) {
    return 'IQ';
  }
  if (text.contains('kuwait') || text.contains('كويت') ||
      text.contains('كويتي')) {
    return 'KW';
  }
  if (text.contains('qatar') || text.contains('قطر') ||
      text.contains('قطري')) {
    return 'QA';
  }
  if (text.contains('jordan') || text.contains('أردن') ||
      text.contains('اردن')) {
    return 'JO';
  }
  if (text.contains('lebanon') || text.contains('لبنان')) return 'LB';
  if (text.contains('syria') || text.contains('سوريا')) return 'SY';
  if (text.contains('yemen') || text.contains('يمن')) return 'YE';
  if (text.contains('oman') || text.contains('عمان')) return 'OM';
  if (text.contains('bahrain') || text.contains('بحرين')) return 'BH';
  if (text.contains('sudan') || text.contains('سودان')) return 'SD';
  if (text.contains('libya') || text.contains('ليبيا')) return 'LY';
  if (text.contains('palestin') || text.contains('فلسطين')) return 'PS';

  final codeMatch = RegExp(
          r'\b(SA|AE|EG|MA|DZ|TN|IQ|KW|QA|JO|LB|SY|YE|OM|BH|SD|LY|PS)\b')
      .firstMatch(group.toUpperCase());
  if (codeMatch != null) return codeMatch.group(1)!;

  return '';
}
  
  // ==========================================================
  //  أدوات عامة
  // ==========================================================
  void dispose() {
    _dio.close();
  }
}
