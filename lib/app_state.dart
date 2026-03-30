import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class Activity {
  String id;
  String icon;
  String name;
  int targetMinutes;

  Activity({required this.id, required this.icon, required this.name, required this.targetMinutes});

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'],
        icon: j['icon'],
        name: j['name'],
        targetMinutes: j['target'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'icon': icon, 'name': name, 'target': targetMinutes};
}

class TimerState {
  int elapsed;
  String status; // idle | running | paused | done
  int pomodoroCount;
  bool partialLogged;

  TimerState({this.elapsed = 0, this.status = 'idle', this.pomodoroCount = 0, this.partialLogged = false});

  factory TimerState.fromJson(Map<String, dynamic> j) => TimerState(
        elapsed: (j['elapsed'] as num?)?.toInt() ?? 0,
        status: j['status'] ?? 'idle',
        pomodoroCount: (j['pomodoroCount'] as num?)?.toInt() ?? 0,
        partialLogged: j['partialLogged'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'elapsed': elapsed,
        'status': status,
        'pomodoroCount': pomodoroCount,
        'partialLogged': partialLogged,
      };
}

class HistoryEntry {
  final String date;
  final String name;
  final String icon;
  final int duration;
  final int timestamp;
  String note;

  HistoryEntry({
    required this.date,
    required this.name,
    required this.icon,
    required this.duration,
    required this.timestamp,
    this.note = '',
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        date: j['date'],
        name: j['name'],
        icon: j['icon'] ?? '⏱',
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        timestamp: (j['timestamp'] as num?)?.toInt() ?? 0,
        note: j['note'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'name': name,
        'icon': icon,
        'duration': duration,
        'timestamp': timestamp,
        'note': note,
      };
}

// ─── Stats cache ──────────────────────────────────────────────────────────────
// Computed once per history change + once per day. Avoids re-iterating 1000
// history entries every second while a timer is ticking.

class _StatsSnapshot {
  final String date; // date this was computed — auto-stales at midnight
  final int currentStreak;
  final int bestStreak;
  final int totalFocusedAllTime;
  final int totalSessionsAllTime;
  final List<({String label, int seconds, bool isToday})> last7DaysFocus;
  final List<({String icon, String name, int seconds})> topActivities;

  _StatsSnapshot({
    required this.date,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalFocusedAllTime,
    required this.totalSessionsAllTime,
    required this.last7DaysFocus,
    required this.topActivities,
  });
}

// ─── AppState ─────────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  List<Activity> activities = [];
  Map<String, TimerState> timerStates = {};
  List<HistoryEntry> history = [];
  bool isPomodoroMode = false;
  int pomodoroDurationMinutes = 25;
  String? alarmSoundUri;

  Timer? _ticker;
  String? _runningId;
  _StatsSnapshot? _statsCache;

  String? get runningId => _runningId;

  // UI Callbacks — these live here as a pragmatic Flutter pattern.
  // HomeScreen sets them in initState and clears in dispose so they never
  // outlive the widget. Avoid triggering them from background isolates.
  void Function(String id)? onTimerDone;
  void Function(HistoryEntry entry)? onSessionLogged;
  void Function(String activityName, int pomodoroCount)? onPomodoroBreak;

  static final _uuid = Uuid();

  // ── Persistence ─────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final actRaw = prefs.getString('ft_activities');
      if (actRaw != null) {
        activities = (jsonDecode(actRaw) as List).map((j) => Activity.fromJson(j)).toList();
      } else {
        activities = [];
      }
    } catch (_) {
      activities = [];
    }

    try {
      final stateRaw = prefs.getString('ft_state');
      if (stateRaw != null) {
        final m = jsonDecode(stateRaw) as Map<String, dynamic>;
        timerStates = m.map((k, v) => MapEntry(k, TimerState.fromJson(v)));
      }
    } catch (_) {
      timerStates = {};
    }
    // Any timer saved as 'running' means the app was killed mid-session.
    // The Timer.periodic is gone — mark it paused so the UI doesn't show
    // a frozen "running" timer.
    for (final ts in timerStates.values) {
      if (ts.status == 'running') ts.status = 'paused';
    }
    for (final a in activities) {
      timerStates.putIfAbsent(a.id, () => TimerState());
    }

    isPomodoroMode = prefs.getBool('ft_pomodoro_on') ?? false;
    pomodoroDurationMinutes = prefs.getInt('ft_pomodoro_mins') ?? 25;
    alarmSoundUri = prefs.getString('ft_alarm_uri');

