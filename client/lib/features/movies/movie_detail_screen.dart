import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/history_provider.dart';
import '../../data/providers/favorites_provider.dart';
import '../player/player_screen.dart';

/// شاشة تفاصيل الفيلم — تعرض كل المعلومات قبل التشغيل
class MovieDetailScreen extends ConsumerStatefulWidget {
  final Channel movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final isFav = ref.watch(favoritesProvider).contains(movie.id);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(movie),
                const SizedBox(height: 24),
                _buildActionButtons(movie, isFav),
                const SizedBox(height: 28),
                _buildInfoSection(movie),
                const SizedBox(height: 24),
                _buildMetadataChips(movie),
                const SizedBox(height: 24),
                _buildStreamInfo(movie),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  القسم العلوي
  // ==========================================================
  Widget _buildHeroSection(Channel movie) {
    return Stack(
      children: [
        Container(
          height: 380,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2238), Color(0xFF0A0E1A)],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPoster(movie),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      if (movie.originalName.isNotEmpty &&
                          movie.originalName != movie.name) ...[
                        const SizedBox(height: 8),
                        Text(
                          movie.originalName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (movie.year != null)
                            _buildInfoBadge(
                              Icons.calendar_today_rounded,
                              '${movie.year}',
                            ),
                          if (movie.genreLabel.isNotEmpty)
                            _buildInfoBadge(
                              Icons.local_movies_rounded,
                              movie.genreLabel,
                            ),
                          if (movie.rating != null)
                            _buildInfoBadge(
                              Icons.star_rounded,
                              movie.rating!.toStringAsFixed(1),
                              color: const Color(0xFFFFB800),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 24,
          right: 24,
          child: _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPoster(Channel movie) {
    return Container(
      width: 220,
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3350), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: movie.logo.isEmpty
            ? _buildFallbackPoster(movie)
            : Image.network(
                movie.logo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackPoster(movie),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFF1A2238),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C8FF),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFallbackPoster(Channel movie) {
    return Container(
      color: const Color(0xFF1A2238),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(movie),
              color: const Color(0xFF00C8FF).withOpacity(0.4),
              size: 70,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                movie.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(Channel movie) {
    if (movie.genre == 'animation') return Icons.animation_rounded;
    if (movie.genre == 'action') return Icons.flash_on_rounded;
    if (movie.genre == 'horror') return Icons.psychology_rounded;
    if (movie.genre == 'comedy') return Icons.sentiment_very_satisfied_rounded;
    return Icons.movie_rounded;
  }

  Widget _buildInfoBadge(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // ==========================================================
  //  أزرار الإجراءات
  // ==========================================================
  Widget _buildActionButtons(Channel movie, bool isFav) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // زر تشغيل كبير
          Expanded(
            flex: 3,
            child: _FocusableButton(
              onPressed: () => _openPlayer(movie),
              icon: Icons.play_arrow_rounded,
              label: 'تشغيل الآن',
            ),
          ),
          const SizedBox(width: 12),

          // مفضلة (حقيقي)
          _ActionButton(
            icon: isFav
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: isFav ? 'في المفضلة' : 'مفضلة',
            color: isFav ? const Color(0xFFFF1744) : Colors.white70,
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggle(movie.id);
            },
          ),
          const SizedBox(width: 12),

          // مشاهدة لاحقاً (تجريبي)
          _ActionButton(
            icon: Icons.bookmark_border_rounded,
            label: 'لاحقاً',
            color: Colors.white70,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم إضافة الميزة قريباً'),
                  backgroundColor: Color(0xFF141A2E),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  فتح المشغل (مع تسجيل في السجل)
  // ==========================================================
  void _openPlayer(Channel movie) {
    // ✅ تسجيل في السجل
    ref.read(historyProvider.notifier).record(movie);

    // فتح المشغل
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: movie.streamUrl,
          channelName: movie.name,
          channelLogo: movie.logo,
        ),
      ),
    );
  }

  // ==========================================================
  //  المعلومات
  // ==========================================================
  Widget _buildInfoSection(Channel movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المعلومات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3350)),
            ),
            child: Column(
              children: [
                _buildInfoRow('الباقة', movie.group),
                if (movie.languageLabel.isNotEmpty)
                  _buildInfoRow('اللغة', movie.languageLabel),
                if (movie.translationLabel.isNotEmpty)
                  _buildInfoRow('الترجمة', movie.translationLabel),
                if (movie.countryLabel.isNotEmpty)
                  _buildInfoRow('الدولة', movie.countryLabel),
                if (movie.genreLabel.isNotEmpty)
                  _buildInfoRow('النوع', movie.genreLabel),
                if (movie.year != null)
                  _buildInfoRow('سنة الإنتاج', '${movie.year}'),
                _buildInfoRow('نوع الملف', movie.isHls ? 'HLS (m3u8)' : 'M3U'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  الشرائح
  // ==========================================================
  Widget _buildMetadataChips(Channel movie) {
    final chips = <Widget>[];

    if (movie.languageLabel.isNotEmpty) {
      chips.add(_buildBigChip(
        Icons.language_rounded,
        movie.languageLabel,
        const Color(0xFF00C8FF),
      ));
    }
    if (movie.translationLabel.isNotEmpty) {
      chips.add(_buildBigChip(
        Icons.translate_rounded,
        movie.translationLabel,
        const Color(0xFF9C27B0),
      ));
    }
    if (movie.countryLabel.isNotEmpty) {
      chips.add(_buildBigChip(
        Icons.flag_rounded,
        movie.countryLabel,
        const Color(0xFF4CAF50),
      ));
    }
    if (movie.genreLabel.isNotEmpty) {
      chips.add(_buildBigChip(
        Icons.category_rounded,
        movie.genreLabel,
        const Color(0xFFFFB800),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Wrap(spacing: 10, runSpacing: 10, children: chips),
    );
  }

  Widget _buildBigChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  معلومات الرابط
  // ==========================================================
  Widget _buildStreamInfo(Channel movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A3350)),
        ),
        child: Row(
          children: [
            Icon(
              movie.isWorking
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              color: movie.isWorking
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF5252),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              movie.isWorking ? 'الرابط نشط' : 'الرابط غير نشط',
              style: TextStyle(
                color: movie.isWorking
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF5252),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              'أولوية: ${movie.priority}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
//  زر كبير للتشغيل
// ==========================================================
class _FocusableButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _FocusableButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onPressed();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C8FF), Color(0xFF0090D4)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.black, size: 28),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  زر إجراء ثانوي
// ==========================================================
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onPressed();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF00C8FF)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.5),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _isFocused ? Colors.black : widget.color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isFocused ? Colors.black : widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  زر دائري للرجوع
// ==========================================================
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onPressed();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF00C8FF)
                : Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.white24,
              width: _isFocused ? 3 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            widget.icon,
            color: _isFocused ? Colors.black : Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
