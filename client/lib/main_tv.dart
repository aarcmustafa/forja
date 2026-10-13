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

List<String> kPlaylistUrls = SecureConfig.urls;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SttitenFootTvApp(),
    ),
  );
}

class SttitenFootTvApp extends StatelessWidget {
  const SttitenFootTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STTITEN FOOT',
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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static const int _idxHome = 0;
  static const int _idxLive = 1;
  static const int _idxMatches = 2;
  static const int _idxFavorites = 3;
  static const int _idxPackages = 4;
  static const int _idxSettings = 5;

  final List<String> _menuItems = const [
    'الرئيسية',
    'البث المباشر',
    'المباريات',
    'المفضلة',
    'الباقات',
    'الإعدادات',
  ];

  final List<IconData> _menuIcons = const [
    Icons.home_rounded,
    Icons.live_tv_rounded,
    Icons.sports_soccer_rounded,
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
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

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
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xFF4CAF50),
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'STTITEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'FOOT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3350)),
          const SizedBox(height: 8),

          _buildSearchButton(),
          const SizedBox(height: 8),

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
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                SizedBox(height: 4),
                Text(
                  'Developer: J. Mustapha',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '© 2026',
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
                  FadeSlideRoute(
                    page: const UnifiedSearchScreen(),
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
                      'Search',
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
                  color: active ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _menuIcons[index],
                      color: active ? Colors.white : Colors.white70,
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
                          color: active ? Colors.white : Colors.white70,
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
                              ? Colors.white
                              : const Color(0xFFFF1744),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF4CAF50)
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
  
  Widget _buildContent() {
    switch (_selectedIndex) {
      case _idxHome:
        return const HomeScreen();

      case _idxLive:
        return LiveTvScreen(
          playlistUrls: kPlaylistUrls,
          onChannelTap: _openChannel,
        );

      case _idxMatches:
        return _buildMatchesScreen();

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

  Widget _buildMatchesScreen() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                SportsMatchesWidget(
                  onChannelTap: _openChannel,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
