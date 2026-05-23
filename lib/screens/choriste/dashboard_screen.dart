import 'package:cso/screens/choriste/messagerie_chef_screen.dart';
import 'package:cso/screens/home_screen.dart';
import 'package:cso/screens/sondages_screen.dart';
import 'package:cso/screens/survey_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/survey_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';
import '../../services/chef_pupitre_service.dart';
import '../../services/notification_service.dart';
import '../../services/survey_service.dart';
import '../../widgets/concert_cards.dart';

part 'dashboard_ui.dart';

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
  final SurveyService _surveyService = SurveyService();

  static const Color _bg = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1D26);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE8ECF4);
  static const Color _accent = Color(0xFF4F5D94);

  List<dynamic> _allRepetitions = [];
  List<dynamic> _allConcerts = [];
  List<dynamic> _messages = [];
  List<SurveyModel> _pendingSurveys = [];
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
      await _service.getChoristeDashboard();
      final reps = await _service.getRepetitions();
      final concerts = await _service.getConcerts();
      final reminders = await _service.getAllMyReminders();

      List<dynamic> msgs = [];
      try {
        msgs = await _chefService.getChoristMessages();
      } catch (_) {}

      final pendingSurveys = <SurveyModel>[];
      try {
        final raw = await _surveyService.getSurveys();
        for (final j in raw) {
          final s = SurveyModel.fromJson(j as Map<String, dynamic>);
          if (s.statut != 'actif') continue;
          final rep = await _surveyService.getMaReponse(s.id);
          if (rep == null) pendingSurveys.add(s);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _allRepetitions = reps;
        _allConcerts = concerts;
        _messages = msgs;
        _pendingSurveys = pendingSurveys;
        _repReminders
          ..clear()
          ..addAll(reminders);
        _isLoading = false;
      });

      HomeScreen.of(context)?.refreshNotificationBadge();
      await NotificationService.notifyNewPendingSurveys(
        pendingSurveys
            .map((s) => (id: s.id, titre: s.titre))
            .toList(),
      );
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

  bool _isRepFinished(dynamic r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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

  List<dynamic> get _upcomingRepetitions {
    return _allRepetitions.where((r) => !_isRepFinished(r)).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(2099);
        final db = _parseDate(b['date']) ?? DateTime(2099);
        return da.compareTo(db);
      });
  }

  /// Onglet Présences dans HomeScreen (même rendu que le menu latéral).
  void _openPresencesTab() {
    final home = HomeScreen.of(context);
    if (home != null) {
      home.selectTab(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 1),
      ),
    );
  }

  int get _unreadMessagesCount =>
      _messages.where((m) => m['readAt'] == null).length;

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
    final pupitreColor = _pupitreColor(user?.pupitre ?? '');
    final upcomingReps = _upcomingRepetitions.take(4).toList();
    final upcomingConcerts = _upcomingConcerts.take(3).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: _accent,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Container(
              color: _bg,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoBanner(),
                    const SizedBox(height: 18),
                    _buildQuickStats(
                      taux: taux,
                      unread: _unreadMessagesCount,
                      surveys: _pendingSurveys.length,
                      concerts: upcomingConcerts.length,
                      reps: upcomingReps.length,
                      pupitreColor: pupitreColor,
                    ),
                    if (_pendingSurveys.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Sondages à répondre',
                        Icons.poll_outlined,
                        const Color(0xFF0D9488),
                        badge: _pendingSurveys.length,
                      ),
                      const SizedBox(height: 10),
                      _buildSurveysSection(pupitreColor),
                    ],
                    if (_unreadMessagesCount > 0) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Messages non lus',
                        Icons.mark_chat_unread_outlined,
                        const Color(0xFF7C3AED),
                        badge: _unreadMessagesCount,
                      ),
                      const SizedBox(height: 10),
                      _buildMessagesSection(user, pupitreColor),
                    ],
                    if (_pendingSurveys.isEmpty &&
                        _unreadMessagesCount == 0) ...[
                      const SizedBox(height: 24),
                      _buildAllClearBanner(),
                    ],
                    if (upcomingReps.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Répétitions à venir',
                        Icons.event_note_outlined,
                        const Color(0xFFD97706),
                        badge: upcomingReps.length,
                      ),
                      const SizedBox(height: 10),
                      _buildRepetitionsSection(upcomingReps, userId),
                    ],
                    if (upcomingConcerts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Concerts à venir',
                        Icons.music_note_outlined,
                        const Color(0xFFBE185D),
                        badge: upcomingConcerts.length,
                      ),
                      const SizedBox(height: 10),
                      _buildConcertsSection(upcomingConcerts, userId),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Présence',
                      Icons.verified_outlined,
                      pupitreColor,
                    ),
                    const SizedBox(height: 10),
                    _buildPresenceCard(taux, userId, pupitreColor),
                  ],
                ),
              ),
            ),
    );
  }

}
