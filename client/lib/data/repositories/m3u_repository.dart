import 'dart:async';
import 'package:dio/dio.dart';
import '../models/channel.dart';

/// مستودع تحميل وتحليل ملفات M3U من روابط HTTP/HTTPS
class M3uRepository {
  final Dio _dio;
  final Map<String, List<Channel>> _cache = {};

  M3uRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'User-Agent': 'EstetnFarja/1.0 (Android TV)',
                'Accept': '*/*',
              },
            ));

  /// تحميل قائمة M3U من رابط
  /// [forceRefresh] = true لتجاهل الـ cache
  Future<List<Channel>> loadFromUrl(
    String url, {
    bool forceRefresh = false,
  }) async {
    // نرجع من الـ cache إن وُجد
    if (!forceRefresh && _cache.containsKey(url)) {
      return _cache[url]!;
    }

    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('فشل تحميل الملف: رمز ${response.statusCode}');
      }

      final channels = parseM3uContent(response.data!);
      _cache[url] = channels;
      return channels;
    } on DioException catch (e) {
      throw Exception('خطأ في الاتصال: ${e.message}');
    }
  }

  /// تحميل من محتوى نصي مباشرة (للاستخدام المحلي)
  List<Channel> parseM3uContent(String content) {
    final lines = content.split('\n');
    final channels = <Channel>[];
    Map<String, String>? currentInfo;
    String? currentName;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // بداية الملف
      if (line.startsWith('#EXTM3U')) {
        continue;
      }

      // معلومات القناة
      if (line.startsWith('#EXTINF:')) {
        currentInfo = _parseExtInf(line);
        currentName = _extractName(line);
        continue;
      }

      // أي سطر آخر يبدأ بـ # نضيفه للـ extras
      if (line.startsWith('#')) {
        continue;
      }

      // هذا رابط البث
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

  /// استخراج السمات من سطر #EXTINF
  Map<String, String> _parseExtInf(String line) {
    final info = <String, String>{};

    // نبحث عن tvg-id="..." أو group-title="..." إلخ
    final regex = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');
    for (final match in regex.allMatches(line)) {
      info[match.group(1)!] = match.group(2)!;
    }

    return info;
  }

  /// استخراج اسم القناة (بعد آخر فاصلة في السطر)
  String _extractName(String line) {
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex == -1 || commaIndex == line.length - 1) {
      return 'قناة غير معروفة';
    }
    return line.substring(commaIndex + 1).trim();
  }

  /// بناء Channel من المعلومات المستخرجة
  Channel _buildChannel({
    required String name,
    required String url,
    required Map<String, String> info,
  }) {
    final group = info['group-title'] ?? 'غير مصنف';
    final tvgId = info['tvg-id'] ?? '';
    final logo = info['tvg-logo'] ?? '';

    // تحديد التصنيف تلقائياً من الاسم والمجموعة
    final category = _inferCategory(name, group);
    final contentType = _inferContentType(name, group);
    final language = _inferLanguage(name, group);
    final translation = _inferTranslation(name);

    // الأولوية تحسب من نوع الرابط ومدة الصلاحية
    final priority = _calculatePriority(url);

    return Channel(
      id: _generateId(name, url),
      name: name,
      logo: logo,
      streamUrl: url,
      group: group,
      category: category,
      language: language,
      contentType: contentType,
      translation: translation,
      isWorking: true,
      priority: priority,
      tvgId: tvgId,
    );
  }

  /// توليد ID فريد للقناة
  String _generateId(String name, String url) {
    return '${name.hashCode}_${url.hashCode}';
  }

  /// استنتاج التصنيف من الاسم والمجموعة
  String _inferCategory(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    // رياضة
    if (text.contains('bein') ||
        text.contains('sport') ||
        text.contains('ssc') ||
        text.contains('رياض') ||
        text.contains('كورة') ||
        text.contains('alkass') ||
        text.contains('dubai sport')) {
      return 'sport';
    }

    // أفلام
    if (text.contains('movie') ||
        text.contains('cinema') ||
        text.contains('film') ||
        text.contains('أفلام') ||
        text.contains('سينما') ||
        text.contains('osn movie') ||
        text.contains('mbc movie')) {
      return 'movie';
    }

    // مسلسلات
    if (text.contains('series') ||
        text.contains('drama') ||
        text.contains('مسلسل') ||
        text.contains('دراما')) {
      return 'series';
    }

    // أخبار
    if (text.contains('news') ||
        text.contains('أخبار') ||
        text.contains('alarabiya') ||
        text.contains('jazeera') ||
        text.contains('sky news')) {
      return 'news';
    }

    // أطفال
    if (text.contains('kid') ||
        text.contains('cartoon') ||
        text.contains('أطفال') ||
        text.contains('كرتون') ||
        text.contains('spacetoon') ||
        text.contains('mbc3')) {
      return 'kids';
    }

    return 'general';
  }

  /// استنتاج نوع المحتوى
  String _inferContentType(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';
    if (text.contains('vod') ||
        text.contains('movie') ||
        text.contains('film') ||
        text.contains('أفلام')) {
      return 'movie';
    }
    if (text.contains('series') || text.contains('مسلسل')) {
      return 'series';
    }
    return 'live';
  }

  /// استنتاج اللغة
  String _inferLanguage(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (text.contains('turk') || text.contains('تركي')) return 'tur';
    if (text.contains('hindi') ||
        text.contains('bollywood') ||
        text.contains('هندي')) {
      return 'hin';
    }
    if (text.contains('french') || text.contains('franc')) return 'fra';
    if (text.contains('english') || text.contains('usa')) return 'eng';

    return 'ara'; // الافتراضي
  }

  /// استنتاج نوع الترجمة
  String? _inferTranslation(String name) {
    final text = name.toLowerCase();
    if (text.contains('مدبلج') || text.contains('dubbed')) return 'dubbed';
    if (text.contains('مترجم') || text.contains('subtitled')) {
      return 'subtitled';
    }
    return null;
  }

  /// حساب الأولوية للرابط
  /// - الروابط الطويلة الصلاحية أعلى
  /// - HLS أعلى من العادي
  int _calculatePriority(String url) {
    int priority = 0;

    // HLS أعلى أولوية
    if (url.contains('.m3u8')) priority += 10;

    // HTTPS أعلى من HTTP
    if (url.startsWith('https://')) priority += 5;

    // روابط تحتوي token/token مع m3u8
    if (url.contains('token=') || url.contains('exp=')) priority += 3;

    // روابط بأبعاد عالية
    if (url.contains('1080') || url.contains('hd')) priority += 2;

    return priority;
  }

  /// حذف الـ cache
  void clearCache() {
    _cache.clear();
  }

  /// إغلاق الـ Dio
  void dispose() {
    _dio.close();
  }
}
