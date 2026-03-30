import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class ActivityCard extends StatefulWidget {
  final Activity activity;
  final bool isManageMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReset;

  const ActivityCard({
    super.key,
    required this.activity,
    this.isManageMode = false,
    this.onEdit,
    this.onDelete,
    this.onReset,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.stateOf(widget.activity.id);
    final progress = state.getProgress(widget.activity.id);
    final isRunning = s.status == 'running';
    final isDone = s.status == 'done';
    final isPaused = s.status == 'paused';

    final borderColor = isDone
        ? AppTheme.success.withAlpha(120)
        : isRunning
            ? AppTheme.accent.withAlpha(200)
            : isPaused
                ? AppTheme.accent.withAlpha(60)
                : AppTheme.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.card.withAlpha(220)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isRunning || isDone ? 1.5 : 1),
        boxShadow: [
          if (isRunning)
            BoxShadow(color: AppTheme.accent.withAlpha(50), blurRadius: 24, offset: const Offset(0, 6)),
          if (isDone)
            BoxShadow(color: AppTheme.success.withAlpha(30), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopSection(s, isRunning, isDone, isPaused, state, progress),
          const SizedBox(height: 14),
          _buildBottom(s, isRunning, isDone, state),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopSection(TimerState s, bool isRunning, bool isDone, bool isPaused, AppState state, double progress) {
    final highlight = widget.isManageMode ? (type: null as String?, daysSince: 0)
        : state.activityHighlight(widget.activity.name);
    
    final totalSecs = state.totalSecsForActivity(widget.activity.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. HEADER ROW: Icon, Name, Highlight Badge, Live Timer ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(isRunning, isDone, totalSecs),
              const SizedBox(width: 14),
              // Name & Plan Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Highlight Badge
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Tooltip(
                            message: widget.activity.name,
                            child: Text(
                              widget.activity.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          if (highlight.type != null)
                            _HighlightBadge(type: highlight.type!, daysSince: highlight.daysSince),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // ── 2. PLAN ROW: Target, Pomodoro, Paused ──
                      _buildTargetStatusInfo(s, state, isPaused),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Live Timer
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDone ? AppTheme.success : isRunning ? AppTheme.accent : Colors.white.withAlpha(220),
                ),
                child: Text(
                  AppState.formatTime(s.elapsed),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
          
          // ── 3. PROGRESS ROW: Bar + % ──
          if (s.elapsed > 0 || isRunning) ...[
            const SizedBox(height: 14),
            _buildProgressBar(progress, isDone, isRunning),
          ] else ...[
            const SizedBox(height: 4),
          ],
          
          // ── 4. STATS ROW: Mastery Badge, Total Time, Time to Next ──
          if (totalSecs > 0) ...[
            const SizedBox(height: 14),
            _buildMasteryInfo(state, totalSecs),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(bool isRunning, bool isDone, int totalSecs) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showMasterySheet(context, totalSecs);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: isDone
              ? AppTheme.success.withAlpha(25)
              : isRunning
                  ? AppTheme.accent.withAlpha(35)
                  : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? AppTheme.success.withAlpha(80)
                : isRunning
                    ? AppTheme.accent.withAlpha(80)
                    : Colors.white.withAlpha(12),
          ),
        ),
        child: Center(
          child: Text(widget.activity.icon, style: const TextStyle(fontSize: 22, inherit: false)),
        ),
      ),
    );
  }

  Widget _buildTargetStatusInfo(TimerState s, AppState state, bool isPaused) {
    // "Wrap" guarantees elements move to the next line safely if cramped!
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (isPaused && s.elapsed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent2.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('PAUSED', style: TextStyle(fontSize: 9, color: AppTheme.accent2, fontWeight: FontWeight.w800)),
          ),
        
        Text(
          'Target: ${AppState.formatMins(widget.activity.targetMinutes)}',
          style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w500),
        ),

        if (state.isPomodoroMode)
          Text(
            (s.pomodoroCount > 0) 
                ? '•  🍅 ${s.pomodoroCount} session${s.pomodoroCount > 1 ? 's' : ''}'
                : '•  🍅 ${state.pomodoroDurationMinutes}m sessions',
            style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  Widget _buildProgressBar(double progress, bool isDone, bool isRunning) {
    final pct = (progress * 100).round();
    final barColor = isDone ? AppTheme.success : isRunning ? AppTheme.accent : AppTheme.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Percentage text floating right above the bar
        Text(
          '$pct%',
          style: TextStyle(fontSize: 10, color: barColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context2, v, child2) => LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: Colors.white.withAlpha(10),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMasteryInfo(AppState state, int totalSecs) {
    final mastery = AppState.masteryFor(totalSecs);
    final tiers = AppState.masteryTiers;
    final tierIndex = tiers.indexWhere((t) => t.label == mastery.label);
    final isMax = tierIndex == tiers.length - 1;
    final nextTier = isMax ? null : tiers[tierIndex + 1];

    final totalH = totalSecs / 3600;
    final totalLabel = totalH < 1
        ? '${(totalSecs / 60).round()}m'
        : '${totalH.toStringAsFixed(totalH < 10 ? 1 : 0)}h';

    String? toNext;
    if (nextTier != null) {
      final remaining = nextTier.seconds - totalSecs;
      final remainH = remaining / 3600;
      toNext = remainH < 1
          ? '${(remaining / 60).round()}m'
          : '${remainH.toStringAsFixed(remainH < 10 ? 1 : 0)}h';
      toNext += ' to ${nextTier.label}';
    }

    // A subtle dark tinted box to house the stats neatly
    return Container(
      width: double.infinity, // stretch to look like a clean divider section
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(8)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          // Mastery Badge
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showMasterySheet(context, totalSecs);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mastery.emoji, style: const TextStyle(fontSize: 10, inherit: false)),
                  const SizedBox(width: 4),
                  Text(mastery.label, style: TextStyle(fontSize: 10, color: AppTheme.muted, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          
          // Total Logged Time
          Text(
            totalLabel,
            style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          
          // Next Tier Requirement
          if (toNext != null) ...[
            Text('•', style: TextStyle(fontSize: 10, color: AppTheme.muted.withAlpha(80))),
            Text(
              toNext,
              style: TextStyle(fontSize: 11, color: AppTheme.muted.withAlpha(140)),
            ),
          ],
        ],
      ),
    );
  }

  void _showMasterySheet(BuildContext context, int totalSecs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MasterySheet(
        activityName: widget.activity.name,
        totalSecs: totalSecs,
      ),
    );
  }

  Widget _buildBottom(TimerState s, bool isRunning, bool isDone, AppState state) {
    final id = widget.activity.id;

    if (widget.isManageMode) {
      final hasProgress = s.elapsed > 0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _outlineBtn(label: 'Edit', icon: Icons.edit_outlined, onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onEdit?.call();
                }, color: Colors.white70)),
                const SizedBox(width: 10),
                Expanded(child: _outlineBtn(label: 'Delete', icon: Icons.delete_outline_rounded, onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onDelete?.call();
                }, color: AppTheme.danger, borderColor: AppTheme.danger.withAlpha(60))),
              ],
            ),
            if (hasProgress) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onReset?.call();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.muted.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, size: 13, color: AppTheme.muted),
                      const SizedBox(width: 6),
                      Text('Reset Progress',
                          style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isDone) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.success.withAlpha(60)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    Text('COMPLETED', style: TextStyle(
                      color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _squareBtn(
              icon: Icons.add_rounded,
              color: AppTheme.success,
              borderColor: AppTheme.success.withAlpha(60),
              onTap: () {
                HapticFeedback.mediumImpact();
                state.resetTimer(id);
                state.startTimer(id);
              },
            ),
          ],
        ),
      );
    }

    if (isRunning) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _outlineBtn(label: 'Pause', icon: Icons.pause_rounded, onTap: () {
              HapticFeedback.lightImpact();
              state.pauseTimer(id);
            }, color: AppTheme.accent, borderColor: AppTheme.accent.withAlpha(80))),
            const SizedBox(width: 10),
            _squareBtn(icon: Icons.stop_rounded, onTap: () {
              HapticFeedback.mediumImpact();
              state.finishTimer(id);
            }, color: AppTheme.success, borderColor: AppTheme.success.withAlpha(60)),
          ],
        ),
      );
    }

    // idle / paused
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _filledBtn(
            label: s.status == 'paused' ? 'Resume' : 'Start',
            icon: Icons.play_arrow_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              state.startTimer(id);
            },
          )),
        ],
      ),
    );
  }

  Widget _filledBtn({required String label, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppTheme.accent.withAlpha(70), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    Color? borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? color.withAlpha(60)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _squareBtn({required IconData icon, required VoidCallback onTap, required Color color, Color? borderColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 50, height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? AppTheme.border),
            color: color.withAlpha(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Mastery Sheet ─────────────────────────────────────────────────────────────

class _MasterySheet extends StatelessWidget {
  final String activityName;
  final int totalSecs;
  const _MasterySheet({required this.activityName, required this.totalSecs});

  static const _tierColors = [
    Color(0xFF6B8E6B),
    Color(0xFF7B6FD4),
    Color(0xFFD47B3F),
    Color(0xFFD4AF37),
  ];

  static const _tierRanges = ['0 – 20h', '20 – 100h', '100 – 1,000h', '1,000h+'];

  static const _tierMessages = [
    'The hardest phase. Most people quit here.\nPush through — it gets easier.',
    'You can handle the basics. Real confidence\nstarts building from here.',
    'Deep fluency. You solve problems others\ncan\'t even see yet.',
    'Elite level. You\'ve put in more than most\npeople ever will.',
  ];

  @override
  Widget build(BuildContext context) {
    final tiers = AppState.masteryTiers;
    final current = AppState.masteryFor(totalSecs);
    final currentIndex = tiers.indexWhere((t) => t.label == current.label);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '🏆  Mastery Levels',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            activityName,
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          ...List.generate(tiers.length, (i) {
            final tier = tiers[i];
            final isCurrentTier = i == currentIndex;
            final isPast = i < currentIndex;
            final color = _tierColors[i];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrentTier ? color.withAlpha(25) : Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentTier ? color.withAlpha(100) : Colors.white.withAlpha(12),
                    width: isCurrentTier ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tier.emoji, style: const TextStyle(fontSize: 22, inherit: false)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrentTier ? color : isPast ? Colors.white54 : Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _tierRanges[i],
                                style: TextStyle(fontSize: 11, color: AppTheme.muted),
                              ),
                              if (isCurrentTier) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('YOU',
                                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tierMessages[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrentTier ? Colors.white.withAlpha(180) : AppTheme.muted.withAlpha(140),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPast)
                      Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      ),
    );
  }
}

// ── Highlight Badge ───────────────────────────────────────────────────────────

class _HighlightBadge extends StatelessWidget {
  final String type;
  final int daysSince;
  const _HighlightBadge({required this.type, required this.daysSince});

  @override
  Widget build(BuildContext context) {
    final (String emoji, String label, Color color) = switch (type) {
      'neverStarted' => ('💤', 'Not started', const Color(0xFF8888AA)),
      'neglected'    => ('🔴', daysSince == 1 ? 'Yesterday' : '${daysSince}d ago', const Color(0xFFE05C5C)),
      'atRisk'       => ('⚠️', 'Focus me', const Color(0xFFD4A03F)),
      'onARoll'      => ('✨', '7-day streak', const Color(0xFF5CB87A)),
      _              => ('', '', Colors.transparent),
    };

    if (emoji.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 8, inherit: false)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
