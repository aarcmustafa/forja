/// نموذج موحّد يمثل قناة أو فيلم أو مسلسل في تطبيق IPTV
class Channel {
  final String id;
  final String name;
  final String originalName; // الاسم الأصلي (بالإنجليزية مثلاً)
  final String logo;
  final String streamUrl;
  final String group;        // اسم الباقة (beIN, OSN, MBC...)
  final String category;     // التصنيف الرئيسي: sport, movie, series, general
  final String language;     // ara, tur, hin, eng, anime, asian
  final String countryCode;  // SA, AE, EG, MA, DZ, IQ, KW, QA, JO, LB, SY
  final String genre;        // action, drama, comedy, horror, kids, doc
  final String contentType;  // live, movie, series
  final String? translation; // dubbed, subtitled, original
  final int? year;           // سنة الفيلم/المسلسل
  final double? rating;      // التقييم
  final bool isWorking;
  final int priority;        // كل ما زاد، كل ما كان أفضل
  final DateTime? expiresAt;
  final String tvgId;        // للقضاء على التكرار
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
    this.extras = const {},
  });

  /// هل الرابط من نوع HLS؟
  bool get isHls => streamUrl.contains('.m3u8');

  /// هل الرابط من نوع m3u عادي؟
  bool get isM3u => streamUrl.contains('.m3u');

  /// التصنيف بالعربية
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

  /// اللغة بالعربية
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

  /// اسم الدولة بالعربية
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
      case 'SO':
        return 'الصومال';
      case 'DJ':
        return 'جيبوتي';
      case 'KM':
        return 'جزر القمر';
      default:
        return '';
    }
  }

  /// النوع بالعربية
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

  /// نوع الترجمة
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

  /// هل هذه القناة/الفيلم مفضل؟
  bool matchesQuery(String q) {
    if (q.trim().isEmpty) return true;
    final query = q.trim().toLowerCase();
    return name.toLowerCase().contains(query) ||
        originalName.toLowerCase().contains(query) ||
        group.toLowerCase().contains(query) ||
        genre.toLowerCase().contains(query);
  }
  
  /// إنشاء نسخة معدّلة
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
      extras: extras ?? this.extras,
    );
  }

  /// من JSON
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
      extras: (json['extras'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
    );
  }

  /// إلى JSON
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
      'extras': extras,
    };
  }

  @override
  String toString() =>
      'Channel($name | $group | $category | $language | $countryCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
