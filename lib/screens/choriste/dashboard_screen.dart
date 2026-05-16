import 'package:cso_mobile/screens/choriste/messagerie_chef_screen.dart';
import 'package:cso_mobile/screens/choriste/presences_screen.dart';
import 'package:cso_mobile/screens/choriste/programme_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';
import '../../services/chef_pupitre_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ─────────────────────────────────────────────────────────────
  // ÉTAT
  // ─────────────────────────────────────────────────────────────

  final ChoristeService _service = ChoristeService();
  final ChefPupitreService _chefService = ChefPupitreService();

  Map<String, dynamic>? _dashboardData;
  List<dynamic> _allRepetitions = [];
  List<dynamic> _allConcerts = [];
  List<dynamic> _messages = [];
  bool _isLoading = true;

  /// Map<repId, List<minutesBefore>> — rappels actifs non envoyés
  final Map<String, List<int>> _repReminders = {};

  // ─────────────────────────────────────────────────────────────
  // CONSTANTES
  // ─────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> _reminderPresets = [
    {'label': '2 min avant', 'value': 2},
    {'label': '5 min avant', 'value': 5},
    {'label': '10 min avant', 'value': 10},
    {'label': '15 min avant', 'value': 15},
    {'label': '30 min avant', 'value': 30},
    {'label': '1h avant', 'value': 60},
    {'label': '1h30 avant', 'value': 90},
    {'label': '2h avant', 'value': 120},
    {'label': '3h avant', 'value': 180},
    {'label': 'La veille', 'value': 1440},
    {'label': '2 jours avant', 'value': 2880},
    {'label': 'Personnalisé...', 'value': -1},
  ];

  // ─────────────────────────────────────────────────────────────
  // CYCLE DE VIE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getChoristeDashboard();
      final reps = await _service.getRepetitions();
      final concerts = await _service.getConcerts();
      final reminders = await _service.getAllMyReminders();

      List<dynamic> msgs = [];
      try {
        msgs = await _chefService.getChoristMessages();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _allRepetitions = reps;
        _allConcerts = concerts;
        _messages = msgs;
        _repReminders
          ..clear()
          ..addAll(reminders);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS — DATES
  // ─────────────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    const months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }

  String _formatDateShort(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    const months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${date.day} ${months[date.month]}';
  }

  String _formatMsgDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return _formatDateShort(raw);
    } catch (_) {
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS — RAPPELS
  // ─────────────────────────────────────────────────────────────

  String _formatMinutes(int min) {
    if (min >= 2880) return '${min ~/ 1440}j avant';
    if (min == 1440) return 'La veille';
    if (min >= 60 && min % 60 == 0) return '${min ~/ 60}h avant';
    if (min >= 60) return '${min ~/ 60}h${min % 60}min avant';
    return '${min}min avant';
  }

  List<int> _getReminders(String repId) =>
      List<int>.from(_repReminders[repId] ?? []);

  // ─────────────────────────────────────────────────────────────
  // HELPERS — RÉPÉTITIONS / PRÉSENCES
  // ─────────────────────────────────────────────────────────────

  List<dynamic> get _weekRepetitions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isFinished(dynamic r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(today)) return true;
      if (_isSameDay(day, today)) {
        final endTime = r['endTime'] as String?;
        if (endTime != null) {
          try {
            final parts = endTime.split(':').map(int.parse).toList();
            final end = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
            return now.isAfter(end);
          } catch (_) {}
        }
      }
      return false;
    }

    final past = _allRepetitions.where(isFinished).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(0);
        final db = _parseDate(b['date']) ?? DateTime(0);
        return db.compareTo(da);
      });

    final upcoming = _allRepetitions.where((r) => !isFinished(r)).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(2099);
        final db = _parseDate(b['date']) ?? DateTime(2099);
        return da.compareTo(db);
      });

    return [...upcoming.take(2), ...past.take(2)];
  }

  List<dynamic> get _upcomingConcerts {
    final now = DateTime.now();
    return _allConcerts.where((c) {
      final d = _parseDate(c['dateHeure']);
      return d != null && d.isAfter(now);
    }).toList()..sort((a, b) {
      final da = _parseDate(a['dateHeure']) ?? DateTime(2099);
      final db = _parseDate(b['dateHeure']) ?? DateTime(2099);
      return da.compareTo(db);
    });
  }

  String _repStatus(dynamic rep, String userId) {
    final manual = (rep['manualPresences'] as List?)?.firstWhere(
      (m) => (m['choriste']?['_id'] ?? m['choriste']) == userId,
      orElse: () => null,
    );
    if (manual != null) {
      return manual['type'] == 'present' ? 'present' : 'absent';
    }

    final present =
        (rep['presentChoristes'] as List?)?.any(
          (c) => (c['_id'] ?? c) == userId,
        ) ??
        false;
    if (present) return 'present';

    final absent =
        (rep['absentChoristes'] as List?)?.any(
          (a) => (a['choriste']?['_id'] ?? a['choriste']) == userId,
        ) ??
        false;
    if (absent) return 'absent';

    final d = _parseDate(rep['date']);
    if (d != null &&
        !_isSameDay(d, DateTime.now()) &&
        d.isBefore(DateTime.now())) {
      return 'absent_default';
    }
    return 'pending';
  }

  int _tauxPresence(String userId) {
    int present = 0, total = 0;
    for (final r in _allRepetitions) {
      final d = _parseDate(r['date']);
      if (d == null || d.isAfter(DateTime.now())) continue;
      total++;
      if (_repStatus(r, userId) == 'present') present++;
    }
    return total > 0 ? (present / total * 100).round() : 0;
  }

  Color _pupitreColor(String p) {
    switch (p) {
      case 'soprano':
        return const Color(0xFF7C3AED);
      case 'alto':
        return const Color(0xFF0891B2);
      case 'ténor':
        return const Color(0xFF059669);
      case 'basse':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS — GESTION DES RAPPELS
  // ─────────────────────────────────────────────────────────────

  Future<void> _addReminder(
    String repId,
    int minutes,
    StateSetter setSheet,
  ) async {
    final current = _getReminders(repId);
    if (current.contains(minutes)) {
      _showSnackError('Ce délai est déjà défini pour cette répétition.');
      return;
    }

    final newList = [...current, minutes]..sort();

    setState(() => _repReminders[repId] = newList);
    setSheet(() {});

    final success = await _service.addRepetitionReminder(repId, minutes);
    if (!mounted) return;

    if (!success) {
      setState(() {
        if (current.isEmpty) {
          _repReminders.remove(repId);
        } else {
          _repReminders[repId] = current;
        }
      });
      setSheet(() {});
      _showSnackError('Erreur lors de l\'ajout du rappel.');
    } else {
      _showSnackSuccess('🔔 Rappel ajouté : ${_formatMinutes(minutes)}');
    }
  }

  Future<void> _removeReminder(
    String repId,
    int minutes,
    StateSetter setSheet,
  ) async {
    final current = _getReminders(repId);
    final newList = current.where((m) => m != minutes).toList();

    setState(() {
      if (newList.isEmpty) {
        _repReminders.remove(repId);
      } else {
        _repReminders[repId] = newList;
      }
    });
    setSheet(() {});

    final success = await _service.deleteRepetitionReminder(repId, minutes);
    if (!mounted) return;

    if (!success) {
      setState(() => _repReminders[repId] = current);
      setSheet(() {});
      _showSnackError('Erreur lors de la suppression du rappel.');
    } else {
      _showSnackbar('Rappel supprimé', Colors.grey.shade700);
    }
  }

  Future<void> _removeAllReminders(String repId, StateSetter setSheet) async {
    final previous = _getReminders(repId);

    setState(() => _repReminders.remove(repId));
    setSheet(() {});

    final success = await _service.deleteAllRepetitionReminders(repId);
    if (!mounted) return;

    if (!success) {
      setState(() => _repReminders[repId] = previous);
      setSheet(() {});
      _showSnackError('Erreur lors de la suppression des rappels.');
    } else {
      _showSnackbar('Tous les rappels supprimés', Colors.grey.shade700);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UI — SNACKBARS
  // ─────────────────────────────────────────────────────────────

  void _showSnackSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1D9E75),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSnackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UI — PICKER PERSONNALISÉ
  // ─────────────────────────────────────────────────────────────

  Future<int?> _showCustomMinutesPicker(BuildContext ctx) async {
    int hours = 0;
    int minutes = 30;

    return showDialog<int>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Délai personnalisé',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choisissez combien de temps avant la répétition '
                'vous souhaitez être notifié.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Heures',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _pickerBtn(
                            Icons.remove,
                            hours > 0 ? () => setDialog(() => hours--) : null,
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$hours',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _pickerBtn(
                            Icons.add,
                            hours < 72 ? () => setDialog(() => hours++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'Minutes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _pickerBtn(
                            Icons.remove,
                            minutes > 0
                                ? () => setDialog(() => minutes--)
                                : null,
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              minutes.toString().padLeft(2, '0'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _pickerBtn(
                            Icons.add,
                            minutes < 59
                                ? () => setDialog(() => minutes++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Builder(
                  builder: (_) {
                    final total = hours * 60 + minutes;
                    return Text(
                      total == 0
                          ? 'Choisissez un délai'
                          : 'Rappel : ${_formatMinutes(total)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2DD4BF),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2DD4BF),
              ),
              onPressed: () {
                final total = hours * 60 + minutes;
                if (total < 1) return;
                Navigator.pop(dialogCtx, total);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: onTap != null ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Icon(
        icon,
        size: 14,
        color: onTap != null ? null : Colors.grey.shade300,
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // UI — BOTTOM SHEET RAPPELS
  // ─────────────────────────────────────────────────────────────

  void _showReminderSheet(BuildContext context, dynamic rep) {
    final repId = rep['_id'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final currentReminders = _getReminders(repId);

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF2DD4BF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rappels',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '${_formatDate(rep['date'])} à ${rep['startTime'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (currentReminders.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Rappels actifs (${currentReminders.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    _removeAllReminders(repId, setSheet),
                                child: const Text(
                                  'Tout supprimer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: currentReminders
                                .map(
                                  (min) => _reminderChip(
                                    label: _formatMinutes(min),
                                    onDelete: () =>
                                        _removeReminder(repId, min, setSheet),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currentReminders.isEmpty
                            ? 'Choisir un rappel'
                            : 'Ajouter un rappel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._reminderPresets.map((option) {
                            final val = option['value'] as int;
                            final isAlreadySet =
                                val != -1 && currentReminders.contains(val);

                            return ListTile(
                              dense: true,
                              enabled: !isAlreadySet,
                              leading: Icon(
                                val == -1
                                    ? Icons.tune_rounded
                                    : Icons.add_alert_outlined,
                                color: isAlreadySet
                                    ? Colors.grey.shade300
                                    : const Color(0xFF2DD4BF),
                                size: 20,
                              ),
                              title: Text(
                                option['label'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: isAlreadySet
                                      ? Colors.grey.shade400
                                      : const Color(0xFF374151),
                                ),
                              ),
                              subtitle: val == -1
                                  ? const Text(
                                      'Choisir une durée précise',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    )
                                  : null,
                              trailing: isAlreadySet
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: Colors.grey.shade400,
                                      size: 16,
                                    )
                                  : val == -1
                                  ? const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF9CA3AF),
                                      size: 20,
                                    )
                                  : null,
                              onTap: isAlreadySet
                                  ? null
                                  : () async {
                                      if (val == -1) {
                                        final custom =
                                            await _showCustomMinutesPicker(ctx);
                                        if (custom != null && custom >= 1) {
                                          await _addReminder(
                                            repId,
                                            custom,
                                            setSheet,
                                          );
                                        }
                                      } else {
                                        await _addReminder(
                                          repId,
                                          val,
                                          setSheet,
                                        );
                                      }
                                    },
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — CHIP RAPPEL ACTIF
  // ─────────────────────────────────────────────────────────────

  Widget _reminderChip({
    required String label,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2DD4BF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            size: 13,
            color: Color(0xFF2DD4BF),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2DD4BF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 11,
                color: Color(0xFF2DD4BF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineReminderBadge(int min) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2DD4BF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            size: 9,
            color: Color(0xFF2DD4BF),
          ),
          const SizedBox(width: 3),
          Text(
            _formatMinutes(min),
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF2DD4BF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final userId = user?.id ?? '';
    final taux = _tauxPresence(userId);
    final nextConcert = _upcomingConcerts.isNotEmpty
        ? _upcomingConcerts.first
        : null;
    final weekReps = _weekRepetitions;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF2DD4BF),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user),
                  const SizedBox(height: 20),
                  _buildPresenceCard(taux, userId),
                  const SizedBox(height: 14),
                  if (nextConcert != null) ...[
                    _buildNextConcertCard(nextConcert, userId),
                    const SizedBox(height: 20),
                  ],

                  // Messages non lus
                  _buildMessagesSectionTitle(user),
                  const SizedBox(height: 12),
                  _buildMessagesSection(user),
                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    'Répétitions',
                    Icons.event_note_rounded,
                    const Color(0xFF2DD4BF),
                  ),
                  const SizedBox(height: 12),
                  _buildWeekRepetitions(weekReps, userId),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF2DD4BF), Color(0xFF60A5FA)],
                ).createShader(bounds),
                child: const Text(
                  'CSO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Carthage Symphony Orchestra',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — CARTE PRÉSENCE
  // ─────────────────────────────────────────────────────────────

  Widget _buildPresenceCard(int taux, String userId) {
    Color color;
    String label;
    IconData icon;

    if (taux >= 80) {
      color = const Color(0xFF22C55E);
      label = 'Excellente assiduité';
      icon = Icons.emoji_events_rounded;
    } else if (taux >= 60) {
      color = const Color(0xFFF59E0B);
      label = 'Assiduité correcte';
      icon = Icons.trending_up_rounded;
    } else {
      color = const Color(0xFFEF4444);
      label = 'Assiduité insuffisante';
      icon = Icons.warning_amber_rounded;
    }

    int total = 0, present = 0;
    for (final r in _allRepetitions) {
      final d = _parseDate(r['date']);
      if (d == null || d.isAfter(DateTime.now())) continue;
      total++;
      if (_repStatus(r, userId) == 'present') present++;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: taux / 100,
                  strokeWidth: 7,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '$taux%',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Taux de présence',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$present répétition${present > 1 ? 's' : ''} sur $total '
                  'assistée${present > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — SECTION MESSAGES
  // ─────────────────────────────────────────────────────────────

  Widget _buildMessagesSectionTitle(dynamic user) {
    final pColor = _pupitreColor(user?.pupitre ?? '');
    final unreadCount = _messages.where((m) => m['readAt'] == null).length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: pColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.mark_chat_read_rounded, size: 15, color: pColor),
        ),
        const SizedBox(width: 10),
        const Text(
          'Messages non lus',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        if (unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: pColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessagesSection(dynamic user) {
    final pupitre = user?.pupitre as String? ?? '';
    final pColor = _pupitreColor(pupitre);
    final unreadMessages = _messages.where((m) => m['readAt'] == null).toList();

    if (unreadMessages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.mark_chat_read_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Pas de messages pour le moment',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final toShow = unreadMessages.take(3).toList();
    return Column(
      children: [
        ...toShow.map((msg) {
          final sender = msg['senderId'] as Map?;
          final isRead = msg['readAt'] != null;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesChoristScreen()),
            ).then((_) => _loadDashboard()),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRead
                      ? const Color(0xFFE2E8F0)
                      : pColor.withOpacity(0.35),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: pColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        sender != null
                            ? '${sender['firstName']?[0] ?? '?'}'
                            : '?',
                        style: TextStyle(
                          color: pColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sender?['firstName'] ?? ''} ${sender?['lastName'] ?? ''} · Chef',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          msg['content'] ?? '',
                          style: TextStyle(
                            color: isRead
                                ? const Color(0xFF64748B)
                                : const Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatMsgDate(msg['createdAt']),
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (unreadMessages.length > 3)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesChoristScreen()),
            ).then((_) => _loadDashboard()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: pColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pColor.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  'Voir tous les messages (${_messages.length})',
                  style: TextStyle(
                    color: pColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — CARTE PROCHAIN CONCERT
  // ─────────────────────────────────────────────────────────────

  Widget _buildNextConcertCard(dynamic concert, String userId) {
    final d = _parseDate(concert['dateHeure']);
    final daysLeft = d?.difference(DateTime.now()).inDays;

    final dispo =
        (concert['availableChoristes'] as List?)?.any(
          (c) => (c['_id'] ?? c) == userId,
        ) ??
        false;
    final indispo =
        (concert['absentChoristes'] as List?)?.any(
          (a) => (a['choriste']?['_id'] ?? a) == userId,
        ) ??
        false;

    String statusLabel = 'À confirmer';
    Color statusColor = const Color(0xFFF59E0B);
    Color statusBg = const Color(0xFFFFFBEB);

    if (dispo) {
      statusLabel = '✓ Disponible';
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
    }
    if (indispo) {
      statusLabel = '✗ Indisponible';
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text(
                'Programme de la saison',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: Colors.black12,
              surfaceTintColor: Colors.white,
              iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
            ),
            body: const ProgrammeScreen(),
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    daysLeft != null ? 'J-$daysLeft' : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'jours',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prochain concert',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    concert['title'] ?? 'Concert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(concert['dateHeure']),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (concert['location'] != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            concert['location'],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — SECTION TITLE
  // ─────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — LISTE DES RÉPÉTITIONS
  // ─────────────────────────────────────────────────────────────

  Widget _buildWeekRepetitions(List<dynamic> reps, String userId) {
    if (reps.isEmpty) {
      return _buildEmptyCard(
        'Aucune répétition cette semaine',
        Icons.event_note_rounded,
        const Color(0xFF2DD4BF),
      );
    }

    return Column(
      children: reps.map((rep) {
        final d = _parseDate(rep['date']);
        final now = DateTime.now();
        final isToday = d != null && _isSameDay(d, now);

        bool isPast = d != null && !isToday && d.isBefore(now);
        if (!isPast && isToday && d != null) {
          final endTime = rep['endTime'] as String?;
          if (endTime != null) {
            final parts = endTime.split(':').map(int.parse).toList();
            final end = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
            if (now.isAfter(end)) isPast = true;
          }
        }

        final Color accentColor = isPast
            ? const Color(0xFF9CA3AF)
            : const Color(0xFFF59E0B);
        final String statusLabel = isPast ? 'Passée' : 'À venir';
        final Color statusBg = isPast
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFFFFBEB);

        final repId = rep['_id'].toString();
        final reminders = _getReminders(repId);
        final hasReminders = reminders.isNotEmpty;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text(
                    'Gérer les présences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  shadowColor: Colors.black12,
                  surfaceTintColor: Colors.white,
                  iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
                ),
                body: PresencesScreen(initialTab: isPast ? 1 : 0),
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPast ? const Color(0xFFFAFAFA) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isToday
                  ? Border.all(
                      color: const Color(0xFF2DD4BF).withOpacity(0.4),
                      width: 1.5,
                    )
                  : isPast
                  ? Border.all(color: const Color(0xFFE5E7EB))
                  : null,
              boxShadow: isPast
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.library_music_rounded,
                        color: Color(0xFF2DD4BF),
                        size: 20,
                      ),
                    ),
                    if (isToday)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Auj.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Répétition',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (rep['concert']?['title'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          rep['concert']['title'],
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(rep['date']),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${rep['startTime']} – ${rep['endTime']}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (rep['location'] != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 11,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                rep['location'],
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isPast && hasReminders) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: reminders
                              .map((min) => _inlineReminderBadge(min))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isPast) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _showReminderSheet(context, rep),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: hasReminders
                                    ? const Color(0xFF2DD4BF).withOpacity(0.12)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasReminders
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                size: 16,
                                color: hasReminders
                                    ? const Color(0xFF2DD4BF)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            if (reminders.length > 1)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2DD4BF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${reminders.length}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS — EMPTY CARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyCard(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: color.withOpacity(0.4)),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
