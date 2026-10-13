import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'features/home/home_screen.dart';
import 'features/live_tv/live_tv_screen.dart';
import 'features/movies/movies_netflix_screen.dart';
import 'features/series/series_netflix_screen.dart';
import 'features/packages/packages_screen.dart';
import 'features/player/player_screen.dart';
import 'data/models/channel.dart';
import 'data/providers/playlist_provider.dart';

// ==========================================================
//  ⚙️  روابط M3U
// ==========================================================
const List<String> kPlaylistUrls = [
  // ============ قنوات مباشرة ============
  'https://m3uextgroup.kiki10kkii.workers.dev/f/gt2izrmxn1nr/Live_AR.m3u',
  'https://m3uextgroup.kiki10kkii.workers.dev/f/htw0iolrrihk/Live_SPORTS.m3u',

  // ============ قنوات رياضية فردية ============
  'https://m3uextractor.kiki10kkii.workers.dev/download/1f48228d-7783-43a8-8533-4228b4c9ba43/Live_AR%20_%20ALWAN%20SPORTS.m3u8',
  'https://m3uextractor.kiki10kkii.workers.dev/download/127c2b7c-21c8-42e9-a903-6aad10029683/Live_AR%20_%20BEIN%20TOD.m3u8',
  'https://m3uextractor.kiki10kkii.workers.dev/download/a3260edc-48d0-4696-aa1e-3fb6916b2d51/Live_AR%20_%20BEIN%20SPORTS%208K.m3u8',
  'https://m3uextractor.kiki10kkii.workers.dev/download/08cdf005-1a6f-48e4-8486-912afa4f918d/Live_BeIN%20SPORTS%20__%20BEE__%20.m3u8',

  // ============ Xtream (قنوات + أفلام + مسلسلات) ============
  'http://dksipi.com:80/get.php?username=kirham2025&password=M0BfTl2CtK&type=m3u_plus&output=m3u8',
  'http://xtreamutv.org:80/get.php?username=7rFgH6sFwy&password=HSzDvxrCy6&type=m3u_plus&output=m3u8',
  'http://prod.dragonkey.net:2082/get.php?username=00228866&password=2pd974kh95&type=m3u_plus&output=m3u8',
];

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
      home: const MainShell(),
    );
  }
}

// ==========================================================
//  الشاشة الرئيسية (Shell)
// ==========================================================
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // فتح التطبيق على "الرئيسية"
  int _selectedIndex = 0;

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
          for (int i = 0; i < _menuItems.length; i++) _buildMenuItem(i),
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
                    Text(
                      _menuItems[index],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
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
  //  المحتوى
  // ==========================================================
  Widget _buildContent() {
    switch (_selectedIndex) {
      case _idxHome:
        return const HomeScreen();

      case _idxLive:
        return LiveTvScreen(
          playlistUrls: kPlaylistUrls,
          onChannelTap: _openPlayer,
        );

      case _idxMovies:
        return const MoviesNetflixScreen();

      case _idxSeries:
        return const SeriesNetflixScreen();

      case _idxPackages:
        return const PackagesScreen();

      case _idxSettings:
      default:
        return _buildPlaceholder();
    }
  }

  // ==========================================================
  //  فتح المشغل
  // ==========================================================
  void _openPlayer(Channel channel) {
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

  // ==========================================================
  //  Placeholder (للإعدادات فقط حالياً)
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
