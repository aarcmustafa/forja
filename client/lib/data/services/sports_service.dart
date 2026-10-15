// ══════════════════════════════════════════════════════════
//  فلترة بالمستويات حسب الأولوية
// ══════════════════════════════════════════════════════════
List<SportMatch> filterImportant(List<SportMatch> matches) {
  final filtered = matches.where((m) => _getPriority(m) < 999).toList();

  filtered.sort((a, b) {
    final pa = _getPriority(a);
    final pb = _getPriority(b);
    if (pa != pb) return pa.compareTo(pb);

    // نفس الأولوية → المباشر أولاً
    final aLive = a.isLive ? 0 : 1;
    final bLive = b.isLive ? 0 : 1;
    if (aLive != bLive) return aLive.compareTo(bLive);

    // ثم حسب الوقت
    return a.startTime.compareTo(b.startTime);
  });

  return filtered;
}

/// ✅ نظام الأولويات الرقمي
/// كلما صغر الرقم، ظهر أولاً
int _getPriority(SportMatch m) {
  // ═══════════════════════════════════════════════════
  //  🥇 1) المنتخب الجزائري — أولوية قصوى (0-99)
  // ═══════════════════════════════════════════════════
  if (_isAlgeriaNational(m)) {
    if (m.isLive) return 0;
    return 10;
  }

  // ═══════════════════════════════════════════════════
  //  🥈 2) كأس العالم — أي مباراة (100-199)
  // ═══════════════════════════════════════════════════
  if (_isWorldCup(m)) {
    if (m.isLive) return 100;
    return 110;
  }

  // ═══════════════════════════════════════════════════
  //  🥉 3) كأس أمم إفريقيا — مع الجزائر (200-299)
  // ═══════════════════════════════════════════════════
  if (_isAfconWithAlgeria(m)) {
    if (m.isLive) return 200;
    return 210;
  }

  // ═══════════════════════════════════════════════════
  //  4) الدوريات الأوروبية الكبرى (400-499)
  // ═══════════════════════════════════════════════════
  if (_isTopEuropeanLeague(m)) {
    if (m.isLive) return 400;
    return 410;
  }

  // ═══════════════════════════════════════════════════
  //  ❌ مستبعد (الأندية الجزائرية + كل الباقي)
  // ═══════════════════════════════════════════════════
  return 999;
}

// ==========================================================
//  🇩🇿 المنتخب الجزائري (أي مسابقة)
// ==========================================================
bool _isAlgeriaNational(SportMatch m) {
  final patterns = [
    RegExp(r'\balgeria\b', caseSensitive: false),
    RegExp(r'\balgérie\b', caseSensitive: false),
    RegExp(r'\bالجزائر\b'),
  ];

  for (final p in patterns) {
    if (p.hasMatch(m.homeTeam) || p.hasMatch(m.awayTeam)) return true;
  }
  return false;
}

// ==========================================================
//  🏆 كأس العالم (أي مباراة)
// ==========================================================
bool _isWorldCup(SportMatch m) {
  final league = m.league.toLowerCase();

  // كأس العالم للكبار (استبعاد الفئات السنية والنساء)
  if (league.contains('fifa world cup') &&
      !league.contains('club') &&
      !league.contains('women') &&
      !league.contains('u17') &&
      !league.contains('u20') &&
      !league.contains('u23')) {
    return true;
  }
  if (league == 'world cup') return true;

  // التصفيات المؤهلة
  if (league.contains('world cup qualification') ||
      league.contains('world cup qualifiers')) {
    return true;
  }

  return false;
}

// ==========================================================
//  🌍 كأس أمم إفريقيا مع المنتخب الجزائري
// ==========================================================
bool _isAfconWithAlgeria(SportMatch m) {
  final league = m.league.toLowerCase();

  final isAfcon = league.contains('africa cup') ||
      league.contains('afcon') ||
      league.contains('caf africa cup') ||
      league.contains('africa cup of nations') ||
      league.contains('كأس أمم إفريقيا') ||
      league.contains('كأس الأمم الإفريقية');

  if (!isAfcon) return false;

  return _isAlgeriaNational(m);
}

// ==========================================================
//  🏆 الدوريات الأوروبية الكبرى
// ==========================================================
bool _isTopEuropeanLeague(SportMatch m) {
  final league = m.league.toLowerCase().trim();
  if (league.isEmpty) return false;

  // استثناءات (ليست أوروبية)
  if (league.contains('brazilian')) return false;
  if (league.contains('egyptian')) return false;
  if (league.contains('saudi')) return false;
  if (league.contains('japanese')) return false;
  if (league.contains('chinese')) return false;
  if (league.contains('korean')) return false;
  if (league.contains('american') || league.contains('mls')) return false;
  if (league.contains('mexican')) return false;
  if (league.contains('argentinian') || league.contains('argentina')) {
    return false;
  }
  if (league.contains('turkish')) return false;
  if (league.contains('russian')) return false;
  if (league.contains('greek')) return false;
  if (league.contains('ukrainian')) return false;

  // المسابقات القارية الأوروبية
  if (league.contains('uefa champions league')) return true;
  if (league.contains('uefa europa league')) return true;
  if (league.contains('uefa europa conference league')) return true;
  if (league.contains('uefa conference league')) return true;

  // الدوريات المحلية الكبرى
  if (league.contains('english premier league')) return true;
  if (league == 'premier league') return true;

  if (league.contains('spanish la liga')) return true;
  if (league == 'la liga') return true;

  if (league.contains('italian serie a')) return true;
  if (league == 'serie a') return true;

  if (league.contains('german bundesliga')) return true;
  if (league == 'bundesliga') return true;

  if (league.contains('french ligue 1')) return true;
  if (league == 'ligue 1') return true;

  if (league.contains('portuguese primeira liga')) return true;
  if (league == 'primeira liga') return true;

  if (league.contains('dutch eredivisie')) return true;
  if (league == 'eredivisie') return true;

  return false;
}
