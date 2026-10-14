import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ==========================================================
//  معلومات التطبيق
// ==========================================================
class AppInfo {
  static const String appName = 'استيتن فرجة';
  static const String appSubtitle = 'الرياضية';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String developerAr = 'جلولي مصطفى';
  static const String developerEn = 'Djellouli Mustafa';
  static const String platform = 'Android TV / Google TV';
  static const String year = '2026';
}

// ==========================================================
//  حالة الإعدادات (مبسطة)
// ==========================================================
class SettingsState {
  final bool filterAdult;
  final bool isLoaded;

  const SettingsState({
    this.filterAdult = false,
    this.isLoaded = true,
  });

  SettingsState copyWith({
    bool? filterAdult,
    bool? isLoaded,
  }) {
    return SettingsState(
      filterAdult: filterAdult ?? this.filterAdult,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setFilterAdult(bool value) {
    state = state.copyWith(filterAdult: value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// دالة فحص البالغين (محفوظة للتوافق)
bool isAdultContent(String name, String group) {
  final text = '${name.toLowerCase()} ${group.toLowerCase()}';
  const keywords = [
    'xxx', 'porn', 'adult', 'sex', 'erotic', 'erotik',
    'playboy', 'hustler', 'brazzers', 'penthouse',
    '18+', '+18', 'adultos', 'اباحي', 'إباحي', 'للبالغين',
  ];
  for (final k in keywords) {
    if (text.contains(k)) return true;
  }
  return false;
}

// ==========================================================
//  شاشة الإعدادات
// ==========================================================
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopTitle(),
                const SizedBox(height: 32),
                _sectionTitle('حول التطبيق', Icons.info_rounded),
                const SizedBox(height: 12),
                _infoCard(),
                const SizedBox(height: 24),
                _developerCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  العنوان الرئيسي
  // ==========================================================
  Widget _buildTopTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'معلومات التطبيق',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  //  عنوان قسم
  // ==========================================================
  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00C8FF), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00C8FF),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: const Color(0xFF2A3350))),
      ],
    );
  }

  // ==========================================================
  //  معلومات التطبيق
  // ==========================================================
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3350)),
      ),
      child: Column(
        children: [
          _infoRow('اسم التطبيق', AppInfo.appName),
          const Divider(color: Color(0xFF2A3350), height: 24),
          _infoRow('النوع', AppInfo.appSubtitle),
          const Divider(color: Color(0xFF2A3350), height: 24),
          _infoRow('الإصدار', AppInfo.version),
          const Divider(color: Color(0xFF2A3350), height: 24),
          _infoRow('رقم البناء', AppInfo.buildNumber),
          const Divider(color: Color(0xFF2A3350), height: 24),
          _infoRow('المنصة', AppInfo.platform),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  //  بطاقة المطور
  // ==========================================================
  Widget _developerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.15),
            const Color(0xFF141A2E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                'ج.م',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المطور',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppInfo.developerAr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppInfo.developerEn,
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '© ${AppInfo.year} جميع الحقوق محفوظة',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
