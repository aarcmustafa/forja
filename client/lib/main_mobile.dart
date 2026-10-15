import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'features/home/home_screen.dart';
import 'features/live_tv/live_tv_screen.dart';
import 'features/live_tv/widgets/sports_matches_widget.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/player/player_screen.dart';
import 'features/search/unified_search_screen.dart';
import 'data/models/channel.dart';
import 'data/providers/playlist_provider.dart';
import 'data/providers/history_provider.dart';
import 'data/config/app_config.dart';
import 'data/local/remote_config.dart';

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
      home: const MobileShell(),
    );
  }
}

// ==========================================================
//  الشاشة الرئيسية للهاتف
// ==========================================================
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _selectedIndex = 0;

  final List<String> _titles = const [
    'الرئيسية',
    'البث المباشر',
    'المباريات',
    'المفضلة',
    'الإعدادات',
  ];

  final List<IconData> _icons = const [
    Icons.home_rounded,
    Icons.live_tv_rounded,
    Icons.sports_soccer_rounded,
    Icons.favorite_rounded,
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
        body: _buildContent(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const HomeScreen();

      case 1:
        return LiveTvScreen(
          playlistUrls: kPlaylistUrls,
          onChannelTap: _openChannel,
        );

      case 2:
        return _buildMatchesScreen();

      case 3:
        return const FavoritesScreen();

      case 4:
        return const SettingsScreen();

      default:
        return const HomeScreen();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141A2E),
        border: Border(
          top: BorderSide(color: Color(0xFF2A3350), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00C8FF),
        unselectedItemColor: Colors.white54,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: List.generate(
          _titles.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _titles[i],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A2E),
        elevation: 0,
        title: const Text(
          'مباريات اليوم',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: SingleChildScrollView(
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

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UnifiedSearchScreen(),
      ),
    );
  }
}
