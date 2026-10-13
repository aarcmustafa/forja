import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'features/home/home_screen.dart';
import 'features/live_tv/live_tv_screen.dart';
import 'features/live_tv/widgets/sports_matches_widget.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/packages/packages_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/player/player_screen.dart';
import 'features/search/unified_search_screen.dart';
import 'data/models/channel.dart';
import 'data/providers/playlist_provider.dart';
import 'data/providers/favorites_provider.dart';
import 'data/providers/history_provider.dart';
import 'data/local/secure_config.dart';
import 'data/local/remote_config.dart';
import 'core/animations/app_animations.dart';

// ==========================================================
//  روابط M3U
// ==========================================================
List<String> kPlaylistUrls = SecureConfig.urls;

// ==========================================================
//  نقطة انطلاق التطبيق
// ==========================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EstetnFarjaMobileApp(),
    ),
  );
}

class EstetnFarjaMobileApp extends StatelessWidget {
  const EstetnFarjaMobileApp({super.key});

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
      home: const MobileShell(),
    );
  }
}

// ==========================================================
//  Mobile Shell — Bottom Navigation
// ==========================================================
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _selectedIndex = 0;

  // فهارس
  static const int _idxHome = 0;
  static const int _idxLive = 1;
  static const int _idxMatches = 2;
  static const int _idxFavorites = 3;
  static const int _idxMore = 4;

  final List<String> _titles = const [
    'الرئيسية',
    'البث المباشر',
    'المباريات',
    'المفضلة',
    'المزيد',
  ];

  final List<IconData> _icons = const [
    Icons.home_rounded,
    Icons.live_tv_rounded,
    Icons.sports_soccer_rounded,
    Icons.favorite_rounded,
    Icons.more_horiz_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylistsIfNeeded();
    });
  }

  // ==========================================================
  //  تحميل القنوات (نفس منطق التلفاز)
  // ==========================================================
  Future<void> _loadPlaylistsIfNeeded() async {
    try {
      final repo = ref.read(m3uRepositoryProvider);
      await repo.maintainCache();
      final storage = ref.read(localStorageProvider);
      await storage.maintain();
    } catch (_) {}

    try {
      final remote = RemoteConfig();
      final cached = await remote.loadCached();
      if (cached.isNotEmpty) {
        kPlaylistUrls = cached;
      }
      remote.fetchRemote().then((remoteUrls) {
        if (remoteUrls != null && remoteUrls.isNotEmpty) {
          kPlaylistUrls = remoteUrls;
        }
      });
    } catch (_) {}

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
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: _buildAppBar(),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const HomeScreen(),
            LiveTvScreen(
              playlistUrls: kPlaylistUrls,
              onChannelTap: _openChannel,
            ),
            _buildMatchesScreen(),
            const FavoritesScreen(),
            const _MoreScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ==========================================================
  //  AppBar
  // ==========================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF141A2E),
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'استيتن فرجة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _titles[_selectedIndex],
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              FadeSlideRoute(page: const UnifiedSearchScreen()),
            );
          },
          icon: const Icon(
            Icons.search_rounded,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  //  Bottom Navigation Bar
  // ==========================================================
  Widget _buildBottomNav() {
    final favCount = ref.watch(favoritesProvider).length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141A2E),
        border: Border(
          top: BorderSide(color: Color(0xFF2A3350), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: Colors.white54,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: [
            for (int i = 0; i < _titles.length; i++)
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(_icons[i]),
                    if (i == _idxFavorites && favCount > 0)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF1744),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            favCount > 99 ? '99+' : '$favCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Icon(
                  _icons[i],
                  color: const Color(0xFF4CAF50),
                ),
                label: _titles[i],
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  شاشة المباريات
  // ==========================================================
  Widget _buildMatchesScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            SportsMatchesWidget(
              onChannelTap: _openChannel,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  فتح القناة
  // ==========================================================
  void _openChannel(Channel channel) {
    ref.read(historyProvider.notifier).record(channel);
    Navigator.push(
      context,
      FadeSlideRoute(
        page: PlayerScreen(
          streamUrl: channel.streamUrl,
          channelName: channel.name,
          channelLogo: channel.logo,
        ),
      ),
    );
  }
}

// ==========================================================
//  شاشة "المزيد" (الباقات + الإعدادات)
// ==========================================================
class _MoreScreen extends ConsumerStatefulWidget {
  const _MoreScreen();

  @override
  ConsumerState<_MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<_MoreScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // شريط تبويبات علوي
        Container(
          color: const Color(0xFF0A0E1A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _MoreTab(
                  label: 'الباقات',
                  icon: Icons.list_rounded,
                  isSelected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MoreTab(
                  label: 'الإعدادات',
                  icon: Icons.settings_rounded,
                  isSelected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ),
            ],
          ),
        ),

        // المحتوى
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: const [
              PackagesScreen(),
              SettingsScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================================
//  زر تبويب "المزيد"
// ==========================================================
class _MoreTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoreTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50)
              : const Color(0xFF141A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2A3350),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
