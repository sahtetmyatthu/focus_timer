import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final total = state.totalElapsedToday;
    final doneCount = state.timerStates.values.where((s) => s.status == 'done').length;
    final activeCount = state.activities.length;

    final now = DateTime.now();
    final dateLabel = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: const Border.fromBorderSide(BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.today_rounded, color: AppTheme.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Focus",
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(dateLabel,
                          style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      total > 0 ? AppState.formatElapsed(total) : '—',
                      style: GoogleFonts.spaceMono(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.accent),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$doneCount/$activeCount done',
                            style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                        if (state.currentStreak > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🔥 ${state.currentStreak}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress bar for overall
          if (total > 0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activeCount > 0 ? doneCount / activeCount : 0,
                  minHeight: 3,
                  backgroundColor: Colors.white.withAlpha(10),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),

          if (state.activities.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Text('No activities yet.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13)),
            )
          else
            ...state.activities.map((a) => _SummaryRow(
                  activity: a,
                  timerState: state.stateOf(a.id),
                )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _weekday(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final i = d - 1;
    return (i >= 0 && i < days.length) ? days[i] : '';
  }

  static String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final i = m - 1;
    return (i >= 0 && i < months.length) ? months[i] : '';
  }
}

class _SummaryRow extends StatelessWidget {
  final Activity activity;
  final TimerState timerState;
  const _SummaryRow({required this.activity, required this.timerState});

  @override
  Widget build(BuildContext context) {
    final isDone = timerState.status == 'done';
    final isRunning = timerState.status == 'running';
    final elapsed = timerState.elapsed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Row(
        children: [
          Text(activity.icon, style: const TextStyle(fontSize: 16, inherit: false)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.name,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (elapsed / (activity.targetMinutes * 60)).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white.withAlpha(10),
                    valueColor: AlwaysStoppedAnimation(
                      isDone ? AppTheme.success : isRunning ? AppTheme.accent : AppTheme.muted.withAlpha(100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: isDone
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 12),
                      const SizedBox(width: 3),
                      Text('Done', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700)),
                    ])
                  : elapsed > 0
                      ? Text(
                          AppState.formatElapsed(elapsed),
                          style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.white54),
                        )
                      : Text('—', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ),
          ),
        ],
      ),
    );
  }
}
