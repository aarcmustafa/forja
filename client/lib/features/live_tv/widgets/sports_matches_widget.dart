import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/channel.dart';
import '../../../data/providers/playlist_provider.dart';
import '../../../data/services/sports_service.dart';
import '../../../data/services/notification_service.dart';

/// صندوق مباريات الرياضة
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

  Future<void> _loadMatches({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final all = await _service.getTodayFootballMatches(
        forceRefresh: force,
      );
      if (!mounted) return;

      if (all.isEmpty) {
        setState(() {
          _matches = [];
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      final filtered = _service.filterImportant(all);
      setState(() {
        _matches = filtered;
        _isLoading = false;
      });

      try {
        final notif = NotificationService();
        if (notif.isEnabled) {
          await notif.scheduleMatches(filtered);
        }
      } catch (_) {}
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
    final liveMatches = _matches.where((m) => m.isLive).toList();
    final upcomingToday = _matches
        .where((m) => m.isUpcoming && m.isToday)
        .toList();
    final upcomingTomorrow = _matches
        .where((m) => m.isUpcoming && m.isTomorrow)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1A2E1A), Color(0xFF0F1A0F)],
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
                'مباريات اليوم والغد',
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
                _RefreshButton(onPressed: () => _loadMatches(force: true)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading && _matches.isEmpty)
            _buildLoading()
          else if (_hasError)
            _buildError()
          else if (liveMatches.isEmpty &&
              upcomingToday.isEmpty &&
              upcomingTomorrow.isEmpty)
            _buildNoMatches()
          else ...[
            if (liveMatches.isNotEmpty) ...[
              _buildSectionTitle(
                'الآن على الشاشة',
                Icons.fiber_manual_record,
                const Color(0xFFFF1744),
              ),
              const SizedBox(height: 10),
              for (final m in liveMatches) _buildMatchCard(m),
              const SizedBox(height: 16),
            ],
            if (upcomingToday.isNotEmpty) ...[
              _buildSectionTitle(
                'اليوم',
                Icons.schedule_rounded,
                const Color(0xFFFFB800),
              ),
              const SizedBox(height: 10),
              for (final m in upcomingToday) _buildMatchCard(m),
              const SizedBox(height: 16),
            ],
            if (upcomingTomorrow.isNotEmpty) ...[
              _buildSectionTitle(
                'غدًا',
                Icons.event_rounded,
                const Color(0xFF00C8FF),
              ),
              const SizedBox(height: 10),
              for (final m in upcomingTomorrow) _buildMatchCard(m),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
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
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: Color(0xFF4CAF50),
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFFF5252), size: 20),
          const SizedBox(width: 10),
          const Text(
            'فشل تحميل المباريات',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _loadMatches(force: true),
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
            Icon(Icons.sports_rounded, color: Colors.white24, size: 40),
            SizedBox(height: 8),
            Text(
              'لا توجد مباريات اليوم أو غدًا',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
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
          Row(
            children: [
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
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
          Row(
            children: [
              if (match.league.isNotEmpty) ...[
                const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFFFB800), size: 14),
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
                match.isLive
                    ? 'مباشر'
                    : '${match.formattedTime} • ${match.timeUntilStart}',
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
          if (channels.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3350), height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: channels
                  .take(8)
                  .map((ch) => _buildChannelChip(ch))
                  .toList(),
            ),
          ] else if (match.channel != null && match.channel!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3350), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.tv_rounded,
                    color: Colors.white38, size: 14),
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
  //  ✅ إيجاد القنوات الناقلة
  //  كل beIN + ألوان (بدون شرط AR)
  // ==========================================================
  List<Channel> _findChannels(SportMatch match) {
    final all = ref.read(playlistProvider).filteredChannels;
    if (all.isEmpty) return [];

    // 1) اجمع القنوات المسموحة
    final allowed = <Channel>[];
    for (final c in all) {
      final name = c.name.toLowerCase();
      final group = c.group.toLowerCase();
      final text = '$name $group';

      if (_isAllowedMatchChannel(text, name)) {
        allowed.add(c);
      }
    }

    if (allowed.isEmpty) return [];

    // 2) ترتيب حسب صلة المباراة
    final result = <Channel>[];

    // أولاً: إذا API ذكر قناة معينة
    if (match.channel != null && match.channel!.isNotEmpty) {
      final apiChannel = match.channel!.toLowerCase();

      if (apiChannel.contains('bein')) {
        for (final c in allowed) {
          if (c.name.toLowerCase().contains('bein') ||
              c.name.toLowerCase().contains('بين')) {
            result.add(c);
            if (result.length >= 10) break;
          }
        }
      } else if (apiChannel.contains('alwan') ||
          apiChannel.contains('ألوان') ||
          apiChannel.contains('الوان')) {
        for (final c in allowed) {
          if (c.name.toLowerCase().contains('alwan') ||
              c.name.toLowerCase().contains('ألوان') ||
              c.name.toLowerCase().contains('الوان')) {
            result.add(c);
            if (result.length >= 6) break;
          }
        }
      }
    }

    // ثانيًا: إذا لم نضف شيئًا، أضف أول 8
    if (result.isEmpty) {
      result.addAll(allowed.take(8));
    }

    return result;
  }

  /// ✅ فحص: هل هذه قناة مسموحة لعرض المباريات؟
  /// الحل A: كل beIN مسموح (بدون شرط AR)
  bool _isAllowedMatchChannel(String text, String name) {
    // ✅ كل beIN (بأي صيغة)
    if (text.contains('bein') || text.contains('بين')) {
      return true;
    }

    // ✅ ألوان سبور
    if (text.contains('alwan') ||
        text.contains('ألوان') ||
        text.contains('الوان')) {
      return true;
    }

    return false;
  }

  Widget _buildChannelChip(Channel channel) {
    return _ChannelPlayChip(
      channel: channel,
      onTap: () => widget.onChannelTap(channel),
    );
  }
}

// ==========================================================
//  شريحة قناة
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
                    color: _isFocused
                        ? Colors.white
                        : const Color(0xFF4CAF50),
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
