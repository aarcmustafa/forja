/// نموذج موحّد يمثل قناة أو فيلم أو مسلسل في تطبيق IPTV
class Channel {
  final String id;
  final String name;
  final String logo;
  final String streamUrl;
  final String group;       // اسم الباقة (beIN, OSN, MBC...)
  final String category;    // التصنيف الرئيسي: sport, movie, series, general
  final String language;    // ara, tur, hin, eng
  final String contentType; // live, movie, series
  final String? translation; // dubbed, subtitled, original
  final bool isWorking;
  final int priority;       // كل ما زاد، كل ما كان أفضل
  final DateTime? expiresAt;
  final String tvgId;       // للقضاء على التكرار
  final Map<String, String> extras;

  const Channel({
    required this.id,
    required this.name,
    this.logo = '',
    required this.streamUrl,
    this.group = 'غير مصنف',
    this.category = 'general',
    this.language = 'ara',
    this.contentType = 'live',
    this.translation,
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
      default:
        return language;
    }
  }

  /// نوع الترجمة
  String get translationLabel {
    switch (translation) {
      case 'dubbed':
        return 'مدبلج';
      case 'subtitled':
        return 'مترجم';
      default:
        return '';
    }
  }

  /// إنشاء نسخة معدّلة
  Channel copyWith({
    String? id,
    String? name,
    String? logo,
    String? streamUrl,
    String? group,
    String? category,
    String? language,
    String? contentType,
    String? translation,
    bool? isWorking,
    int? priority,
    DateTime? expiresAt,
    String? tvgId,
    Map<String, String>? extras,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      streamUrl: streamUrl ?? this.streamUrl,
      group: group ?? this.group,
      category: category ?? this.category,
      language: language ?? this.language,
      contentType: contentType ?? this.contentType,
      translation: translation ?? this.translation,
      isWorking: isWorking ?? this.isWorking,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      tvgId: tvgId ?? this.tvgId,
      extras: extras ?? this.extras,
    );
  }

  /// من Map (JSON)
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'غير معروف',
      logo: json['logo'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      group: json['group'] as String? ?? 'غير مصنف',
      category: json['category'] as String? ?? 'general',
      language: json['language'] as String? ?? 'ara',
      contentType: json['contentType'] as String? ?? 'live',
      translation: json['translation'] as String?,
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

  /// إلى Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'streamUrl': streamUrl,
      'group': group,
      'category': category,
      'language': language,
      'contentType': contentType,
      'translation': translation,
      'isWorking': isWorking,
      'priority': priority,
      'expiresAt': expiresAt?.toIso8601String(),
      'tvgId': tvgId,
      'extras': extras,
    };
  }

  @override
  String toString() => 'Channel($name | $group | $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
