import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cso_ui.dart';

class PresencesScreen extends StatefulWidget {
  final int initialTab;
  const PresencesScreen({super.key, this.initialTab = 0});

  @override
  State<PresencesScreen> createState() => _PresencesScreenState();
}

class _PresencesScreenState extends State<PresencesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChoristeService _service = ChoristeService();

  List<dynamic> _repetitions = [];
  List<dynamic> _concerts = [];
  bool _isLoading = true;
  // key = item _id, value = 'present' | 'absent' | 'absent_default' | null
  Map<String, String?> _statusMap = {};
  bool _historyPresentExpanded = false;
  bool _historyAbsentExpanded = false;

  // ── Repetition split ──

  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));
  DateTime _endOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1) + 6, 23, 59, 59);

  // "À venir" = toutes les répétitions futures non encore terminées
  List<dynamic> get _upcomingRepetitions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _repetitions.where((r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      // Exclure les jours passés
      if (day.isBefore(today)) return false;
      // Si c'est aujourd'hui, exclure si déjà terminée
      if (_isSameDay(day, now)) {
        final endTime = r['endTime'] as String?;
        if (endTime != null) {
          final parts = endTime.split(':').map(int.parse).toList();
          final end = DateTime(day.year, day.month, day.day, parts[0], parts[1]);
          if (now.isAfter(end)) return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(2099);
        final db = _parseDate(b['date']) ?? DateTime(2099);
        return da.compareTo(db);
      });
  }

  List<dynamic> get _historyRepetitions {
    final now = DateTime.now();
    return _repetitions.where((r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      // Répétitions des jours passés
      if (!_isSameDay(d, now) && d.isBefore(now)) return true;
      // Répétitions d'aujourd'hui déjà terminées
      if (_isSameDay(d, now)) {
        final endTime = r['endTime'] as String?;
        if (endTime != null) {
          final parts = endTime.split(':').map(int.parse).toList();
          final end = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
          return now.isAfter(end);
        }
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(0);
        final db = _parseDate(b['date']) ?? DateTime(0);
        return db.compareTo(da); // Plus récent en premier
      });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ──

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

  /// True only when now is between startTime and endTime on the repetition date
  bool _isInsideWindow(dynamic rep) {
    final date = _parseDate(rep['date']);
    if (date == null) return false;
    final now = DateTime.now();
    if (!_isSameDay(date, now)) return false;

    try {
      final start = _parseTime(rep['startTime'], date);
      var end = _parseTime(rep['endTime'], date);
      if (end.isBefore(start)) end = end.add(const Duration(days: 1));
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  DateTime _parseTime(String? timeStr, DateTime baseDate) {
    if (timeStr == null) return baseDate;
    final parts = timeStr.split(':').map(int.parse).toList();
    final localBase = baseDate.toLocal();
    return DateTime(
        localBase.year, localBase.month, localBase.day, parts[0], parts[1]);
  }

  String _windowHint(dynamic rep) {
    final date = _parseDate(rep['date']);
    if (date == null) return '';
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      try {
        final start = _parseTime(rep['startTime'], date);
        final end = _parseTime(rep['endTime'], date);
        if (now.isBefore(start)) {
          return 'Ouverture à ${rep['startTime']}';
        } else {
          return 'Fermé depuis ${rep['endTime']}';
        }
      } catch (_) {}
    }
    return '';
  }

  // ── Data loading ──

  Future<void> _loadData() async {
    try {
      final reps = await _service.getRepetitions();
      final concerts = await _service.getConcerts();
      final userId =
          context.read<AuthProvider>().user?.id ?? '';

      setState(() {
        _repetitions = reps;
        _concerts = concerts;
        _isLoading = false;
        _statusMap = {};

        for (var rep in reps) {
          final id = rep['_id'] as String;
          final date = _parseDate(rep['date']);
          final isPast = date != null &&
              !_isSameDay(date, DateTime.now()) &&
              date.isBefore(DateTime.now());

          final present = (rep['presentChoristes'] as List?)
                  ?.any((c) => (c['_id'] ?? c) == userId) ??
              false;
          final absent = (rep['absentChoristes'] as List?)
                  ?.any((a) => (a['choriste']?['_id'] ?? a['choriste']) == userId) ??
              false;
          // Also check manualPresences
          final manual = (rep['manualPresences'] as List?)
              ?.firstWhere(
                  (m) =>
                      (m['choriste']?['_id'] ?? m['choriste']) == userId,
                  orElse: () => null);

          // ✅ Vérifier si la répétition est terminée (passée ou aujourd'hui après endTime)
          bool isFinished = isPast;
          if (!isFinished && date != null && _isSameDay(date, DateTime.now())) {
            final endTime = rep['endTime'] as String?;
            if (endTime != null) {
              final parts = endTime.split(':').map(int.parse).toList();
              final end = DateTime(date.year, date.month, date.day, parts[0], parts[1]);
              isFinished = DateTime.now().isAfter(end);
            }
          }

          if (manual != null) {
            _statusMap[id] = manual['type'] == 'present' ? 'present' : 'absent';
          } else if (present) {
            _statusMap[id] = 'present';
          } else if (absent) {
            _statusMap[id] = 'absent';
          } else if (isFinished) {
            // ✅ Répétition terminée sans marquage = absent par défaut
            _statusMap[id] = 'absent_default';
          }
        }

        for (var concert in concerts) {
          final id = concert['_id'] as String;
          final date = _parseDate(concert['dateHeure']);
          final isPast = date != null && date.isBefore(DateTime.now());

          if ((concert['availableChoristes'] as List?)
                  ?.any((c) => (c['_id'] ?? c) == userId) ??
              false) {
            _statusMap[id] = 'present';
          } else if ((concert['absentChoristes'] as List?)
                  ?.any((a) => (a['choriste']?['_id'] ?? a) == userId) ??
              false) {
            _statusMap[id] = 'absent';
          } else if (isPast) {
            _statusMap[id] = 'absent_default';
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    }
  }

  // ── Actions ──

  Future<void> _markRepetition(String id, bool present) async {
    if (!present) {
      final reason = await _showReasonDialog();
      if (reason == null || reason.isEmpty) return;
      try {
        await _service.markRepetitionAbsence(id, reason);
        setState(() => _statusMap[id] = 'absent');
        if (!mounted) return;
        _showSnackBar('Absence déclarée', const Color(0xFFEF4444));
      } on DioException catch (e) {
        if (!mounted) return;
        final msg = _extractErrorMessage(e) ?? 'Erreur lors de l\'enregistrement';
        _showSnackBar(msg, const Color(0xFFEF4444));
      }
    } else {
      try {
        await _service.markRepetitionPresence(id);
        setState(() => _statusMap[id] = 'present');
        if (!mounted) return;
        _showSnackBar('Présence confirmée ✅', const Color(0xFF22C55E));
      } on DioException catch (e) {
        if (!mounted) return;
        final msg = _extractErrorMessage(e) ?? 'Erreur lors de l\'enregistrement';
        _showSnackBar(msg, const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _markConcert(String id, bool available) async {
    try {
      await _service.markConcertAvailability(id, available);
      setState(() => _statusMap[id] = available ? 'present' : 'absent');
      if (!mounted) return;
      _showSnackBar(
        available ? 'Disponibilité confirmée ✅' : 'Indisponibilité déclarée',
        available ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  String? _extractErrorMessage(DioException e) {
    try {
      return e.response?.data?['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── UI helpers ──

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFF2DD4BF)),
          SizedBox(width: 8),
          Text('Motif d\'absence'),
        ]),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Entrez votre motif...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final date = DateTime.parse(rawDate);
      const months = [
        '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      const days = [
        '', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
      ];
      return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return rawDate;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return CsoUi.screenBody(
      child: Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            indicatorWeight: 2.5,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upcoming_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('À venir (${_upcomingRepetitions.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Historique'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Content ──
        Expanded(
          child: _isLoading
              ? CsoUi.loading()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUpcomingTab(),
                    _buildHistoryTab(),
                  ],
                ),
        ),
      ],
      ),
    );
  }

  // ── Identity banner ──

  Widget _buildIdentityBanner(dynamic user) {
    final pupitreLabel = user.pupitreLabel as String? ?? '';
    final isChef = user.isChefDePupitre as bool? ?? false;
    final pupitreColor = Color(user.pupitreColor as int? ?? 0xFF6B7280);

    if (pupitreLabel.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: pupitreColor.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: pupitreColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: pupitreColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.music_note_rounded, color: pupitreColor, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            pupitreLabel,
            style: TextStyle(
              color: pupitreColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          if (isChef)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text('Chef de pupitre',
                      style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Upcoming tab ──

  Widget _buildUpcomingTab() {
    final upcoming = _upcomingRepetitions;
    if (upcoming.isEmpty) {
      return _buildEmptyState(
          'Aucune répétition à venir cette semaine', Icons.event_available_rounded);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: upcoming.length,
        itemBuilder: (context, index) =>
            _buildRepetitionCard(upcoming[index], isHistory: false),
      ),
    );
  }

  // ── History tab ──

  bool _isHistoryPresent(dynamic rep) {
    final id = rep['_id'] as String;
    return _statusMap[id] == 'present';
  }

  Widget _buildHistorySectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    bool expanded = false,
    bool collapsible = false,
    VoidCallback? onToggle,
  }) {
    final content = Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.subtitle.copyWith(fontSize: 15),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.label.copyWith(color: color),
          ),
        ),
        if (collapsible) ...[
          const SizedBox(width: 6),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: color,
            size: 22,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: collapsible
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }

  Widget _buildCollapsibleHistorySection({
    required String title,
    required List<dynamic> reps,
    required IconData icon,
    required Color color,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    if (reps.isEmpty) return const SizedBox.shrink();

    final collapsible = reps.length > 1;
    final visible = expanded || !collapsible ? reps : reps.take(1).toList();
    final hidden = reps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHistorySectionHeader(
          title: title,
          count: reps.length,
          icon: icon,
          color: color,
          expanded: expanded,
          collapsible: collapsible,
          onToggle: onToggle,
        ),
        for (final rep in visible)
          _buildRepetitionCard(rep, isHistory: true),
        if (collapsible)
          Center(
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
              label: Text(
                expanded
                    ? 'Réduire'
                    : 'Voir $hidden autre${hidden > 1 ? 's' : ''}',
                style: AppTextStyles.label.copyWith(color: color),
              ),
              style: TextButton.styleFrom(foregroundColor: color),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final history = _historyRepetitions;
    if (history.isEmpty) {
      return _buildEmptyState(
          'Aucun historique disponible', Icons.history_rounded);
    }

    final present =
        history.where(_isHistoryPresent).toList(growable: false);
    final absent = history.where((r) => !_isHistoryPresent(r)).toList();

    final children = <Widget>[];

    if (present.isNotEmpty) {
      children.add(
        _buildCollapsibleHistorySection(
          title: 'Présences confirmées',
          reps: present,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          expanded: _historyPresentExpanded,
          onToggle: () => setState(
            () => _historyPresentExpanded = !_historyPresentExpanded,
          ),
        ),
      );
      if (absent.isNotEmpty) {
        children.add(const SizedBox(height: 20));
      }
    }

    if (absent.isNotEmpty) {
      children.add(
        _buildCollapsibleHistorySection(
          title: 'Absences',
          reps: absent,
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          expanded: _historyAbsentExpanded,
          onToggle: () =>
              setState(() => _historyAbsentExpanded = !_historyAbsentExpanded),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: children,
      ),
    );
  }

  // ── Repetition card ──

  Widget _buildRepetitionCard(dynamic rep, {required bool isHistory}) {
    final id = rep['_id'] as String;
    final status = _statusMap[id];
    final insideWindow = _isInsideWindow(rep);
    final date = _parseDate(rep['date']);
    final isToday = date != null && _isSameDay(date, DateTime.now());
    final isLive = isToday && insideWindow && status == null;

    Color accentColor;
    switch (status) {
      case 'present':
        accentColor = AppColors.success;
        break;
      case 'absent':
        accentColor = AppColors.error;
        break;
      case 'absent_default':
        accentColor = AppColors.textMuted;
        break;
      default:
        accentColor = isLive ? AppColors.success : AppColors.repAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CsoUi.card(
        accent: isLive ? AppColors.success : accentColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.repAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.library_music_outlined,
                  color: AppColors.repAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Répétition', style: AppTextStyles.subtitle),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.repAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Aujourd'hui",
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (rep['concert']?['title'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        rep['concert']['title'],
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusBadge(status, isLive),
            ],
          ),
          const SizedBox(height: 12),
          CsoUi.infoRow(
            Icons.calendar_today_outlined,
            _formatDate(rep['date']),
          ),
          if (rep['startTime'] != null)
            CsoUi.infoRow(
              Icons.access_time_outlined,
              '${rep['startTime']} – ${rep['endTime'] ?? ''}',
            ),
          if (rep['location'] != null)
            CsoUi.infoRow(Icons.location_on_outlined, rep['location']),
          if (isToday && status == null && !insideWindow) ...[
            const SizedBox(height: 4),
            Text(
              _windowHint(rep),
              style: AppTextStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildRepetitionActions(
            id,
            rep,
            status,
            isHistory,
            isToday,
            insideWindow,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status, bool isLive) {
    switch (status) {
      case 'present':
        return CsoUi.statusBadge('Présent', AppColors.success, AppColors.successBg);
      case 'absent':
        return CsoUi.statusBadge('Absent', AppColors.error, AppColors.errorBg);
      case 'absent_default':
        return CsoUi.statusBadge('Absent', AppColors.error, AppColors.errorBg);
      default:
        return isLive
            ? CsoUi.statusBadge('En cours', AppColors.success, AppColors.successBg)
            : CsoUi.statusBadge(
                'En attente',
                AppColors.warning,
                AppColors.warningBg,
              );
    }
  }

  Widget _buildRepetitionActions(
    String id,
    dynamic rep,
    String? status,
    bool isHistory,
    bool isToday,
    bool insideWindow,
  ) {
    // History: always locked
    if (isHistory) {
      return _buildLockedBanner(status);
    }

    // Already marked → show lock with option to change (only if window open)
    if (status != null && status != 'absent_default') {
      if (isToday && insideWindow) {
        // Allow changing during the window
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _statusMap.remove(id)),
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        );
      }
      return _buildLockedBanner(status);
    }

    // absent_default (past, not today) → locked
    if (status == 'absent_default') {
      return _buildLockedBanner(status);
    }

    // No status yet — future date
    if (!isToday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'Le pointage s\'ouvrira le jour J',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    // Today, inside window → show buttons
    if (insideWindow) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markRepetition(id, true),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Présent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markRepetition(id, false),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Absent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    // Today but outside window (before start or after end)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_rounded,
              size: 14, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(
            _windowHint(rep),
            style:
                const TextStyle(color: Color(0xFFD97706), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner(String? status) {
    String msg;
    Color color;

    switch (status) {
      case 'present':
        msg = 'Présence confirmée — modification impossible';
        color = const Color(0xFF22C55E);
        break;
      case 'absent':
        msg = 'Absence déclarée — modification impossible';
        color = const Color(0xFFEF4444);
        break;
      case 'absent_default':
        msg = 'Absent — pointage non effectué';
        color = const Color(0xFFEF4444);
        break;
      default:
        msg = 'Passé — modification impossible';
        color = const Color(0xFF6B7280);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(msg, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return CsoUi.emptyState(message: message, icon: icon);
  }
}