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
import 'data/config/app_config.dart';
import 'data/local/remote_config.dart';
import 'data/services/notification_service.dart';

// ==========================================================
//  نقطة انطلاق التطبيق
// ==========================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  try {
    await NotificationService().init();
  } catch (_) {}

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
      title: 'استيتن فرجة الرياضية',
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
      final settings = ref.read(settingsProvider);
      NotificationService().setEnabled(settings.matchNotifications);
    } catch (_) {}

    if (kPlaylistUrls.isEmpty) {
      try {
        final remote = RemoteConfig();
        final cached = await remote.loadCached();
        if (cached.isNotEmpty) {
          kPlaylistUrls = cached;
        }
      } catch (_) {}
    }

    if (kPlaylistUrls.isNotEmpty) {
      final state = ref.read(playlistProvider);
      if (state.allChannels.isEmpty && !state.isLoading) {
        ref
            .read(playlistProvider.notifier)
            .loadPlaylists(kPlaylistUrls);
      }
    }

    try {
      final remote = RemoteConfig();
      final remoteUrls = await remote.fetchRemote();
      if (remoteUrls != null && remoteUrls.isNotEmpty) {
        kPlaylistUrls = remoteUrls;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
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
      width: 240,
      color: const Color(0xFF141A2E),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الترويسة
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xFF00C8FF),
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'استيتن فرجة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C8FF),
                  ),
                ),
                Text(
                  'الرياضية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2A3350)),
          const SizedBox(height: 8),

          // زر البحث
          _buildMenuButton(
            index: -1,
            icon: Icons.search_rounded,
            label: 'بحث',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UnifiedSearchScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // عناصر القائمة
          for (int i = 0; i < _menuItems.length; i++)
            _buildMenuButton(
              index: i,
              icon: _menuIcons[i],
              label: _menuItems[i],
              badge: i == _idxFavorites ? favCount : 0,
              onTap: () => setState(() => _selectedIndex = i),
            ),

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

  // ==========================================================
  //  زر قائمة واحد
  // ==========================================================
  Widget _buildMenuButton({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    final isSelected = index >= 0 && _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _FocusableMenuButton(
        isSelected: isSelected,
        icon: icon,
        label: label,
        badge: badge,
        onTap: onTap,
      ),
    );
  }

  // ==========================================================
  //  المحتوى الرئيسي
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
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: channel.streamUrl,
          channelName: channel.name,
          channelLogo: channel.logo,
          extras: channel.extras,
        ),
      ),
    );
  }
}

// ==========================================================
//  زر قائمة قابل للتركيز
// ==========================================================
class _FocusableMenuButton extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _FocusableMenuButton({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_FocusableMenuButton> createState() => _FocusableMenuButtonState();
}

class _FocusableMenuButtonState extends State<_FocusableMenuButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = _isFocused || widget.isSelected;

    return Focus(
      onFocusChange: (h) {
        if (mounted) setState(() => _isFocused = h);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
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
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : Colors.transparent,
              width: _isFocused ? 2 : 0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: active ? Colors.black : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.black : Colors.white70,
                  ),
                ),
              ),
              if (widget.badge > 0)
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
                    '${widget.badge}',
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
      ),
    );
  }
}
