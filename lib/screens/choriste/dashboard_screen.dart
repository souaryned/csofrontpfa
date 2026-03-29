import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';
import 'presences_screen.dart';
import 'programme_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ChoristeService _service = ChoristeService();
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _allRepetitions = [];
  List<dynamic> _allConcerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _service.getChoristeDashboard();
      final reps = await _service.getRepetitions();
      final concerts = await _service.getConcerts();
      setState(() {
        _dashboardData = data;
        _allRepetitions = reps;
        _allConcerts = concerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try { return DateTime.parse(raw.toString()).toLocal(); } catch (_) { return null; }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _endOfWeek(DateTime d) {
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return start.add(const Duration(days: 6));
  }

  String _formatDate(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }

  // Répétitions à venir cette semaine
  List<dynamic> get _weekRepetitions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = _endOfWeek(now);
    return _allRepetitions.where((r) {
      final d = _parseDate(r['date']);
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(today) && !day.isAfter(weekEnd);
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a['date']) ?? DateTime(2099);
        final db = _parseDate(b['date']) ?? DateTime(2099);
        return da.compareTo(db);
      });
  }

  // Prochains concerts
  List<dynamic> get _upcomingConcerts {
    final now = DateTime.now();
    return _allConcerts.where((c) {
      final d = _parseDate(c['dateHeure']);
      return d != null && d.isAfter(now);
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a['dateHeure']) ?? DateTime(2099);
        final db = _parseDate(b['dateHeure']) ?? DateTime(2099);
        return da.compareTo(db);
      });
  }

  // Statut répétition
  String _repStatus(dynamic rep, String userId) {
    final manual = (rep['manualPresences'] as List?)?.firstWhere(
      (m) => (m['choriste']?['_id'] ?? m['choriste']) == userId,
      orElse: () => null,
    );
    if (manual != null) return manual['type'] == 'present' ? 'present' : 'absent';
    final present = (rep['presentChoristes'] as List?)
        ?.any((c) => (c['_id'] ?? c) == userId) ?? false;
    if (present) return 'present';
    final absent = (rep['absentChoristes'] as List?)
        ?.any((a) => (a['choriste']?['_id'] ?? a['choriste']) == userId) ?? false;
    if (absent) return 'absent';
    final d = _parseDate(rep['date']);
    if (d != null && !_isSameDay(d, DateTime.now()) && d.isBefore(DateTime.now()))
      return 'absent_default';
    return 'pending';
  }

  // Taux de présence
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final userId = user?.id ?? '';
    final taux = _tauxPresence(userId);
    final nextConcert = _upcomingConcerts.isNotEmpty ? _upcomingConcerts.first : null;
    final weekReps = _weekRepetitions;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF2DD4BF),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header CSO ──
                  _buildHeader(user),
                  const SizedBox(height: 20),

                  // ── Taux de présence (1 seule carte large) ──
                  _buildPresenceCard(taux, userId),
                  const SizedBox(height: 14),

                  // ── Prochain concert ──
                  if (nextConcert != null) ...[
                    _buildNextConcertCard(nextConcert, userId),
                    const SizedBox(height: 20),
                  ],

                  // ── Répétitions cette semaine ──
                  _buildSectionTitle('Répétitions cette semaine',
                      Icons.event_note_rounded, const Color(0xFF2DD4BF)),
                  const SizedBox(height: 12),
                  _buildWeekRepetitions(weekReps, userId),
                  const SizedBox(height: 20),


                ],
              ),
            ),
    );
  }

  // ── Header CSO compact ──
  Widget _buildHeader(dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/logo.png',
                width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF2DD4BF), Color(0xFF60A5FA)],
                ).createShader(bounds),
                child: const Text('CSO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        height: 1)),
              ),
              const SizedBox(height: 2),
              const Text('Carthage Symphony Orchestra',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 9, letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Carte taux de présence ──
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

    // Nombre de répétitions passées
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
              color: color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Cercle de progression
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: taux / 100,
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text('$taux%',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taux de présence',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$present répétition${present > 1 ? 's' : ''} sur $total assistée${present > 1 ? 's' : ''}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Prochain concert (carte mise en avant) ──
  Widget _buildNextConcertCard(dynamic concert, String userId) {
    final d = _parseDate(concert['dateHeure']);
    final daysLeft = d != null ? d.difference(DateTime.now()).inDays : null;

    final dispo = (concert['availableChoristes'] as List?)
        ?.any((c) => (c['_id'] ?? c) == userId) ?? false;
    final indispo = (concert['absentChoristes'] as List?)
        ?.any((a) => (a['choriste']?['_id'] ?? a) == userId) ?? false;

    String statusLabel = 'À confirmer';
    Color statusColor = const Color(0xFFF59E0B);
    Color statusBg = const Color(0xFFFFFBEB);
    if (dispo) { statusLabel = '✓ Disponible'; statusColor = const Color(0xFF16A34A); statusBg = const Color(0xFFDCFCE7); }
    if (indispo) { statusLabel = '✗ Indisponible'; statusColor = const Color(0xFFDC2626); statusBg = const Color(0xFFFEE2E2); }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Programme de la saison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
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
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Countdown
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                      height: 1),
                ),
                const Text('jours',
                    style: TextStyle(color: Colors.white54, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prochain concert',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(concert['title'] ?? 'Concert',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(_formatDate(concert['dateHeure']),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ]),
                if (concert['location'] != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 11, color: Colors.white38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(concert['location'],
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),  // end GestureDetector child Container
    );  // end GestureDetector
  }

  // ── Section title ──
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937))),
      ],
    );
  }

  // ── Répétitions cette semaine ──
  Widget _buildWeekRepetitions(List<dynamic> reps, String userId) {
    if (reps.isEmpty) {
      return _buildEmptyCard(
          'Aucune répétition cette semaine', Icons.event_note_rounded, const Color(0xFF2DD4BF));
    }
    return Column(
      children: reps.map((rep) {
        final status = _repStatus(rep, userId);
        final d = _parseDate(rep['date']);
        final isToday = d != null && _isSameDay(d, DateTime.now());

        Color accentColor;
        String statusLabel;
        Color statusBg;
        switch (status) {
          case 'present':
            accentColor = const Color(0xFF22C55E);
            statusLabel = '✓ Présent';
            statusBg = const Color(0xFFDCFCE7);
            break;
          case 'absent':
            accentColor = const Color(0xFFEF4444);
            statusLabel = '✗ Absent';
            statusBg = const Color(0xFFFEE2E2);
            break;
          default:
            accentColor = const Color(0xFFF59E0B);
            statusLabel = 'En attente';
            statusBg = const Color(0xFFFFFBEB);
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Gérer les présences',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  shadowColor: Colors.black12,
                  surfaceTintColor: Colors.white,
                  iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
                ),
                body: const PresencesScreen(),
              ),
            ),
          ),
          child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isToday
                ? Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              // Icône avec badge Aujourd'hui
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.library_music_rounded,
                        color: Color(0xFF2DD4BF), size: 20),
                  ),
                  if (isToday)
                    Positioned(
                      top: -6, right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2DD4BF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Auj.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Répétition',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1F2937))),
                    if (rep['concert']?['title'] != null) ...[
                      const SizedBox(height: 2),
                      Text(rep['concert']['title'],
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
  spacing: 10,
  runSpacing: 2,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_today_rounded,
          size: 11, color: Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text(_formatDate(rep['date']),
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 11)),
    ]),
    Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.access_time_rounded,
          size: 11, color: Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text('${rep['startTime']} – ${rep['endTime']}',
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 11)),
    ]),
  ],
),
                    if (rep['location'] != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(rep['location'],
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 11)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
        ); // end GestureDetector
      }).toList(),
    );
  }

  // ── Prochains concerts ──
  Widget _buildUpcomingConcerts(String userId) {
    final concerts = _upcomingConcerts.take(3).toList();
    if (concerts.isEmpty) {
      return _buildEmptyCard(
          'Aucun concert à venir', Icons.stadium_rounded, const Color(0xFF8B5CF6));
    }
    return Column(
      children: concerts.map((concert) {
        final d = _parseDate(concert['dateHeure']);
        final daysLeft = d != null ? d.difference(DateTime.now()).inDays : null;

        final dispo = (concert['availableChoristes'] as List?)
            ?.any((c) => (c['_id'] ?? c) == userId) ?? false;
        final indispo = (concert['absentChoristes'] as List?)
            ?.any((a) => (a['choriste']?['_id'] ?? a) == userId) ?? false;
        String statusLabel = 'À confirmer';
        Color statusColor = const Color(0xFFF59E0B);
        Color statusBg = const Color(0xFFFFFBEB);
        if (dispo) { statusLabel = '✓ Dispo'; statusColor = const Color(0xFF16A34A); statusBg = const Color(0xFFDCFCE7); }
        if (indispo) { statusLabel = '✗ Indispo'; statusColor = const Color(0xFFDC2626); statusBg = const Color(0xFFFEE2E2); }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: daysLeft != null
                    ? Center(
                        child: Text('J-$daysLeft',
                            style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontSize: 11,
                                fontWeight: FontWeight.w800)))
                    : const Icon(Icons.celebration_rounded,
                        color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(concert['title'] ?? 'Concert',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(_formatDate(concert['dateHeure']),
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ]),
                    if (concert['location'] != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(concert['location'],
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 11)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyCard(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: color.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}