import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/choriste_service.dart';

class ReminderPreferencesScreen extends StatefulWidget {
  const ReminderPreferencesScreen({super.key});

  @override
  State<ReminderPreferencesScreen> createState() =>
      _ReminderPreferencesScreenState();
}

class _ReminderPreferencesScreenState extends State<ReminderPreferencesScreen> {
  // ── État local ──────────────────────────────────────────────
  bool _dayBeforeEnabled = true;

  bool _twoHoursEnabled = true;
  int _twoHoursMinutes = 120;

  bool _tenMinEnabled = true;
  int _tenMinMinutes = 10;

  bool _loading = true;
  bool _saving = false;

  // ── Initialisation ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ChoristeService().getReminderPreferences();
    if (!mounted) return;
    if (prefs != null) {
      setState(() {
        _dayBeforeEnabled = prefs['dayBefore']?['enabled'] ?? true;
        _twoHoursEnabled = prefs['twoHours']?['enabled'] ?? true;
        _twoHoursMinutes = prefs['twoHours']?['minutesBefore'] ?? 120;
        _tenMinEnabled = prefs['tenMinutes']?['enabled'] ?? true;
        _tenMinMinutes = prefs['tenMinutes']?['minutesBefore'] ?? 10;
      });
    }
    setState(() => _loading = false);
  }

  // ── Sauvegarde ──────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ChoristeService().updateReminderPreferences({
        'dayBefore': {'enabled': _dayBeforeEnabled},
        'twoHours': {
          'enabled': _twoHoursEnabled,
          'minutesBefore': _twoHoursMinutes,
        },
        'tenMinutes': {
          'enabled': _tenMinEnabled,
          'minutesBefore': _tenMinMinutes,
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Préférences sauvegardées ✓'),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers UI ──────────────────────────────────────────────
  String _fmt(int v) {
    if (v >= 60 && v % 60 == 0) return '${v ~/ 60}h avant';
    if (v >= 60) return '${v ~/ 60}h ${v % 60}min avant';
    return '${v}min avant';
  }

  // ── Widgets ─────────────────────────────────────────────────
  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    value: value,
    onChanged: onChanged,
    activeColor: const Color(0xFF1D9E75),
  );

  Widget _stepperRow({
    required int value,
    required int min,
    required int max,
    required int step,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) => AnimatedOpacity(
    opacity: enabled ? 1.0 : 0.35,
    duration: const Duration(milliseconds: 200),
    child: IgnorePointer(
      ignoring: !enabled,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Text(
              'Délai : ${_fmt(value)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            // Bouton −
            _stepBtn(
              icon: Icons.remove,
              onTap: value > min ? () => onChanged(value - step) : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Bouton +
            _stepBtn(
              icon: Icons.add,
              onTap: value < max ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stepBtn({required IconData icon, VoidCallback? onTap}) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? null : Colors.grey.shade300,
        ),
      ),
    ),
  );

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes rappels')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Rappel J-1 ──────────────────────────────
                _sectionHeader('Rappel J-1'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: _switchTile(
                    title: 'Rappel la veille',
                    subtitle: 'Notification la veille de chaque répétition',
                    value: _dayBeforeEnabled,
                    onChanged: (v) => setState(() => _dayBeforeEnabled = v),
                  ),
                ),

                // ── Rappel anticipé ──────────────────────────
                _sectionHeader('Rappel anticipé'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Rappel avant la répétition',
                        subtitle: 'Actuellement : ${_fmt(_twoHoursMinutes)}',
                        value: _twoHoursEnabled,
                        onChanged: (v) => setState(() => _twoHoursEnabled = v),
                      ),
                      _stepperRow(
                        value: _twoHoursMinutes,
                        min: 60,
                        max: 240,
                        step: 30,
                        enabled: _twoHoursEnabled,
                        onChanged: (v) => setState(() => _twoHoursMinutes = v),
                      ),
                    ],
                  ),
                ),

                // ── Rappel urgent ────────────────────────────
                _sectionHeader('Rappel urgent'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Rappel de dernière minute',
                        subtitle: 'Actuellement : ${_fmt(_tenMinMinutes)}',
                        value: _tenMinEnabled,
                        onChanged: (v) => setState(() => _tenMinEnabled = v),
                      ),
                      _stepperRow(
                        value: _tenMinMinutes,
                        min: 5,
                        max: 30,
                        step: 5,
                        enabled: _tenMinEnabled,
                        onChanged: (v) => setState(() => _tenMinMinutes = v),
                      ),
                    ],
                  ),
                ),

                // ── Bouton sauvegarder ───────────────────────
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Enregistrer mes préférences',
                            style: TextStyle(fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
