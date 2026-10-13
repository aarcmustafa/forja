/// نموذج موحّد يمثل قناة أو فيلم أو مسلسل
class Channel {
  final String id;
  final String name;
  final String originalName;
  final String logo;
  final String streamUrl;
  final String group;
  final String category;
  final String language;
  final String countryCode;
  final String genre;
  final String contentType;
  final String? translation;
  final int? year;
  final double? rating;
  final bool isWorking;
  final int priority;
  final DateTime? expiresAt;
  final String tvgId;
  final bool isAdult;
  final Map<String, String> extras;

  const Channel({
    required this.id,
    required this.name,
    this.originalName = '',
    this.logo = '',
    required this.streamUrl,
    this.group = 'غير مصنف',
    this.category = 'general',
    this.language = 'ara',
    this.countryCode = '',
    this.genre = '',
    this.contentType = 'live',
    this.translation,
    this.year,
    this.rating,
    this.isWorking = true,
    this.priority = 0,
    this.expiresAt,
    this.tvgId = '',
    this.isAdult = false,
    this.extras = const {},
  });

  // ==========================================================
  //  كشف صيغة البث
  // ==========================================================
  bool get isHls => streamUrl.contains('.m3u8');
  bool get isM3u => streamUrl.endsWith('.m3u') && !streamUrl.contains('.m3u8');
  bool get isTs => streamUrl.contains('.ts');
  bool get isDash => streamUrl.contains('.mpd');
  bool get isVideo =>
      streamUrl.contains('.mp4') ||
      streamUrl.contains('.mkv') ||
      streamUrl.contains('.avi') ||
      streamUrl.contains('.mov');
  bool get isRtsp => streamUrl.startsWith('rtsp://');
  bool get isRtmp => streamUrl.startsWith('rtmp://');
  bool get isUdp =>
      streamUrl.startsWith('udp://') || streamUrl.startsWith('rtp://');
  bool get isMms => streamUrl.startsWith('mms://');
  bool get isFlv => streamUrl.contains('.flv');

  bool get isLiveStream =>
      isHls || isTs || isRtsp || isRtmp || isUdp || isMms || isFlv;

  String get streamFormat {
    if (isHls) return 'HLS';
    if (isTs) return 'TS';
    if (isDash) return 'DASH';
    if (isRtsp) return 'RTSP';
    if (isRtmp) return 'RTMP';
    if (isUdp) return 'UDP';
    if (isMms) return 'MMS';
    if (isFlv) return 'FLV';
    if (streamUrl.contains('.mp4')) return 'MP4';
    if (streamUrl.contains('.mkv')) return 'MKV';
    if (streamUrl.contains('.avi')) return 'AVI';
    if (isM3u) return 'M3U';
    return 'Unknown';
  }