    // Auto-reset timer states if this is a new day
    final lastDate = prefs.getString('ft_last_date');
    final today = _dateStr(DateTime.now());
    if (lastDate != null && lastDate != today) {
      for (final a in activities) {
        if (timerStates[a.id]?.status == 'done') {
          timerStates[a.id] = TimerState();
        }
      }
      _saveState();
    }
    prefs.setString('ft_last_date', today);

    try {
      final histRaw = prefs.getString('ft_history');
      if (histRaw != null) {
        history = (jsonDecode(histRaw) as List).map((j) => HistoryEntry.fromJson(j)).toList();
      }
    } catch (_) {
      history = [];
    }

    notifyListeners();
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ft_activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ft_state', jsonEncode(timerStates.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ft_history', jsonEncode(history.map((h) => h.toJson()).toList()));
  }

  // ── Day reset ────────────────────────────────────────────────────
  // Called on app resume so a timer left running overnight is reset on the
  // next day without needing a full app restart.
  Future<void> checkAndResetIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('ft_last_date');
    final today = _dateStr(DateTime.now());
    if (lastDate != null && lastDate != today) {
      if (_runningId != null) {
        final s = timerStates[_runningId!];
        if (s != null && s.status == 'running') {
          s.status = 'paused';
        }
        _ticker?.cancel();
        _runningId = null;
      }
      for (final a in activities) {
        if (timerStates[a.id]?.status == 'done') {
          timerStates[a.id] = TimerState();
        }
      }
      _statsCache = null;
      await _saveState();
      await prefs.setString('ft_last_date', today);
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  TimerState stateOf(String id) => timerStates[id] ?? TimerState();

  Activity? activityById(String id) {
    try { return activities.firstWhere((a) => a.id == id); } catch (_) { return null; }
  }

  static String formatTime(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String formatMins(int mins) {
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${mins}m';
  }

  /// Short format: shows "5m 30s" for short durations, "1h 20m" for long ones
  static String formatElapsed(int secs) {
    if (secs < 60) return '${secs}s';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  double getProgress(String id) {
    final a = activityById(id);
    if (a == null) return 0;
    return (stateOf(id).elapsed / (a.targetMinutes * 60)).clamp(0.0, 1.0);
  }

  // ── Timer Control ────────────────────────────────────────────────

  void startTimer(String id) {
    if (_runningId != null && _runningId != id) {
      _pauseInternal(_runningId!);
    }

    timerStates[id]!.status = 'running';
    _runningId = id;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = timerStates[id];
      if (s == null || s.status != 'running') { _ticker?.cancel(); return; }
      s.elapsed++;

      // Auto-done at target (check before Pomodoro so completion wins when both coincide)
      final a = activityById(id);
      if (a != null && s.elapsed >= a.targetMinutes * 60) {
        s.status = 'done';
        final entry = _logSession(id);
        if (entry != null) onSessionLogged?.call(entry);
        onTimerDone?.call(id);
        _runningId = null;
        _ticker?.cancel();
        _saveState();
        notifyListeners();
        return;
      }

      // Pomodoro: pause every N min — notify user
      if (isPomodoroMode) {
        final nextAt = (s.pomodoroCount + 1) * pomodoroDurationMinutes * 60;
        if (s.elapsed >= nextAt) {
          s.pomodoroCount++;
          s.status = 'paused';
          _runningId = null;
          _ticker?.cancel();
          onPomodoroBreak?.call(a?.name ?? 'Timer', s.pomodoroCount);
          _saveState();
          notifyListeners();
          return;
        }
      }

      if (s.elapsed % 10 == 0) _saveState();
      notifyListeners();
    });

    _saveState();
    notifyListeners();
  }

  void _pauseInternal(String id) {
    timerStates[id]?.status = 'paused';
    if (_runningId == id) _runningId = null;
  }

  void pauseTimer(String id) {
    _ticker?.cancel();
    _pauseInternal(id);
    _saveState();
    notifyListeners();
  }

  void finishTimer(String id) {
    _ticker?.cancel();
    final s = timerStates[id]!;
    final a = activityById(id);
    if (_runningId == id) _runningId = null;

    s.status = (a != null && s.elapsed >= a.targetMinutes * 60) ? 'done' : 'paused';

    // Only log if elapsed > 2 min to avoid accidental taps
    if (s.elapsed > 120 && !s.partialLogged) {
      final entry = _logSession(id);
      s.partialLogged = true;
      if (entry != null) {
        onSessionLogged?.call(entry);
        if (s.status == 'done') onTimerDone?.call(id);
      }
    } else if (s.status == 'done') {
      onTimerDone?.call(id);
    }

    _saveState();
    _saveHistory();
    notifyListeners();
  }

  HistoryEntry? _logSession(String id) {
    final a = activityById(id);
    final s = timerStates[id];
    if (a == null || s == null) return null;

    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final entry = HistoryEntry(
      date: date,
      name: a.name,
      icon: a.icon,
      duration: s.elapsed,
      timestamp: now.millisecondsSinceEpoch,
    );
    history.add(entry);
    if (history.length > 1000) history.removeRange(0, history.length - 1000);
    _statsCache = null;
    _saveHistory();
    return entry;
  }

  void saveNote(HistoryEntry entry, String note) {
    entry.note = note;
    _saveHistory();
    notifyListeners();
  }

  void deleteHistoryEntry(HistoryEntry entry) {
    history.remove(entry);
    _statsCache = null;
    _saveHistory();
    notifyListeners();
  }

  void clearAllHistory() {
    history.clear();
    _statsCache = null;
    _saveHistory();
    notifyListeners();
  }

  void resetTimer(String id) {
    if (_runningId == id) { _ticker?.cancel(); _runningId = null; }
    timerStates[id] = TimerState();
    _saveState();
    notifyListeners();
  }

  void togglePomodoro() {
    isPomodoroMode = !isPomodoroMode;
    SharedPreferences.getInstance().then((p) => p.setBool('ft_pomodoro_on', isPomodoroMode));
    notifyListeners();
  }

  void setPomodoroMins(int mins) {
    pomodoroDurationMinutes = mins.clamp(1, 120);
    SharedPreferences.getInstance().then((p) => p.setInt('ft_pomodoro_mins', pomodoroDurationMinutes));
    notifyListeners();
  }

  void setAlarmSoundUri(String? uri) {
    alarmSoundUri = uri;
    SharedPreferences.getInstance().then((p) {
      if (uri == null) {
        p.remove('ft_alarm_uri');
      } else {
        p.setString('ft_alarm_uri', uri);
      }
    });
    notifyListeners();
  }

  // ── CRUD ─────────────────────────────────────────────────────────

  void reorderActivities(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = activities.removeAt(oldIndex);
    activities.insert(newIndex, item);
    _saveActivities();
    notifyListeners();
  }

  void addActivity({required String icon, required String name, required int targetMinutes}) {
    final a = Activity(id: _uuid.v4(), icon: icon, name: name, targetMinutes: targetMinutes);
    activities.add(a);
    timerStates[a.id] = TimerState();
    _saveActivities();
    _saveState();
    notifyListeners();
  }

  void updateActivity(String id, {required String icon, required String name, required int targetMinutes}) {
    final i = activities.indexWhere((a) => a.id == id);
    if (i >= 0) {
      activities[i] = Activity(id: id, icon: icon, name: name, targetMinutes: targetMinutes);
      _saveActivities();
      notifyListeners();
    }
  }

  void deleteActivity(String id) {
    if (_runningId == id) { _ticker?.cancel(); _runningId = null; }
    activities.removeWhere((a) => a.id == id);
    timerStates.remove(id);
    _saveActivities();
    _saveState();
    notifyListeners();
  }

  Future<void> resetAll() async {
    _ticker?.cancel();
    _runningId = null;
    for (final a in activities) { timerStates[a.id] = TimerState(); }
    await _saveState();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _ticker?.cancel();
    _runningId = null;
    activities.clear();
    timerStates.clear();
    history.clear();
    _statsCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ft_activities');
    await prefs.remove('ft_state');
    await prefs.remove('ft_history');
    await prefs.remove('ft_last_date');
    notifyListeners();
  }

  int get totalElapsedToday => timerStates.values.fold(0, (s, t) => s + t.elapsed);

  // ── Mastery ──────────────────────────────────────────────────────
  static const masteryTiers = [
    (emoji: '🌱', label: 'Beginner',    message: 'Hardest phase — push through',  seconds: 0),
    (emoji: '⚡', label: 'Functional',  message: 'You can handle the basics now', seconds: 72000),    // 20h
    (emoji: '🔥', label: 'Comfortable', message: 'Building real depth',            seconds: 360000),  // 100h
    (emoji: '💎', label: 'Proficient',  message: 'Mastery achieved',              seconds: 3600000), // 1000h
  ];

  static ({String emoji, String label, String message, int seconds}) masteryFor(int totalSecs) {
    for (var i = masteryTiers.length - 1; i >= 0; i--) {
      if (totalSecs >= masteryTiers[i].seconds) return masteryTiers[i];
    }
    return masteryTiers[0];
  }

  int totalSecsForActivity(String name) =>
      history.where((e) => e.name == name).fold(0, (s, e) => s + e.duration);

  // Average seconds/day over last 7 days (0 if no data)
  int avgDailySecsForActivity(String name) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final total = history.where((e) => e.name == name && e.timestamp >= cutoff).fold(0, (s, e) => s + e.duration);
    return (total / 7).round();
  }

  // ── Activity Highlight ───────────────────────────────────────────
  // Returns one of: 'neverStarted', 'neglected', 'atRisk', 'onARoll', or null
  ({String? type, int daysSince}) activityHighlight(String name) {
    final entries = history.where((e) => e.name == name).toList();

    if (entries.isEmpty) {
      Activity? act;
      try { act = activities.firstWhere((a) => a.name == name); } catch (_) {}
      if (act != null && (timerStates[act.id]?.elapsed ?? 0) > 0) {
        return (type: null, daysSince: 0);
      }
      return (type: 'neverStarted', daysSince: 0);
    }

    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final loggedDates = entries.map((e) => e.date).toSet();

    // On a roll — logged every day for last 7 days
    final last7 = List.generate(7, (i) => _dateStr(today.subtract(Duration(days: i))));
    if (last7.every((d) => loggedDates.contains(d))) {
      return (type: 'onARoll', daysSince: 0);
    }

    // Days since last session
    final lastTimestamp = entries.map((e) => e.timestamp).reduce((a, b) => a > b ? a : b);
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
    final daysSince = today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

    // Neglected — 3+ days without a session
    if (daysSince >= 3) return (type: 'neglected', daysSince: daysSince);

    // At risk — has history, nothing logged today, but other activities have today sessions
    final hasToday = loggedDates.contains(todayStr);
    final othersHaveToday = history.any((e) => e.name != name && e.date == todayStr);
    if (!hasToday && othersHaveToday) return (type: 'atRisk', daysSince: daysSince);

    return (type: null, daysSince: 0);
  }

  // ── Stats ────────────────────────────────────────────────────────

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Returns cached stats, recomputing only when history changed or day rolled over.
  _StatsSnapshot _getStats() {
    final today = _dateStr(DateTime.now());
    if (_statsCache != null && _statsCache!.date == today) return _statsCache!;

    // ── compute active dates ──
    final dateSet = <String>{};
    for (final h in history) { dateSet.add(h.date); }
    final dates = dateSet.toList()..sort();

    // ── current streak ──
    int currentStreak = 0;
    if (dates.isNotEmpty) {
      final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
      if (dates.last == today || dates.last == yesterday) {
        currentStreak = 1;
        for (int i = dates.length - 1; i > 0; i--) {
          final diff = DateTime.parse(dates[i])
              .difference(DateTime.parse(dates[i - 1])).inDays;
          if (diff == 1) { currentStreak++; } else { break; }
        }
      }
    }

    // ── best streak ──
    int bestStreak = dates.isEmpty ? 0 : 1;
    int run = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = DateTime.parse(dates[i])
          .difference(DateTime.parse(dates[i - 1])).inDays;
      if (diff == 1) { run++; if (run > bestStreak) bestStreak = run; }
      else { run = 1; }
    }

    // ── totals ──
    int totalFocused = 0;
    for (final h in history) { totalFocused += h.duration; }

    // ── last 7 days ──
    final now = DateTime.now();
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final last7 = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = _dateStr(day);
      int secs = 0;
      for (final h in history) { if (h.date == key) secs += h.duration; }
      return (label: dayLabels[day.weekday - 1], seconds: secs, isToday: i == 6);
    });

    // ── top activities (capped at 8) ──
    final actMap = <String, ({String icon, String name, int seconds})>{};
    for (final h in history) {
      final prev = actMap[h.name];
      actMap[h.name] = (icon: h.icon, name: h.name, seconds: (prev?.seconds ?? 0) + h.duration);
    }
    final topList = actMap.values.toList()..sort((a, b) => b.seconds.compareTo(a.seconds));

    _statsCache = _StatsSnapshot(
      date: today,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalFocusedAllTime: totalFocused,
      totalSessionsAllTime: history.length,
      last7DaysFocus: last7,
      topActivities: topList.take(8).toList(),
    );
    return _statsCache!;
  }

  int get currentStreak        => _getStats().currentStreak;
  int get bestStreak           => _getStats().bestStreak;
  int get totalFocusedAllTime  => _getStats().totalFocusedAllTime;
  int get totalSessionsAllTime => _getStats().totalSessionsAllTime;
  List<({String label, int seconds, bool isToday})> get last7DaysFocus => _getStats().last7DaysFocus;
  List<({String icon, String name, int seconds})>   get topActivities  => _getStats().topActivities;

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }
}
