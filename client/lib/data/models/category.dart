/// نموذج التصنيف - يدعم تصنيفات متداخلة
/// مثال: رياضة → beIN Sports, AD Sports, Al Kass
///       أفلام → عربي، تركي، هندي، أجنبي
class Category {
  final String id;
  final String name;          // الاسم بالعربية للعرض
  final String slug;          // المعرّف بالإنجليزية (sport, movie...)
  final String iconName;      // اسم الأيقونة
  final int order;            // ترتيب الظهور
  final List<SubCategory> subCategories; // الباقات الفرعية
  final int channelsCount;    // عدد القنوات الكلي

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName = 'tv',
    this.order = 0,
    this.subCategories = const [],
    this.channelsCount = 0,
  });

  /// إنشاء نسخة معدّلة
  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? iconName,
    int? order,
    List<SubCategory>? subCategories,
    int? channelsCount,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconName: iconName ?? this.iconName,
      order: order ?? this.order,
      subCategories: subCategories ?? this.subCategories,
      channelsCount: channelsCount ?? this.channelsCount,
    );
  }

  /// من JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'tv',
      order: json['order'] as int? ?? 0,
      subCategories: (json['subCategories'] as List<dynamic>?)
              ?.map((e) => SubCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      channelsCount: json['channelsCount'] as int? ?? 0,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'iconName': iconName,
      'order': order,
      'subCategories': subCategories.map((e) => e.toJson()).toList(),
      'channelsCount': channelsCount,
    };
  }

  @override
  String toString() => 'Category($name - $channelsCount channels)';
}

/// الباقة الفرعية (مثل beIN Sports، OSN، MBC)
class SubCategory {
  final String id;
  final String name;         // اسم الباقة: beIN Sports
  final String slug;         // beIN, osn, mbc
  final String? logo;        // شعار الباقة
  final int order;
  final int channelsCount;

  const SubCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.order = 0,
    this.channelsCount = 0,
  });

  SubCategory copyWith({
    String? id,
    String? name,
    String? slug,
    String? logo,
    int? order,
    int? channelsCount,
  }) {
    return SubCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logo: logo ?? this.logo,
      order: order ?? this.order,
      channelsCount: channelsCount ?? this.channelsCount,
    );
  }

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logo: json['logo'] as String?,
      order: json['order'] as int? ?? 0,
      channelsCount: json['channelsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo': logo,
      'order': order,
      'channelsCount': channelsCount,
    };
  }

  @override
  String toString() => 'SubCategory($name)';
}

/// قائمة التصنيفات الجاهزة (يمكن تحميلها من API لاحقاً)
class DefaultCategories {
  static final List<Category> list = [
    Category(
      id: '1',
      name: 'رياضة',
      slug: 'sport',
      iconName: 'sports',
      order: 1,
      subCategories: const [
        SubCategory(id: '1-1', name: 'beIN Sports', slug: 'bein', order: 1),
        SubCategory(id: '1-2', name: 'AD Sports', slug: 'adsports', order: 2),
        SubCategory(id: '1-3', name: 'Al Kass', slug: 'alkass', order: 3),
        SubCategory(id: '1-4', name: 'SSC Sports', slug: 'ssc', order: 4),
        SubCategory(id: '1-5', name: 'Dubai Sports', slug: 'dubai', order: 5),
        SubCategory(id: '1-6', name: 'KSA Sports', slug: 'ksa', order: 6),
      ],
    ),
    Category(
      id: '2',
      name: 'أفلام',
      slug: 'movie',
      iconName: 'movie',
      order: 2,
      subCategories: const [
        SubCategory(id: '2-1', name: 'أفلام عربية', slug: 'arabic', order: 1),
        SubCategory(id: '2-2', name: 'أفلام تركية', slug: 'turkish', order: 2),
        SubCategory(id: '2-3', name: 'أفلام هندية', slug: 'hindi', order: 3),
        SubCategory(id: '2-4', name: 'أفلام أجنبية', slug: 'foreign', order: 4),
        SubCategory(id: '2-5', name: 'OSN Movies', slug: 'osn', order: 5),
        SubCategory(id: '2-6', name: 'MBC Movies', slug: 'mbc', order: 6),
      ],
    ),
    Category(
      id: '3',
      name: 'مسلسلات',
      slug: 'series',
      iconName: 'series',
      order: 3,
      subCategories: const [
        SubCategory(id: '3-1', name: 'مسلسلات عربية', slug: 'arabic', order: 1),
        SubCategory(id: '3-2', name: 'مسلسلات تركية', slug: 'turkish', order: 2),
        SubCategory(id: '3-3', name: 'مسلسلات هندية', slug: 'hindi', order: 3),
        SubCategory(id: '3-4', name: 'مسلسلات أجنبية', slug: 'foreign', order: 4),
      ],
    ),
    Category(
      id: '4',
      name: 'أخبار',
      slug: 'news',
      iconName: 'news',
      order: 4,
      subCategories: const [
        SubCategory(id: '4-1', name: 'العربية', slug: 'alarabiya', order: 1),
        SubCategory(id: '4-2', name: 'الجزيرة', slug: 'jazeera', order: 2),
        SubCategory(id: '4-3', name: 'Sky News', slug: 'skynews', order: 3),
      ],
    ),
    Category(
      id: '5',
      name: 'أطفال',
      slug: 'kids',
      iconName: 'kids',
      order: 5,
      subCategories: const [
        SubCategory(id: '5-1', name: 'كرتون عربي', slug: 'arabic-kids', order: 1),
        SubCategory(id: '5-2', name: 'سبيستون', slug: 'spacetoon', order: 2),
        SubCategory(id: '5-3', name: 'MBC 3', slug: 'mbc3', order: 3),
      ],
    ),
    Category(
      id: '6',
      name: 'قنوات عامة',
      slug: 'general',
      iconName: 'general',
      order: 6,
      subCategories: const [
        SubCategory(id: '6-1', name: 'قنوات عربية', slug: 'arabic-tv', order: 1),
        SubCategory(id: '6-2', name: 'قنوات وثائقية', slug: 'documentary', order: 2),
        SubCategory(id: '6-3', name: 'قنوات موسيقية', slug: 'music', order: 3),
      ],
    ),
  ];
}
