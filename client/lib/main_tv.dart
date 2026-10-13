import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'features/home/home_screen.dart';
import 'features/live_tv/live_tv_screen.dart';
import 'features/movies/movies_netflix_screen.dart';
import 'features/series/series_netflix_screen.dart';
import 'features/packages/packages_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/player/player_screen.dart';
import 'features/search/unified_search_screen.dart';
import 'data/models/channel.dart';
import 'data/providers/playlist_provider.dart';
import 'data/providers/favorites_provider.dart';
import 'data/providers/history_provider.dart';
import 'data/local/secure_config.dart';

// ==========================================================
//  ⚙️  روابط M3U (مشفّرة — تُفكّ في الذاكرة فقط)
// ==========================================================
final List<String> kPlaylistUrls = SecureConfig.urls;

// ==========================================================
//  نقطة انطلاق التطبيق
// ==========================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EstetnFarjaTvApp(),
    ),
  );
}

class EstetnFarjaTvApp extends StatelessWidget {
  const EstetnFarjaTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'استيتن فرجة',
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
      home: const MainShell(),
    );
  }
}

// ==========================================================
//  الشاشة الرئيسية
// ==========================================================
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static const int _idxHome = 0;
  static const int _idxLive = 1;
  static const int _idxMovies = 2;
  static const int _idxSeries = 3;
  static const int _idxFavorites = 4;
  static const int _idxPackages = 5;
  static const int _idxSettings = 6;

  final List<String> _menuItems = const [
    'الرئيسية',
    'البث المباشر',
    'الأفلام',
    'المسلسلات',
    'المفضلة',
    'الباقات',
    'الإعدادات',
  ];

  final List<IconData> _menuIcons = const [
    Icons.home_rounded,
    Icons.live_tv_rounded,
    Icons.movie_rounded,
    Icons.tv_rounded,
    Icons.favorite_rounded,
    Icons.list_rounded,
    Icons.settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylistsIfNeeded();
    });
  }

  Future<void> _loadPlaylistsIfNeeded() async {
    if (kPlaylistUrls.isEmpty) return;
    final state = ref.read(playlistProvider);
    if (state.allChannels.isNotEmpty || state.isLoading) return;
    await ref.read(playlistProvider.notifier).loadPlaylists(kPlaylistUrls);
  }

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
    final favCount = ref.watch(favoritesProvider).length;

    return Container(
      width: 220,
      color: const Color(0xFF141A2E),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
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

          // 🔍 زر البحث الموحد
          _buildSearchButton(),

          const SizedBox(height: 8),

          // القائمة الرئيسية
          for (int i = 0; i < _menuItems.length; i++)
            _buildMenuItem(i, badge: i == _idxFavorites ? favCount : 0),

          const Spacer(),
          const Divider(color: Color(0xFF2A3350)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإصدار 1.0.0',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                SizedBox(height: 4),
                Text(
                  'المطور: جلولي مصطفى',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '© 2025',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ==========================================================
  //  زر البحث
  // ==========================================================
  Widget _buildSearchButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        onFocusChange: (hasFocus) {},
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UnifiedSearchScreen(),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: hasFocus
                      ? const Color(0xFFFFB800)
                      : const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFocus
                        ? Colors.white
                        : const Color(0xFF2A3350),
                    width: hasFocus ? 2 : 1,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withOpacity(0.5),
                            blurRadius: 14,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: hasFocus
                          ? Colors.black
                          : const Color(0xFFFFB800),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'بحث',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            hasFocus ? FontWeight.bold : FontWeight.w500,
                        color: hasFocus
                            ? Colors.black
                            : const Color(0xFFFFB800),
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
  //  عنصر قائمة
  // ==========================================================
  Widget _buildMenuItem(int index, {int badge = 0}) {
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
                  color: active ? const Color(0xFF00C8FF) : Colors.transparent,
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
                    Expanded(
                      child: Text(
                        _menuItems[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                          color: active ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.black
                              : const Color(0xFFFF1744),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF00C8FF)
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
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
  //  المحتوى
  // ==========================================================
  Widget _buildContent() {
    switch (_selectedIndex) {
      case _idxHome:
        return const HomeScreen();

      case _idxLive:
        return LiveTvScreen(
          playlistUrls: kPlaylistUrls,
          onChannelTap: _openChannel,
        );

      case _idxMovies:
        return const MoviesNetflixScreen();

      case _idxSeries:
        return const SeriesNetflixScreen();

      case _idxFavorites:
        return const FavoritesScreen();

      case _idxPackages:
        return const PackagesScreen();

      case _idxSettings:
        return const SettingsScreen();

      default:
        return const HomeScreen();
    }
  }

  // ==========================================================
  //  فتح القناة (مع تسجيل في السجل)
  // ==========================================================
  void _openChannel(Channel channel) {
    ref.read(historyProvider.notifier).record(channel);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: channel.streamUrl,
          channelName: channel.name,
          channelLogo: channel.logo,
        ),
      ),
    );
  }
}
