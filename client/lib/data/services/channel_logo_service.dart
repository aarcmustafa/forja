/// خدمة شعارات القنوات — تجلب الشعارات من الإنترنت
class ChannelLogoService {
  static const String _base =
      'https://raw.githubusercontent.com/tv-logo/tv-logos/main/countries';

  static String? getLogo(String channelName) {
    final name = channelName.toLowerCase().trim();

    // ═══════════════════════════════════════════════════════
    //  beIN Sports
    // ═══════════════════════════════════════════════════════
    if (name.contains('bein') || name.contains('بين')) {
      if (name.contains('max') || name.contains('ماكس')) {
        final n = _extractNumber(name);
        if (n != null && n > 0 && n <= 4) {
          return '$_base/qatar/bein-sports-max-$n-qa.png';
        }
        return '$_base/qatar/bein-sports-max-qa.png';
      }

      if (name.contains('premium') || name.contains('بريميوم')) {
        final n = _extractNumber(name);
        if (n != null && n > 0 && n <= 3) {
          return '$_base/qatar/bein-sports-premium-$n-qa.png';
        }
      }

      if (name.contains('english') || name.contains('إنجليزي')) {
        final n = _extractNumber(name);
        if (n != null && n > 0 && n <= 2) {
          return '$_base/qatar/bein-sports-english-$n-qa.png';
        }
      }

      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 16) {
        return '$_base/qatar/bein-sports-$n-qa.png';
      }

      return '$_base/qatar/bein-sports-qa.png';
    }

    // ═══════════════════════════════════════════════════════
    //  Al Kass
    // ═══════════════════════════════════════════════════════
    if (name.contains('alkass') ||
        name.contains('al kass') ||
        name.contains('الكأس')) {
      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 2) {
        return '$_base/qatar/al-kass-$n-qa.png';
      }
      return '$_base/qatar/al-kass-qa.png';
    }

    // ═══════════════════════════════════════════════════════
    //  Abu Dhabi Sports
    // ═══════════════════════════════════════════════════════
    if (name.contains('abu dhabi') ||
        name.contains('ad sport') ||
        name.contains('أبوظبي')) {
      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 2) {
        return '$_base/uae/abu-dhabi-sports-$n-ae.png';
      }
      return '$_base/uae/abu-dhabi-sports-ae.png';
    }

    // ═══════════════════════════════════════════════════════
    //  Dubai Sports
    // ═══════════════════════════════════════════════════════
    if (name.contains('dubai sport') || name.contains('دبي الرياضية')) {
      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 3) {
        return '$_base/uae/dubai-sports-$n-ae.png';
      }
      return '$_base/uae/dubai-sports-ae.png';
    }

    // ═══════════════════════════════════════════════════════
    //  SSC
    // ═══════════════════════════════════════════════════════
    if (name.contains('ssc')) {
      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 5) {
        return '$_base/saudi/ssc-$n-sa.png';
      }
      return '$_base/saudi/ssc-sa.png';
    }

    // ═══════════════════════════════════════════════════════
    //  KSA Sports
    // ═══════════════════════════════════════════════════════
    if (name.contains('ksa sport') || name.contains('السعودية الرياضية')) {
      final n = _extractNumber(name);
      if (n != null && n > 0 && n <= 2) {
        return '$_base/saudi/ksa-sports-$n-sa.png';
      }
      return '$_base/saudi/ksa-sports-sa.png';
    }

    return null;
  }

  static int? _extractNumber(String text) {
    final match = RegExp(r'(\d{1,2})').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
