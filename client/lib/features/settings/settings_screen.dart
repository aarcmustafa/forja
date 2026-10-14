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
  }title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return _FocusTile(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3350)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFFFB800), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white38,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

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
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'J.M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
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
                'Developer',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                AppInfo.developer,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '© ${AppInfo.year} All rights reserved',
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
  
  Future<void> _showSetPinDialog() async {
    final ctrl = TextEditingController();
    final confirm = TextEditingController();
    String? error;

    return showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.password_rounded, color: Color(0xFF4CAF50)),
                  SizedBox(width: 10),
                  Text(
                    'تعيين كود PIN',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'أدخل كوداً مكوناً من 4 أرقام',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _inputDec('الكود الجديد'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirm,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _inputDec('تأكيد الكود'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final c = ctrl.text.trim();
                    final cf = confirm.text.trim();
                    if (c.length != 4) {
                      setSt(() => error = 'الكود يجب أن يكون 4 أرقام');
                      return;
                    }
                    if (c != cf) {
                      setSt(() => error = 'الكودان غير متطابقان');
                      return;
                    }
                    await ref.read(settingsProvider.notifier).setPinCode(c);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack('تم تعيين كود PIN بنجاح');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFF0A0E1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF141A2E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ==========================================================
//  بطاقة قابلة للتركيز
// ==========================================================
class _FocusTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _FocusTile({required this.child, required this.onTap});

  @override
  State<_FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<_FocusTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onTap();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: AnimatedScale(
            scale: _isFocused ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: widget.child,
          ),
        ),
      ),
    );
  }
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
