import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/channel.dart';
import '../../../data/providers/playlist_provider.dart';
import '../../../data/services/sports_service.dart';

/// صندوق مباريات الرياضة — يظهر في قسم "رياضة"
class SportsMatchesWidget extends ConsumerStatefulWidget {
  final ValueChanged<Channel> onChannelTap;

  const SportsMatchesWidget({super.key, required this.onChannelTap});

  @override
  ConsumerState<SportsMatchesWidget> createState() =>
      _SportsMatchesWidgetState();
}

class _SportsMatchesWidgetState extends ConsumerState<SportsMatchesWidget> {
  final SportsService _service = SportsService();
  List<SportMatch> _matches = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final all = await _service.getTodayFootballMatches();
      final filtered = _service.filterImportant(all);

      if (!mounted) return;
      setState(() {
        _matches = filtered;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // إذا لا مباريات ولا تحميل → لا نعرض شيئاً
    if (!_isLoading && _matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final liveMatches = _matches.where((m) => m.isLive).toList();
    final upcomingMatches =
        _matches.where((m) => m.isUpcoming && m.isSoon).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1A2E1A),
            Color(0xFF0F1A0F),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============ العنوان ============
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'مباريات اليوم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                    strokeWidth: 2,
                  ),
                )
              else
                _RefreshButton(onPressed: _loadMatches),
            ],
          ),

          const SizedBox(height: 16),

          // ============ المحتوى ============
          if (_isLoading && _matches.isEmpty)
            _buildLoading()
          else if (_hasError)
            _buildError()
          else if (liveMatches.isEmpty && upcomingMatches.isEmpty)
            _buildNoMatches()
          else ...[
            if (liveMatches.isNotEmpty) ...[
              _buildSectionTitle(
                'الآن على الشاشة',
                Icons.fiber_manual_record,
                const Color(0xFFFF1744),
                pulse: true,
              ),
              const SizedBox(height: 10),
              for (final match in liveMatches) _buildMatchCard(match),
              const SizedBox(height: 16),
            ],
            if (upcomingMatches.isNotEmpty) ...[
              _buildSectionTitle(
                'قريباً',
                Icons.schedule_rounded,
                const Color(0xFFFFB800),
              ),
              const SizedBox(height: 10),
              for (final match in upcomingMatches) _buildMatchCard(match),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color color, {
    bool pulse = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'جارٍ تحميل المباريات...',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFFF5252),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'فشل تحميل المباريات',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const Spacer(),
          TextButton(
            onPressed: _loadMatches,
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatches() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.sports_rounded,
              color: Colors.white24,
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              'لا توجد مباريات مهمة اليوم',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  بطاقة المباراة
  // ==========================================================
  Widget _buildMatchCard(SportMatch match) {
    final channels = _findChannels(match);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.isLive
              ? const Color(0xFFFF1744).withOpacity(0.5)
              : const Color(0xFF4CAF50).withOpacity(0.2),
          width: match.isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============ المباراة ============
          Row(
            children: [
              // الفريق الأول
              Expanded(
                child: Text(
                  match.homeTeam,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // النتيجة / VS
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: match.isLive
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF1A2E1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.scoreText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // الفريق الثاني
              Expanded(
                child: Text(
                  match.awayTeam,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ============ معلومات ============
          Row(
            children: [
              if (match.league.isNotEmpty) ...[
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFB800),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    match.league,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                match.isLive
                    ? Icons.fiber_manual_record
                    : Icons.schedule_rounded,
                color: match.isLive
                    ? const Color(0xFFFF1744)
                    : const Color(0xFF4CAF50),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                match.isLive ? 'مباشر' : '${match.formattedTime} • ${match.timeUntilStart}',
                style: TextStyle(
                  color: match.isLive
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF4CAF50),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // ============ القنوات الناقلة ============
          if (channels.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3350), height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: channels
                  .take(6)
                  .map((ch) => _buildChannelChip(ch))
                  .toList(),
            ),
          ] else if (match.channel != null &&
              match.channel!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3350), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.tv_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'القناة: ${match.channel}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  //  البحث عن القنوات الناقلة في قائمة القنوات
  // ==========================================================
  List<Channel> _findChannels(SportMatch match) {
    final all = ref.read(playlistProvider).allChannels;

    // إذا كان لدى المباراة قناة محددة → ابحث عنها
    final searchTerms = <String>[];

    if (match.channel != null && match.channel!.isNotEmpty) {
      searchTerms.add(match.channel!.toLowerCase());
    }

    // إضافة الفرق للبحث
    searchTerms.add(match.homeTeam.toLowerCase());
    searchTerms.add(match.awayTeam.toLowerCase());

    // إضافة اسم الدوري
    if (match.league.isNotEmpty) {
      searchTerms.add(match.league.toLowerCase());
    }

    final result = <Channel>[];
    final seenIds = <String>{};

    for (final channel in all) {
      if (channel.contentType != 'live') continue;
      if (channel.category != 'sport') continue;

      final name = channel.name.toLowerCase();
      final group = channel.group.toLowerCase();
      final text = '$name $group';

      // مطابقة اسم القناة من API
      if (match.channel != null && match.channel!.isNotEmpty) {
        final apiChannel = match.channel!.toLowerCase();

        // البحث عن beIN Sports مثلاً
        if (apiChannel.contains('bein') && name.contains('bein')) {
          if (seenIds.add(channel.id)) {
            result.add(channel);
            if (result.length >= 6) break;
            continue;
          }
        }
      }

      // مطابقة عامة مع الفرق/الدوري
      for (final term in searchTerms) {
        if (term.length < 3) continue;
        if (text.contains(term)) {
          if (seenIds.add(channel.id)) {
            result.add(channel);
            if (result.length >= 6) break;
          }
          break;
        }
      }
    }

    // إذا لم نجد → اعرض أول 4 قنوات رياضية (beIN/Arabsat)
    if (result.isEmpty) {
      for (final channel in all) {
        if (channel.contentType != 'live') continue;
        if (channel.category != 'sport') continue;

        final name = channel.name.toLowerCase();
        if (name.contains('bein') ||
            name.contains('ssc') ||
            name.contains('ad sport')) {
          if (seenIds.add(channel.id)) {
            result.add(channel);
            if (result.length >= 4) break;
          }
        }
      }
    }

    return result;
  }

  // ==========================================================
  //  شريحة قناة قابلة للتشغيل
  // ==========================================================
  Widget _buildChannelChip(Channel channel) {
    return _ChannelPlayChip(
      channel: channel,
      onTap: () => widget.onChannelTap(channel),
    );
  }
}

// ==========================================================
//  شريحة قناة قابلة للتركيز
// ==========================================================
class _ChannelPlayChip extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _ChannelPlayChip({required this.channel, required this.onTap});

  @override
  State<_ChannelPlayChip> createState() => _ChannelPlayChipState();
}

class _ChannelPlayChipState extends State<_ChannelPlayChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (h) => setState(() => _isFocused = h),
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
          padding: EdgeInsets.symmetric(
            horizontal: _isFocused ? 14 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF4CAF50)
                : const Color(0xFF4CAF50).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : const Color(0xFF4CAF50).withOpacity(0.4),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: _isFocused ? Colors.white : const Color(0xFF4CAF50),
                size: 16,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isFocused ? Colors.white : const Color(0xFF4CAF50),
                    fontSize: 12,
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

// ==========================================================
//  زر التحديث
// ==========================================================
class _RefreshButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _RefreshButton({required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (h) => setState(() => _isFocused = h),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF4CAF50)
                : Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : Colors.white.withOpacity(0.2),
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Icon(
            Icons.refresh_rounded,
            color: _isFocused ? Colors.white : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }
}
