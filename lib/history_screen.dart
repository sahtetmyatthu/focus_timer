import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history.reversed.toList();

    // Group by date
    final grouped = <String, List<HistoryEntry>>{};
    for (final e in history) {
      grouped.putIfAbsent(e.date, () => []).add(e);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Session Log',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        actions: [
          if (history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withAlpha(60)),
                  ),
                  child: Text('${history.length}',
                      style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger, size: 22),
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context),
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: history.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: dates.length,
                  itemBuilder: (_, i) {
                    final date = dates[i];
                    final entries = grouped[date]!;
                    final totalSecs = entries.fold(0, (s, e) => s + e.duration);
                    return _DateGroup(
                      date: date,
                      entries: entries,
                      totalSecs: totalSecs,
                      isToday: i == 0,
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear All Sessions?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('All session history will be permanently deleted.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().clearAllHistory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📭', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('No Sessions Yet',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Complete a focus session\nto see it logged here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  final String date;
  final List<HistoryEntry> entries;
  final int totalSecs;
  final bool isToday;

  const _DateGroup({
    required this.date,
    required this.entries,
    required this.totalSecs,
    required this.isToday,
  });

  String _friendlyDate(String date) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yest = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (date == today) return 'Today';
    if (date == yest) return 'Yesterday';
    // Parse date string
    final parts = date.split('-');
    if (parts.length == 3) {
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final m = int.tryParse(parts[1]);
      if (m != null && m >= 1 && m <= 12) return '${months[m-1]} ${parts[2]}';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Text(
                _friendlyDate(date),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: isToday ? AppTheme.accent : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: AppTheme.border, height: 1)),
              const SizedBox(width: 8),
              Text(
                AppState.formatElapsed(totalSecs),
                style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Entry cards
        ...entries.map((e) => _DismissibleHistoryCard(entry: e)),
      ],
    );
  }
}

class _DismissibleHistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  const _DismissibleHistoryCard({required this.entry});

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Session?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this session log?',
            style: TextStyle(color: AppTheme.muted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.timestamp),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (_) => context.read<AppState>().deleteHistoryEntry(entry),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.danger.withAlpha(180),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      child: _HistoryCard(entry: entry),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final HistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(widget.entry.timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$min';
    final hasNote = widget.entry.note.isNotEmpty;

    return GestureDetector(
      onTap: hasNote ? () => setState(() => _expanded = !_expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded ? AppTheme.accent.withAlpha(80) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppTheme.accent.withAlpha(35)),
                  ),
                  child: Center(child: Text(widget.entry.icon, style: const TextStyle(fontSize: 20, inherit: false))),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.entry.name,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      if (hasNote && !_expanded)
                        Text(widget.entry.note,
                            style: TextStyle(fontSize: 12, color: AppTheme.muted),
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                      else
                        Text(timeStr, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppState.formatElapsed(widget.entry.duration),
                      style: GoogleFonts.spaceMono(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accent),
                    ),
                    if (hasNote)
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16, color: AppTheme.muted,
                      ),
                  ],
                ),
              ],
            ),

            // Expanded note
            if (_expanded && hasNote) ...[
              const SizedBox(height: 12),
              Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: AppTheme.accent.withAlpha(150)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.entry.note,
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
