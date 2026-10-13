import 'dart:async';
import 'package:dio/dio.dart';
import '../models/channel.dart';

/// مستودع تحميل وتحليل ملفات M3U من روابط HTTP/HTTPS
/// يدعم تصنيفاً ذكياً متقدماً:
/// - عربي، تركي، هندي، أجنبي، أنمي، أسيوي
/// - قنوات حسب الدول العربية (SA, AE, EG, MA, DZ...)
/// - استخراج السنة والنوع من اسم الفيلم
class M3uRepository {
  final Dio _dio;
  final Map<String, List<Channel>> _cache = {};

  M3uRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36',
                'Accept': '*/*',
              },
            ));

  /// تحميل قائمة M3U من رابط
  Future<List<Channel>> loadFromUrl(
    String url, {
    bool forceRefresh = false,
  }) async {
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

  /// تحميل من محتوى نصي مباشرة
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

  /// استخراج السمات من سطر #EXTINF
  Map<String, String> _parseExtInf(String line) {
    final info = <String, String>{};
    final regex = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');
    for (final match in regex.allMatches(line)) {
      info[match.group(1)!] = match.group(2)!;
    }
    return info;
  }

  /// استخراج اسم القناة (بعد آخر فاصلة)
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

    // ============ التصنيف المتقدم ============
    final category = _inferCategory(name, group);
    final contentType = _inferContentType(name, group, url);
    final language = _inferLanguage(name, group);
    final countryCode = _inferCountry(name, group);
    final genre = _inferGenre(name, group);
    final translation = _inferTranslation(name, group);
    final year = _extractYear(name);
    final originalName = _extractOriginalName(name);
    final priority = _calculatePriority(url);

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
    );
  }

  /// توليد ID فريد
  String _generateId(String name, String url) {
    return '${name.hashCode}_${url.hashCode}';
  }

  /// تنظيف الاسم من الرموز الغريبة
  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^\s*[-•·|]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// استخراج السنة من الاسم (مثل: "فيلم 2024")
  int? _extractYear(String name) {
    final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(name);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    if (year == null) return null;
    // نرفض السنوات غير المنطقية
    if (year < 1950 || year > 2030) return null;
    return year;
  }

  /// استخراج الاسم الأصلي إن كان بين قوسين
  String _extractOriginalName(String name) {
    // مثال: "فيلم عربي (The Lion King)"
    final match = RegExp(r'\(([A-Za-z0-9\s\:\-\.\,\!\?]+)\)')
        .firstMatch(name);
    if (match != null) {
      return match.group(1)!.trim();
    }
    // إذا كان الاسم كله بالإنجليزية
    if (RegExp(r'^[A-Za-z0-9\s\:\-\.\,\!\?]+$').hasMatch(name)) {
      return name.trim();
    }
    return '';
  }
  
  // ==========================================================
  //  التصنيف الذكي
  // ==========================================================

  /// استنتاج التصنيف الرئيسي
  String _inferCategory(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    // ============ رياضة ============
    if (_contains(text, [
      'bein', 'sport', 'ssc', 'رياض', 'كورة', 'alkass',
      'dubai sport', 'ad sport', 'ksa sport', 'alwan sport',
      'sky sport', 'espn', 'dazn', 'nba', 'nfl',
    ])) return 'sport';

    // ============ مسلسلات (قبل الأفلام لأن كلمة "مسلسل" تظهر أحياناً في الأفلام) ============
    if (_contains(text, [
      'series', 'serie', 'drama', 'مسلسل', 'مسلسلات',
      'دراما', 'soap', 'telenovela',
    ])) return 'series';

    // ============ أفلام ============
    if (_contains(text, [
      'movie', 'movies', 'cinema', 'film', 'films', 'vod',
      'أفلام', 'فيلم', 'سينما',
    ])) return 'movie';

    // ============ أنمي ============
    if (_contains(text, ['anime', 'أنمي', 'manga'])) return 'movie';

    // ============ أخبار ============
    if (_contains(text, [
      'news', 'أخبار', 'alarabiya', 'jazeera', 'sky news',
      'cnn', 'bbc', 'france 24', 'rt',
    ])) return 'news';

    // ============ أطفال ============
    if (_contains(text, [
      'kid', 'kids', 'cartoon', 'أطفال', 'كرتون', 'spacetoon',
      'mbc3', 'baby', 'junior',
    ])) return 'kids';

    // ============ وثائقي ============
    if (_contains(text, [
      'documentary', 'docu', 'وثائقي', 'nat geo', 'discovery',
      'history', 'animal planet',
    ])) return 'documentary';

    // ============ موسيقى ============
    if (_contains(text, [
      'music', 'موسيقى', 'mtv', 'rotana', 'mazzika',
    ])) return 'music';

    // ============ ديني ============
    if (_contains(text, [
      'quran', 'قرآن', 'islam', 'إسلام', 'دين', 'religious',
      'makkah', 'madinah', 'sunna', 'chr',
    ])) return 'religious';

    return 'general';
  }

  /// استنتاج نوع المحتوى (live / movie / series)
  String _inferContentType(String name, String group, String url) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    // مسلسل
    if (_contains(text, ['series', 'serie', 'مسلسل', 'مسلسلات'])) {
      return 'series';
    }

    // فيلم
    if (_contains(text, [
      'movie', 'movies', 'film', 'vod', 'أفلام', 'فيلم',
      'cinema', 'anime', 'أنمي',
    ])) {
      return 'movie';
    }

    // روابط تحتوي على VOD أو film
    if (url.toLowerCase().contains('/movie/') ||
        url.toLowerCase().contains('/vod/')) {
      return 'movie';
    }

    return 'live';
  }

  /// استنتاج اللغة
  String _inferLanguage(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    // أنمي (يُعامل كتصنيف لغوي خاص)
    if (_contains(text, ['anime', 'أنمي', 'manga'])) return 'anime';

    // كوري / ياباني
    if (_contains(text, ['korean', 'كوري', 'k-drama', 'kdrama'])) {
      return 'kor';
    }
    if (_contains(text, ['japan', 'ياباني', 'j-drama', 'jdrama'])) {
      return 'jpn';
    }

    // هندي
    if (_contains(text, [
      'hindi', 'bollywood', 'هندي', 'الهند', 'india', 'indian',
    ])) return 'hin';

    // تركي
    if (_contains(text, [
      'turk', 'turkish', 'تركي', 'تركية', 'türk',
    ])) return 'tur';

    // أجنبي عام
    if (_contains(text, [
      'foreign', 'اجنبي', 'أجنبي', 'english', 'usa', 'uk',
      'american', 'hollywood', 'west',
    ])) return 'eng';

    // فرنسي
    if (_contains(text, ['french', 'franc', 'فرنسي'])) return 'fra';

    // آسيوي عام
    if (_contains(text, [
      'asian', 'اسيوي', 'أسيوي', 'china', 'chinese', 'صيني',
      'thai', 'تايلندي', 'vietnam', 'فيتنامي', 'philippines',
    ])) return 'asian';

    // الافتراضي: عربي
    return 'ara';
  }

  /// استنتاج الدولة من الاسم/المجموعة
  String _inferCountry(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    // أختام مباشرة
    if (_contains(text, ['saudi', 'ksa', 'سعودي', 'السعودية'])) {
      return 'SA';
    }
    if (_contains(text, ['emarat', 'uae', 'امارات', 'الإمارات', 'dubai', 'abu dhabi'])) {
      return 'AE';
    }
    if (_contains(text, ['egypt', 'مصر', 'مصري', 'cairo'])) return 'EG';
    if (_contains(text, ['morocco', 'مغرب', 'مغربي'])) return 'MA';
    if (_contains(text, ['algeria', 'جزائر', 'جزائري'])) return 'DZ';
    if (_contains(text, ['tunisia', 'تونس', 'تونسي'])) return 'TN';
    if (_contains(text, ['iraq', 'عراق', 'عراقي', 'بغداد'])) return 'IQ';
    if (_contains(text, ['kuwait', 'كويت', 'كويتي'])) return 'KW';
    if (_contains(text, ['qatar', 'قطر', 'قطري', 'دoha'])) return 'QA';
    if (_contains(text, ['jordan', 'أردن', 'اردن', 'عمّان', 'عمان'])) {
      return 'JO';
    }
    if (_contains(text, ['lebanon', 'لبنان', 'لبناني', 'بيروت'])) return 'LB';
    if (_contains(text, ['syria', 'سوريا', 'سوري', 'دمشق'])) return 'SY';
    if (_contains(text, ['yemen', 'يمن', 'يمني', 'صنعاء'])) return 'YE';
    if (_contains(text, ['oman', 'عمان', 'عُمان', 'مسقط'])) return 'OM';
    if (_contains(text, ['bahrain', 'بحرين', 'بحريني', 'منامة'])) return 'BH';
    if (_contains(text, ['sudan', 'سودان', 'سوداني', 'خرطوم'])) return 'SD';
    if (_contains(text, ['libya', 'ليبيا', 'ليبي', 'طرابلس'])) return 'LY';
    if (_contains(text, ['palestin', 'فلسطين', 'فلسطيني', 'غزة', 'قدس'])) {
      return 'PS';
    }
    if (_contains(text, ['mauritania', 'موريتانيا', 'موريتاني'])) {
      return 'MR';
    }

    // رموز مختصرة (AR-SA, AR-EG...)
    final codeMatch = RegExp(r'\b(SA|AE|EG|MA|DZ|TN|IQ|KW|QA|JO|LB|SY|YE|OM|BH|SD|LY|PS|MR)\b')
        .firstMatch(group.toUpperCase());
    if (codeMatch != null) {
      return codeMatch.group(1)!;
    }

    return '';
  }

  /// استنتاج النوع السينمائي
  String _inferGenre(String name, String group) {
    final text = '${name.toLowerCase()} ${group.toLowerCase()}';

    if (_contains(text, ['action', 'أكشن', 'اكشن', 'action movie'])) {
      return 'action';
    }
    if (_contains(text, ['drama', 'دراما'])) return 'drama';
    if (_contains(text, ['comedy', 'كوميدي', 'ضحك', 'funny'])) return 'comedy';
    if (_contains(text, ['horror', 'رعب', 'مخيف', 'scary'])) return 'horror';
    if (_contains(text, ['romance', 'رومانس', 'رومانسي', 'love', 'حب'])) {
      return 'romance';
    }
    if (_contains(text, ['thriller', 'إثارة', 'اثارة', 'suspense'])) {
      return 'thriller';
    }
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
    if (_contains(text, ['mystery', 'غموض', 'mystery'])) return 'mystery';
    if (_contains(text, ['war', 'حرب', 'حربي'])) return 'war';
    if (_contains(text, ['history', 'تاريخ', 'تاريخي', 'historical'])) {
      return 'history';
    }
    if (_contains(text, ['adventure', 'مغامرة', 'adventure'])) {
      return 'adventure';
    }
    if (_contains(text, ['kids', 'أطفال', 'اطفال', 'child'])) return 'kids';

    return '';
  }

  /// استنتاج نوع الترجمة
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

  /// حساب الأولوية للرابط
  int _calculatePriority(String url) {
    int priority = 0;

    // HLS أعلى أولوية
    if (url.contains('.m3u8')) priority += 10;

    // HTTPS أعلى من HTTP
    if (url.startsWith('https://')) priority += 5;

    // روابط مع token أو expires قد تكون أطول صلاحية
    if (url.contains('token=') || url.contains('exp=')) priority += 3;

    // جودة عالية
    final lower = url.toLowerCase();
    if (lower.contains('1080') || lower.contains('fhd')) priority += 3;
    if (lower.contains('720') || lower.contains('hd')) priority += 2;
    if (lower.contains('4k') || lower.contains('uhd')) priority += 4;

    return priority;
  }

  /// هل النص يحتوي على أي كلمة من القائمة؟
  bool _contains(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
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
