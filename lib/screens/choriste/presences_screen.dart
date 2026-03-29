import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';

class PresencesScreen extends StatefulWidget {
  const PresencesScreen({super.key});

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

  // ── Repetition split ──
  List<dynamic> get _upcomingRepetitions {
    final now = DateTime.now();
    // "upcoming" = today or future (including in-progress)
    return _repetitions.where((r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      final dayEnd = DateTime(d.year, d.month, d.day, 23, 59, 59);
      return dayEnd.isAfter(now) || _isSameDay(d, now);
    }).toList();
  }

  List<dynamic> get _historyRepetitions {
    final now = DateTime.now();
    return _repetitions.where((r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      return !_isSameDay(d, now) && d.isBefore(now);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

          if (manual != null) {
            _statusMap[id] = manual['type'] == 'present' ? 'present' : 'absent';
          } else if (present) {
            _statusMap[id] = 'present';
          } else if (absent) {
            _statusMap[id] = 'absent';
          } else if (isPast) {
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
    return Column(
      children: [
        // ── Tab bar ──
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2DD4BF),
            indicatorWeight: 3,
            labelColor: const Color(0xFF2DD4BF),
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUpcomingTab(),
                    _buildHistoryTab(),
                  ],
                ),
        ),
      ],
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
      color: const Color(0xFF2DD4BF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: upcoming.length,
        itemBuilder: (context, index) =>
            _buildRepetitionCard(upcoming[index], isHistory: false),
      ),
    );
  }

  // ── History tab ──

  Widget _buildHistoryTab() {
    final history = _historyRepetitions;
    if (history.isEmpty) {
      return _buildEmptyState(
          'Aucun historique disponible', Icons.history_rounded);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // newest first in history
        itemCount: history.length,
        itemBuilder: (context, index) {
          final sorted = [...history]
            ..sort((a, b) => (_parseDate(b['date']) ?? DateTime(0))
                .compareTo(_parseDate(a['date']) ?? DateTime(0)));
          return _buildRepetitionCard(sorted[index], isHistory: true);
        },
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

    // Couleur selon statut
    Color accentColor;
    switch (status) {
      case 'present':  accentColor = const Color(0xFF22C55E); break;
      case 'absent':   accentColor = const Color(0xFFEF4444); break;
      case 'absent_default': accentColor = const Color(0xFF9CA3AF); break;
      default: accentColor = isLive ? const Color(0xFF22C55E) : const Color(0xFF2DD4BF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header coloré fin ──
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Ligne titre + badge statut ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.library_music_rounded,
                          color: accentColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label fixe "Répétition"
                          const Text(
                            'Répétition',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          // Concert associé
                          if (rep['concert']?['title'] != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.album_rounded,
                                    size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    rep['concert']['title'],
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isToday) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("Aujourd'hui",
                                      style: TextStyle(
                                          color: Color(0xFF2DD4BF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (isLive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fiber_manual_record_rounded,
                                            size: 7, color: Color(0xFF16A34A)),
                                        SizedBox(width: 3),
                                        Text('En cours',
                                            style: TextStyle(
                                                color: Color(0xFF16A34A),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Badge statut — unique, clair
                    _buildStatusBadge(status, isLive),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // ── Infos date / heure / lieu ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(_formatDate(rep['date']),
                                style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ]),
                          if (rep['startTime'] != null) ...[
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Text(
                                '${rep['startTime']} – ${rep['endTime'] ?? ''}',
                                style: const TextStyle(
                                    color: Color(0xFF475569), fontSize: 12),
                              ),
                              // Hint ouverture/fermeture
                              if (isToday && status == null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _windowHint(rep),
                                  style: TextStyle(
                                    color: insideWindow
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ]),
                          ],
                          if (rep['location'] != null) ...[
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(rep['location'],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFF475569), fontSize: 12)),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Action area ──
                _buildRepetitionActions(
                    id, rep, status, isHistory, isToday, insideWindow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status, bool isLive) {
    switch (status) {
      case 'present':
        return _badge('✓ Présent', const Color(0xFF16A34A), const Color(0xFFDCFCE7));
      case 'absent':
        return _badge('✗ Absent', const Color(0xFFDC2626), const Color(0xFFFEE2E2));
      case 'absent_default':
        return _badge('Non marqué', const Color(0xFF6B7280), const Color(0xFFF3F4F6));
      default:
        return isLive
            ? _badge('En cours', const Color(0xFF16A34A), const Color(0xFFDCFCE7))
            : _badge('En attente', const Color(0xFFF59E0B), const Color(0xFFFFFBEB));
    }
  }

  Widget _badge(String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
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
                  foregroundColor: const Color(0xFF2DD4BF),
                  side: const BorderSide(color: Color(0xFF2DD4BF)),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7280).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock_rounded, size: 14, color: Color(0xFF9CA3AF)),
            SizedBox(width: 6),
            Text('Le pointage s\'ouvrira le jour J',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
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
        msg = 'Marqué absent automatiquement';
        color = const Color(0xFF6B7280);
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
          Text(msg, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 40,
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }
}