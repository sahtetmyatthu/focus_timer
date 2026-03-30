import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'history_screen.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'widgets/activity_card.dart';
import 'widgets/add_activity_sheet.dart';
import 'widgets/summary_section.dart';

const _ringtoneChannel = MethodChannel('momentum/ringtone');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isManageMode = false;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.onTimerDone = (_) {
        HapticFeedback.heavyImpact();
        _playAlarm(looping: false);
        Future.delayed(const Duration(seconds: 5), () => FlutterRingtonePlayer().stop());
        _confetti.play();
        _showSnack('🎉 Target reached! Great work!', color: AppTheme.success);
      };
      state.onSessionLogged = null;
      state.onPomodoroBreak = (name, count) {
        HapticFeedback.heavyImpact();
        _playAlarm(looping: true);
        _showPomodoroBreakDialog(name, count);
      };
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      FlutterRingtonePlayer().stop();
      final appState = context.read<AppState>();
      final runningId = appState.runningId;
      if (runningId != null) appState.pauseTimer(runningId);
    }
    if (lifecycle == AppLifecycleState.resumed) {
      // If the user left the app overnight, reset activities for the new day
      context.read<AppState>().checkAndResetIfNewDay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    final state = context.read<AppState>();
    state.onTimerDone = null;
    state.onPomodoroBreak = null;
    super.dispose();
  }

  void _playAlarm({bool looping = false}) {
    final uri = context.read<AppState>().alarmSoundUri;
    if (uri != null) {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        fromFile: uri,
        looping: looping,
        volume: 1.0,
        asAlarm: true,
      );
    } else {
      FlutterRingtonePlayer().playAlarm(looping: looping, volume: 1.0);
    }
  }

  void _showPomodoroBreakDialog(String activityName, int count) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PomodoroBreakDialog(activityName: activityName, count: count),
    );
  }

  void _showSnack(String message, {Color color = AppTheme.accent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddSheet([Activity? activity]) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => AddActivitySheet(activity: activity),
    );
  }

  void _confirmDelete(Activity a) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete "${a.name}"?',
        body: 'This activity and its timer will be removed.',
        confirmLabel: 'Delete',
        confirmColor: AppTheme.danger,
        onConfirm: () => context.read<AppState>().deleteActivity(a.id),
      ),
    );
  }

  void _confirmResetAll() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Reset All Timers?',
        body: 'All timers will be cleared. History will be kept.',
        confirmLabel: 'Reset',
        confirmColor: AppTheme.danger,
        onConfirm: () => context.read<AppState>().resetAll(),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear All Data?',
        body: 'All activities, timers, and history will be permanently deleted. This cannot be undone.',
        confirmLabel: 'Clear Everything',
        confirmColor: AppTheme.danger,
        onConfirm: () {
          context.read<AppState>().clearAllData();
          setState(() => _isManageMode = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.bgGradient),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _buildHeader(state),
                    _buildToolbar(state),
                    Expanded(
                      child: Selector<AppState, String>(
                        selector: (_, s) => s.activities.isEmpty
                            ? ''
                            : s.activities
                                .map((a) => '${a.id}|${a.name}|${a.icon}|${a.targetMinutes}')
                                .join(','),
                        builder: (ctx, key, _) {
                          final s = ctx.read<AppState>();
                          return key.isEmpty ? _emptyState() : _buildList(s, _isManageMode);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 50,
              gravity: 0.25,
              colors: const [
                AppTheme.accent, AppTheme.accent2,
                AppTheme.success, AppTheme.danger, Colors.white,
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: AnimatedScale(
        scale: (_isManageMode || state.activities.isEmpty) ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(),
          backgroundColor: AppTheme.accent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Activity',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildHeader(AppState state) {
    final totalSecs = state.totalElapsedToday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: totalSecs > 0 ? AppTheme.success : AppTheme.muted.withAlpha(100),
                      ),
                    ),
                    Text(
                      'MOMENTUM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppState.formatTime(totalSecs),
                  style: GoogleFonts.spaceMono(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: totalSecs > 0 ? Colors.white : Colors.white.withAlpha(80),
                  ),
                ),
              ],
            ),
          ),
          // Reset + History buttons
          Row(
            children: [
              _headerBtn(
                icon: Icons.replay_rounded,
                onTap: _confirmResetAll,
                color: totalSecs > 0 ? AppTheme.danger.withAlpha(180) : null,
              ),
              const SizedBox(width: 8),
              _headerBtn(
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
              ),
              const SizedBox(width: 8),
              _headerBtn(
                icon: Icons.history_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBtn({required IconData icon, required VoidCallback onTap, Color? color}) {
    final iconColor = color ?? Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color != null ? color.withAlpha(20) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(BorderSide(
            color: color != null ? color.withAlpha(60) : AppTheme.border,
          )),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildToolbar(AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: const Border.fromBorderSide(BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            _toolBtn(
              label: _isManageMode ? 'DONE' : 'MANAGE',
              icon: _isManageMode ? Icons.check_rounded : Icons.tune_rounded,
              active: _isManageMode,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isManageMode = !_isManageMode);
              },
            ),
            _toolBtn(
              label: state.isPomodoroMode
                  ? '🍅 ${state.pomodoroDurationMinutes}m'
                  : 'POMODORO',
              emoji: state.isPomodoroMode ? null : '🍅',
              active: state.isPomodoroMode,
              onTap: () {
                HapticFeedback.selectionClick();
                state.togglePomodoro();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showPomodoroSettings(state);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPomodoroSettings(AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _PomodoroSettingsSheet(state: state),
    );
  }

  Widget _toolBtn({
    required String label,
    IconData? icon,
    String? emoji,
    bool active = false,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: active ? Colors.white : AppTheme.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: active ? Colors.white : AppTheme.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(AppState state, [bool isManageMode = false]) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          sliver: SliverReorderableList(
            itemCount: state.activities.length,
            onReorder: (oldIndex, newIndex) {
              HapticFeedback.mediumImpact();
              state.reorderActivities(oldIndex, newIndex);
            },
            proxyDecorator: (child, _, animation) => AnimatedBuilder(
              animation: animation,
              builder: (_, child) {
                final t = Curves.easeOut.transform(animation.value);
                return Transform.scale(
                  scale: 1.0 + 0.04 * t,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 24 * t,
                    shadowColor: AppTheme.accent.withValues(alpha: 0.5 * t),
                    borderRadius: BorderRadius.circular(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.6 * t),
                          width: 1.5,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            ),
            itemBuilder: (context, index) {
              final a = state.activities[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(a.id),
                index: index,
                enabled: !_isManageMode,
                child: ActivityCard(
                  activity: a,
                  isManageMode: _isManageMode,
                  onEdit: () => _showAddSheet(a),
                  onDelete: () => _confirmDelete(a),
                  onReset: () => context.read<AppState>().resetTimer(a.id),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SummarySection()),
        if (isManageMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: _confirmClearAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.danger.withAlpha(60)),
                    color: AppTheme.danger.withAlpha(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 16, color: AppTheme.danger.withAlpha(180)),
                      const SizedBox(width: 8),
                      Text(
                        'Clear All Data',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger.withAlpha(180),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji with glow background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withAlpha(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withAlpha(40),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🎯', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Activities Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first focus activity\nto start tracking your time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: () => _showAddSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withAlpha(70),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add First Activity',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pomodoro Settings ────────────────────────────────────────────────────────

class _PomodoroSettingsSheet extends StatefulWidget {
  final AppState state;
  const _PomodoroSettingsSheet({required this.state});

  @override
  State<_PomodoroSettingsSheet> createState() => _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState extends State<_PomodoroSettingsSheet> {
  late int _selectedMins;
  bool _pickingSound = false;

  static const _presets = [5, 10, 15, 20, 25, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _selectedMins = widget.state.pomodoroDurationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              const Text('🍅', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Pomodoro Duration',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Timer pauses automatically after each session.',
            style: TextStyle(fontSize: 13, color: AppTheme.muted),
          ),
          const SizedBox(height: 24),

          // Current value display with +/- stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepBtn(Icons.remove_rounded, () {
                if (_selectedMins > 1) setState(() => _selectedMins--);
              }),
              const SizedBox(width: 20),
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Text(
                      '$_selectedMins',
                      style: GoogleFonts.spaceMono(
                          fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    Text('minutes', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _stepBtn(Icons.add_rounded, () {
                if (_selectedMins < 120) setState(() => _selectedMins++);
              }),
            ],
          ),
          const SizedBox(height: 20),

          // Quick presets
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _presets.map((p) {
              final selected = _selectedMins == p;
              return GestureDetector(
                onTap: () => setState(() => _selectedMins = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent.withAlpha(40) : Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Text(
                    '${p}m',
                    style: TextStyle(
                      color: selected ? AppTheme.accent : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Alarm Sound Picker ──────────────────────────────────────
          Text('ALARM SOUND', style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickingSound ? null : () async {
              setState(() => _pickingSound = true);
              try {
                final uri = await _ringtoneChannel.invokeMethod<String>(
                  'pickRingtone',
                  {'currentUri': widget.state.alarmSoundUri},
                );
                if (uri != null) widget.state.setAlarmSoundUri(uri);
              } catch (_) {}
              if (mounted) setState(() => _pickingSound = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.state.alarmSoundUri == null ? 'Default Alarm' : 'Custom Sound (tap to change)',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  if (_pickingSound)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                  else
                    Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
                ],
              ),
            ),
          ),
          if (widget.state.alarmSoundUri != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => widget.state.setAlarmSoundUri(null),
              child: Text('Reset to default', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                widget.state.setPomodoroMins(_selectedMins);
                if (!widget.state.isPomodoroMode) widget.state.togglePomodoro();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                widget.state.isPomodoroMode
                    ? 'Save ${_selectedMins}m'
                    : 'Set ${_selectedMins}m & Enable',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: const Border.fromBorderSide(BorderSide(color: AppTheme.border)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

// ─── Reusable Dialogs ─────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(body, style: TextStyle(color: AppTheme.muted, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ─── Pomodoro Break Dialog ────────────────────────────────────────────────────

class _PomodoroBreakDialog extends StatelessWidget {
  final String activityName;
  final int count;

  const _PomodoroBreakDialog({required this.activityName, required this.count});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍅', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            'Pomodoro #$count Done!',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activityName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent2.withValues(alpha: 0.3)),
            ),
            child: Text(
              count % 4 == 0
                  ? 'Time for a long break! (15–30 min)'
                  : 'Take a short break — 5 minutes',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.accent2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                FlutterRingtonePlayer().stop();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Start Break',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