  // ==========================================================
  //  التسميات العربية
  // ==========================================================
  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'sport':
        return 'رياضة';
      case 'movie':
        return 'أفلام';
      case 'series':
        return 'مسلسلات';
      case 'news':
        return 'أخبار';
      case 'kids':
        return 'أطفال';
      case 'documentary':
        return 'وثائقي';
      case 'music':
        return 'موسيقى';
      case 'religious':
        return 'ديني';
      case 'general':
        return 'عام';
      default:
        return category;
    }
  }

  String get languageLabel {
    switch (language.toLowerCase()) {
      case 'ara':
        return 'عربي';
      case 'tur':
        return 'تركي';
      case 'hin':
        return 'هندي';
      case 'eng':
        return 'إنجليزي';
      case 'fra':
        return 'فرنسي';
      case 'anime':
        return 'أنمي';
      case 'asian':
        return 'أسيوي';
      case 'kor':
        return 'كوري';
      case 'jpn':
        return 'ياباني';
      default:
        return language;
    }
  }

  String get countryLabel {
    switch (countryCode.toUpperCase()) {
      case 'SA':
        return 'السعودية';
      case 'AE':
        return 'الإمارات';
      case 'EG':
        return 'مصر';
      case 'MA':
        return 'المغرب';
      case 'DZ':
        return 'الجزائر';
      case 'TN':
        return 'تونس';
      case 'IQ':
        return 'العراق';
      case 'KW':
        return 'الكويت';
      case 'QA':
        return 'قطر';
      case 'JO':
        return 'الأردن';
      case 'LB':
        return 'لبنان';
      case 'SY':
        return 'سوريا';
      case 'YE':
        return 'اليمن';
      case 'OM':
        return 'عمان';
      case 'BH':
        return 'البحرين';
      case 'SD':
        return 'السودان';
      case 'LY':
        return 'ليبيا';
      case 'PS':
        return 'فلسطين';
      case 'MR':
        return 'موريتانيا';
      default:
        return '';
    }
  }

  String get genreLabel {
    switch (genre.toLowerCase()) {
      case 'action':
        return 'أكشن';
      case 'drama':
        return 'دراما';
      case 'comedy':
        return 'كوميدي';
      case 'horror':
        return 'رعب';
      case 'romance':
        return 'رومانسي';
      case 'thriller':
        return 'إثارة';
      case 'scifi':
        return 'خيال علمي';
      case 'fantasy':
        return 'فانتازيا';
      case 'animation':
        return 'رسوم متحركة';
      case 'documentary':
        return 'وثائقي';
      case 'family':
        return 'عائلي';
      case 'crime':
        return 'جريمة';
      case 'mystery':
        return 'غموض';
      case 'war':
        return 'حربي';
      case 'history':
        return 'تاريخي';
      case 'adventure':
        return 'مغامرة';
      case 'kids':
        return 'أطفال';
      default:
        return '';
    }
  }

  String get translationLabel {
    switch (translation) {
      case 'dubbed':
        return 'مدبلج';
      case 'subtitled':
        return 'مترجم';
      case 'original':
        return 'أصلي';
      default:
        return '';
    }
  }

  bool matchesQuery(String q) {
    if (q.trim().isEmpty) return true;
    final query = q.trim().toLowerCase();
    return name.toLowerCase().contains(query) ||
        originalName.toLowerCase().contains(query) ||
        group.toLowerCase().contains(query) ||
        genre.toLowerCase().contains(query);
  }
  
  Channel copyWith({
    String? id,
    String? name,
    String? originalName,
    String? logo,
    String? streamUrl,
    String? group,
    String? category,
    String? language,
    String? countryCode,
    String? genre,
    String? contentType,
    String? translation,
    int? year,
    double? rating,
    bool? isWorking,
    int? priority,
    DateTime? expiresAt,
    String? tvgId,
    bool? isAdult,
    Map<String, String>? extras,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      logo: logo ?? this.logo,
      streamUrl: streamUrl ?? this.streamUrl,
      group: group ?? this.group,
      category: category ?? this.category,
      language: language ?? this.language,
      countryCode: countryCode ?? this.countryCode,
      genre: genre ?? this.genre,
      contentType: contentType ?? this.contentType,
      translation: translation ?? this.translation,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      isWorking: isWorking ?? this.isWorking,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      tvgId: tvgId ?? this.tvgId,
      isAdult: isAdult ?? this.isAdult,
      extras: extras ?? this.extras,
    );
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'غير معروف',
      originalName: json['originalName'] as String? ?? '',
      logo: json['logo'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      group: json['group'] as String? ?? 'غير مصنف',
      category: json['category'] as String? ?? 'general',
      language: json['language'] as String? ?? 'ara',
      countryCode: json['countryCode'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'live',
      translation: json['translation'] as String?,
      year: json['year'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      isWorking: json['isWorking'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      tvgId: json['tvgId'] as String? ?? '',
      isAdult: json['isAdult'] as bool? ?? false,
      extras: (json['extras'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalName': originalName,
      'logo': logo,
      'streamUrl': streamUrl,
      'group': group,
      'category': category,
      'language': language,
      'countryCode': countryCode,
      'genre': genre,
      'contentType': contentType,
      'translation': translation,
      'year': year,
      'rating': rating,
      'isWorking': isWorking,
      'priority': priority,
      'expiresAt': expiresAt?.toIso8601String(),
      'tvgId': tvgId,
      'isAdult': isAdult,
      'extras': extras,
    };
  }

  @override
  String toString() =>
      'Channel($name | $group | $category | $language | $streamFormat)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
