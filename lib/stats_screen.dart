import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final streak = state.currentStreak;
    final best = state.bestStreak;
    final totalSecs = state.totalFocusedAllTime;
    final sessions = state.totalSessionsAllTime;
    final top = state.topActivities;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'STATS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: 3,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ── Streak banner ───────────────────────────────────────
          _StreakBanner(streak: streak, best: best),
          const SizedBox(height: 14),

          // ── Quick stats ─────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatTile(
                label: 'Total Focus',
                value: _formatHours(totalSecs),
                icon: Icons.timer_outlined,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                label: 'Sessions',
                value: '$sessions',
                icon: Icons.check_circle_outline_rounded,
              )),
            ],
          ),
          const SizedBox(height: 14),



          // ── Mastery ──────────────────────────────────────────────
          _SectionCard(
            title: 'MASTERY',
            child: top.isEmpty
                ? _emptyState('Log sessions to track your mastery journey.')
                : Column(
                    children: top.map((a) {
                      final totalSecs = state.totalSecsForActivity(a.name);
                      final avgSecs = state.avgDailySecsForActivity(a.name);
                      return _MasteryRow(
                        icon: a.icon,
                        name: a.name,
                        totalSecs: totalSecs,
                        avgDailySecs: avgSecs,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatHours(int secs) {
    if (secs == 0) return '0m';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(msg, style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      );
}

// ── Streak Banner ──────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;
  final int best;
  const _StreakBanner({required this.streak, required this.best});

  String get _message {
    if (streak == 0) return 'Start your streak — focus today!';
    if (streak == 1) return 'Great start! Come back tomorrow.';
    if (streak < 5) return 'Building momentum. Keep going!';
    if (streak < 10) return 'You\'re on fire. Don\'t break the chain!';
    if (streak < 30) return 'Incredible consistency. This is a habit!';
    return 'Elite focus. You\'re in rare company.';
  }

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasStreak
              ? [const Color(0xFF2D1B6B), AppTheme.accent.withAlpha(200)]
              : [AppTheme.card, AppTheme.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasStreak ? AppTheme.accent.withAlpha(100) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            hasStreak ? '🔥' : '💤',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStreak ? '$streak Day Streak' : 'No Active Streak',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message,
                  style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180)),
                ),
                if (best > streak && best > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Best: $best days',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accent.withAlpha(200),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11, color: AppTheme.muted,
              fontWeight: FontWeight.w700, letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}


// ── Mastery Row ───────────────────────────────────────────────────────────────

class _MasteryRow extends StatelessWidget {
  final String icon;
  final String name;
  final int totalSecs;
  final int avgDailySecs;

  const _MasteryRow({
    required this.icon,
    required this.name,
    required this.totalSecs,
    required this.avgDailySecs,
  });

  static const _tierColors = [
    Color(0xFF6B8E6B), // Beginner — muted green
    Color(0xFF7B6FD4), // Functional — purple
    Color(0xFFD47B3F), // Comfortable — orange
    Color(0xFFD4AF37), // Proficient — gold
  ];

  @override
  Widget build(BuildContext context) {
    final tiers = AppState.masteryTiers;
    final tier = AppState.masteryFor(totalSecs);
    final tierIndex = tiers.indexWhere((t) => t.label == tier.label);
    final isMax = tierIndex == tiers.length - 1;
    final nextTier = isMax ? null : tiers[tierIndex + 1];
    final tierColor = _tierColors[tierIndex];

    // Progress within current tier
    final tierStart = tier.seconds;
    final tierEnd = nextTier?.seconds ?? tier.seconds;
    final withinTier = isMax ? 1.0 : (totalSecs - tierStart) / (tierEnd - tierStart);

    // ETA to next tier
    String etaLabel = '';
    if (!isMax && nextTier != null) {
      final remaining = nextTier.seconds - totalSecs;
      if (avgDailySecs > 0) {
        final days = (remaining / avgDailySecs).ceil();
        etaLabel = days == 1 ? '~1 day' : '~$days days';
      } else {
        final remainH = remaining / 3600;
        etaLabel = remainH < 1
            ? '${(remaining / 60).round()}m left'
            : '${remainH.toStringAsFixed(remainH < 10 ? 1 : 0)}h left';
      }
    }

    final totalH = totalSecs / 3600;
    final totalLabel = totalH < 1
        ? '${(totalSecs / 60).round()}m'
        : '${totalH.toStringAsFixed(totalH < 10 ? 1 : 0)}h';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 13, inherit: false)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tierColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tier.emoji, style: const TextStyle(fontSize: 10, inherit: false)),
                    const SizedBox(width: 4),
                    Text(
                      tier.label,
                      style: TextStyle(fontSize: 10, color: tierColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tier progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: Colors.white.withAlpha(8)),
                FractionallySizedBox(
                  widthFactor: withinTier.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: tierColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$totalLabel total',
                style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600),
              ),
              if (!isMax && nextTier != null) ...[
                Text('  ·  ', style: TextStyle(fontSize: 11, color: AppTheme.muted.withAlpha(60))),
                Text(
                  etaLabel.isNotEmpty ? '$etaLabel to ${nextTier.label}' : '${_formatH(nextTier.seconds - totalSecs)} to ${nextTier.label}',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ] else ...[
                Text('  ·  ', style: TextStyle(fontSize: 11, color: AppTheme.muted.withAlpha(60))),
                Text(tier.message, style: TextStyle(fontSize: 11, color: tierColor.withAlpha(200))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatH(int secs) {
    final h = secs / 3600;
    return h < 1 ? '${(secs / 60).round()}m' : '${h.toStringAsFixed(h < 10 ? 1 : 0)}h';
  }
}
