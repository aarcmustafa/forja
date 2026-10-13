import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/live_tv/live_tv_screen.dart';
import 'data/models/channel.dart';

// ==========================================================
//  ⚙️  روابط M3U — ضع روابطك هنا
// ==========================================================
const List<String> kPlaylistUrls = [
  // مثال:
  // 'https://example.com/playlist1.m3u',
  // 'https://example.com/playlist2.m3u8',
];

// ==========================================================
//  نقطة انطلاق التطبيق
// ==========================================================
void main() {
  runApp(
    const ProviderScope(   // ← مطلوب لـ Riverpod
      child: EstetnFarjaTvApp(),
    ),
  );
}

class EstetnFarjaTvApp extends StatelessWidget {
  const EstetnFarjaTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estetn Farja TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C8FF),
          secondary: Color(0xFFFFB800),
          surface: Color(0xFF141A2E),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================================
//  الشاشة الرئيسية (جانبية + محتوى)
// ==========================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // فهارس التطبيق
  static const int _idxHome = 0;
  static const int _idxLive = 1;
  static const int _idxMovies = 2;
  static const int _idxSeries = 3;
  static const int _idxPackages = 4;
  static const int _idxSettings = 5;

  final List<String> _menuItems = const [
    'الرئيسية',
    'البث المباشر',
    'الأفلام',
    'المسلسلات',
    'الباقات',
    'الإعدادات',
  ];

  final List<IconData> _menuIcons = const [
    Icons.home_rounded,
    Icons.live_tv_rounded,
    Icons.movie_rounded,
    Icons.tv_rounded,
    Icons.list_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  الشريط الجانبي
  // ==========================================================
  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: const Color(0xFF141A2E),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'استيتن فرجة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C8FF),
              ),
            ),
          ),
          const Divider(color: Color(0xFF2A3350)),
          const SizedBox(height: 12),
          for (int i = 0; i < _menuItems.length; i++)
            _buildMenuItem(i),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && _selectedIndex != index) {
            setState(() => _selectedIndex = index);
          }
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            final active = hasFocus || isSelected;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF00C8FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _menuIcons[index],
                      color: active ? Colors.black : Colors.white70,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _menuItems[index],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: active ? Colors.black : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  //  المحتوى (حسب الاختيار)
  // ==========================================================
  Widget _buildContent() {
    switch (_selectedIndex) {
      case _idxLive:
        return LiveTvScreen(
          playlistUrls: kPlaylistUrls,
          onChannelTap: _onChannelTap,
        );

      case _idxHome:
      case _idxMovies:
      case _idxSeries:
      case _idxPackages:
      case _idxSettings:
      default:
        return _buildPlaceholder();
    }
  }

  // ==========================================================
  //  عند الضغط على قناة
  // ==========================================================
  void _onChannelTap(Channel channel) {
    // TODO: فتح المشغل — سنبنيه في المرحلة القادمة
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141A2E),
          title: Text(
            channel.name,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'الباقة: ${channel.group}\n'
            'التصنيف: ${channel.categoryLabel}\n'
            'اللغة: ${channel.languageLabel}\n'
            'الحالة: ${channel.isWorking ? "تعمل" : "متوقفة"}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF00C8FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  شاشة مؤقتة للأقسام الأخرى
  // ==========================================================
  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _menuItems[_selectedIndex],
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _menuIcons[_selectedIndex],
                    size: 80,
                    color: const Color(0xFF00C8FF).withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _menuItems[_selectedIndex],
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قيد التطوير',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
