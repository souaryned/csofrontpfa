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
  final ChoristeService _service = ChoristeService();
  final ChefPupitreService _chefService = ChefPupitreService();

  Map<String, dynamic>? _dashboardData;
  List<dynamic> _allRepetitions = [];
  List<dynamic> _allConcerts = [];
  List<dynamic> _messages = []; // ← tous les messages reçus
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data     = await _service.getChoristeDashboard();
      final reps     = await _service.getRepetitions();
      final concerts = await _service.getConcerts();

      List<dynamic> msgs = [];
      try {
        msgs = await _chefService.getChoristMessages();
      } catch (_) {}

      setState(() {
        _dashboardData   = data;
        _allRepetitions  = reps;
        _allConcerts     = concerts;
        _messages        = msgs;
        _isLoading       = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try { return DateTime.parse(raw.toString()).toLocal(); } catch (_) { return null; }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }

  String _formatDateShort(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return '';
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${date.day} ${months[date.month]}';
  }

  String _formatMsgDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw.toString()).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
      return _formatDateShort(raw);
    } catch (_) { return ''; }
  }

  // ── Répétitions À VENIR uniquement (pas de passées) ──
  List<dynamic> get _upcomingRepetitions {
    final now   = DateTime.now();
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

    return _allRepetitions
        .where((r) => !isFinished(r))
        .toList()
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

  // Statut présence
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

  // Couleur pupitre
  Color _pupitreColor(String p) {
    switch (p) {
      case 'soprano': return const Color(0xFF7C3AED);
      case 'alto':    return const Color(0xFF0891B2);
      case 'ténor':   return const Color(0xFF059669);
      case 'basse':   return const Color(0xFFB45309);
      default:        return const Color(0xFF6B7280);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user   = context.watch<AuthProvider>().user;
    final userId = user?.id ?? '';
    final taux   = _tauxPresence(userId);
    final upcomingReps = _upcomingRepetitions;

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

                  // ── Header CSO ──────────────────────────────────────────
                  _buildHeader(user),
                  const SizedBox(height: 16),

                  // ── Taux de présence ───────────────────────────────────
                  _buildPresenceCard(taux, userId),
                  const SizedBox(height: 20),

                  // ── Section : Répétitions à venir ──────────────────────
                  _buildSectionTitle(
                    'Répétitions à venir',
                    Icons.event_note_rounded,
                    const Color(0xFF2DD4BF),
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingRepetitions(upcomingReps, userId),
                  const SizedBox(height: 20),

                  // ── Section : Messages non lus ─────────────────────────
                  _buildMessagesSectionTitle(user),
                  const SizedBox(height: 12),
                  _buildMessagesSection(user),
                  const SizedBox(height: 20),

                  // ── Section : Prochains concerts ────────────────────────
                  _buildSectionTitle(
                    'Prochains concerts',
                    Icons.stadium_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingConcerts(userId),

                ],
              ),
            ),
    );
  }

  // ── Header CSO ─────────────────────────────────────────────────────────────
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

  // ── Taux de présence ───────────────────────────────────────────────────────
  Widget _buildPresenceCard(int taux, String userId) {
    Color color;
    String label;
    IconData icon;
    if (taux >= 80) {
      color = const Color(0xFF22C55E);
      label = 'Excellente assiduité';
      icon  = Icons.emoji_events_rounded;
    } else if (taux >= 60) {
      color = const Color(0xFFF59E0B);
      label = 'Assiduité correcte';
      icon  = Icons.trending_up_rounded;
    } else {
      color = const Color(0xFFEF4444);
      label = 'Assiduité insuffisante';
      icon  = Icons.warning_amber_rounded;
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
              color: color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72, height: 72,
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
                        color: color, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Taux de présence',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(
                  '$present répétition${present > 1 ? 's' : ''} sur $total assistée${total > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Répétitions à venir ────────────────────────────────────────────────────
  Widget _buildUpcomingRepetitions(List<dynamic> reps, String userId) {
    if (reps.isEmpty) {
      return _buildEmptyCard(
        'Aucune répétition à venir',
        Icons.event_note_rounded,
        const Color(0xFF2DD4BF),
      );
    }

    return Column(
      children: reps.take(5).map((rep) {
        final d       = _parseDate(rep['date']);
        final now     = DateTime.now();
        final isToday = d != null && _isSameDay(d, now);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Gérer les présences',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  shadowColor: Colors.black12,
                  surfaceTintColor: Colors.white,
                  iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
                ),
                body: const PresencesScreen(initialTab: 0),
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
                  ? Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.5), width: 1.5)
                  : Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                // Icone + badge Aujourd'hui
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44, height: 44,
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
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('Auj.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Détails
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rep['concert']?['title'] != null
                            ? 'Répétition · ${rep['concert']['title']}'
                            : 'Répétition',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1F2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
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
                // Badge À venir
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isToday ? 'Aujourd\'hui' : 'À venir',
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Titre section messages avec badge non lus ────────────────────────────
  Widget _buildMessagesSectionTitle(dynamic user) {
    final pColor = _pupitreColor(user?.pupitre ?? '');
    final unreadCount = _messages.where((m) => m['readAt'] == null).length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: pColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.mark_chat_read_rounded, size: 15, color: pColor),
        ),
        const SizedBox(width: 10),
        const Text('Messages non lus',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        if (unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: pColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$unreadCount',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  // ── Section Messages ───────────────────────────────────────────────────────
  Widget _buildMessagesSection(dynamic user) {
    final pupitre = user?.pupitre as String? ?? '';
    final pColor  = _pupitreColor(pupitre);

    // Filtrer uniquement les messages non lus
    final unreadMessages = _messages.where((m) => m['readAt'] == null).toList();

    // Toujours afficher le container — avec messages non lus ou état vide
    if (unreadMessages.isEmpty) {
      // État vide sobre
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mark_chat_read_rounded,
                  color: Color(0xFFCBD5E1), size: 20),
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

    // Afficher les 3 derniers messages
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
                      : pColor.withValues(alpha: 0.35),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  // Avatar expéditeur
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: pColor.withValues(alpha: 0.1),
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
                            fontSize: 14),
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
                            const Icon(Icons.star_rounded,
                                size: 11, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              '${sender?['firstName'] ?? ''} ${sender?['lastName'] ?? ''} · Chef',
                              style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
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
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
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
                      Text(_formatMsgDate(msg['createdAt']),
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1), fontSize: 10)),
                      const SizedBox(height: 6),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: pColor, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        // Bouton "Voir tous" si plus de 3
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
                color: pColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pColor.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  'Voir tous les messages (${_messages.length})',
                  style: TextStyle(
                      color: pColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Prochains concerts ─────────────────────────────────────────────────────
  Widget _buildUpcomingConcerts(String userId) {
    final concerts = _upcomingConcerts.take(3).toList();
    if (concerts.isEmpty) {
      return _buildEmptyCard(
          'Aucun concert à venir',
          Icons.stadium_rounded,
          const Color(0xFF8B5CF6));
    }
    return Column(
      children: concerts.map((concert) {
        final d        = _parseDate(concert['dateHeure']);
        final daysLeft = d != null ? d.difference(DateTime.now()).inDays : null;

        final dispo   = (concert['availableChoristes'] as List?)
            ?.any((c) => (c['_id'] ?? c) == userId) ?? false;
        final indispo = (concert['absentChoristes'] as List?)
            ?.any((a) => (a['choriste']?['_id'] ?? a) == userId) ?? false;
        String statusLabel = 'À confirmer';
        Color  statusColor = const Color(0xFFF59E0B);
        Color  statusBg    = const Color(0xFFFFFBEB);
        if (dispo)   { statusLabel = '✓ Dispo';   statusColor = const Color(0xFF16A34A); statusBg = const Color(0xFFDCFCE7); }
        if (indispo) { statusLabel = '✗ Indispo'; statusColor = const Color(0xFFDC2626); statusBg = const Color(0xFFFEE2E2); }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Programme de la saison',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
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
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
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
                      const SizedBox(height: 4),
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
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────
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

  // ── Empty card ─────────────────────────────────────────────────────────────
  Widget _buildEmptyCard(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07), shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: color.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ],
      ),
    );
  }
}