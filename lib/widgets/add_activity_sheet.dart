import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

class AddActivitySheet extends StatefulWidget {
  final Activity? activity;
  const AddActivitySheet({super.key, this.activity});

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _iconCtrl = TextEditingController();
  String _icon = '⏱';
  String? _nameError;

  static const _icons = [
    '💻','📚','🎯','🏃','🎨','🎵','✍️','🧘','📝','🔬',
    '💡','🏋️','🍳','🌱','📊','🎮','🗣️','✈️','💰','⏱',
    '🧠','🔧','📱','🌍','🎭','⚽','🎸','🏊','🧪','📷',
  ];

  static const _presets = [
    {'label': '25m', 'value': 25},
    {'label': '30m', 'value': 30},
    {'label': '45m', 'value': 45},
    {'label': '1h',  'value': 60},
    {'label': '2h',  'value': 120},
    {'label': '3h',  'value': 180},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.activity != null) {
      _nameCtrl.text = widget.activity!.name;
      _targetCtrl.text = widget.activity!.targetMinutes.toString();
      _icon = widget.activity!.icon;
      _iconCtrl.text = widget.activity!.icon;
    } else {
      _targetCtrl.text = '60';
      _iconCtrl.text = _icon;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _nameError = 'Activity name is required');
      return;
    }
    final rawTarget = int.tryParse(_targetCtrl.text) ?? 60;
    final target = rawTarget.clamp(1, 480);
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    if (widget.activity == null) {
      state.addActivity(icon: _icon, name: name, targetMinutes: target);
    } else {
      state.updateActivity(widget.activity!.id, icon: _icon, name: name, targetMinutes: target);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.activity != null;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Handle
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
            isEdit ? 'Edit Activity' : 'New Activity',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),

          // Icon picker
          _label('Choose Icon'),
          const SizedBox(height: 10),

          // Current icon preview + custom input
          Row(
            children: [
              // Preview
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent, width: 1.5),
                ),
                child: Center(child: Text(_icon, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _iconCtrl,
                  maxLength: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: ''),
                  decoration: InputDecoration(
                    hintText: 'Type any emoji...',
                    hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() => _icon = val.trim());
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick-pick grid
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _icons.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final ico = _icons[i];
                final sel = ico == _icon;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _icon = ico;
                      _iconCtrl.text = ico;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.accent.withAlpha(40)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? AppTheme.accent : AppTheme.border,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Center(child: Text(ico, style: const TextStyle(fontSize: 22))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Name
          _label('Activity Name'),
          const SizedBox(height: 8),
          _field(
            controller: _nameCtrl,
            hint: 'e.g. Deep Work, Reading...',
            autofocus: !isEdit,
            errorText: _nameError,
            onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
          ),
          const SizedBox(height: 20),

          // Target
          _label('Daily Target'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _targetCtrl,
                  hint: 'minutes',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Text('min', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),

          // Quick presets
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _presets.map((p) {
              final val = p['value'] as int;
              final selected =
                  _targetCtrl.text == val.toString();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _targetCtrl.text = val.toString());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent.withAlpha(40)
                        : Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    p['label'] as String,
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
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Add Activity',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 12,
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool autofocus = false,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontFamilyFallback: ['Roboto', 'sans-serif']),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted),
        errorText: errorText,
        errorStyle: const TextStyle(color: AppTheme.danger, fontSize: 12),
        filled: true,
        fillColor: hasError ? AppTheme.danger.withAlpha(10) : Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: hasError ? AppTheme.danger : AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: hasError ? AppTheme.danger : AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: hasError ? AppTheme.danger : AppTheme.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}
