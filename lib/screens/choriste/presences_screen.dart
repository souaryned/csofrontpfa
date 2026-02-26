import 'package:flutter/material.dart';
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
  Map<String, String> _statusMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final reps = await _service.getRepetitions();
      final concerts = await _service.getConcerts();
      setState(() {
        _repetitions = reps;
        _concerts = concerts;
        _isLoading = false;

        // Init status répétitions
        for (var rep in reps) {
          final id = rep['_id'];
          final isPast = _isPastDate(rep['date']);
          if (rep['presentChoristes'] != null &&
              (rep['presentChoristes'] as List).isNotEmpty) {
            _statusMap[id] = 'present';
          } else if (rep['absentChoristes'] != null &&
              (rep['absentChoristes'] as List).isNotEmpty) {
            _statusMap[id] = 'absent';
          } else if (isPast) {
            // Date dépassée et rien marqué → absent par défaut
            _statusMap[id] = 'absent_default';
          }
        }

        // Init status concerts
        for (var concert in concerts) {
          final id = concert['_id'];
          final isPast = _isPastDate(concert['dateHeure']);
          if (concert['availableChoristes'] != null &&
              (concert['availableChoristes'] as List).isNotEmpty) {
            _statusMap[id] = 'present';
          } else if (concert['absentChoristes'] != null &&
              (concert['absentChoristes'] as List).isNotEmpty) {
            _statusMap[id] = 'absent';
          } else if (isPast) {
            _statusMap[id] = 'absent_default';
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isPastDate(String? rawDate) {
    if (rawDate == null) return false;
    try {
      return DateTime.parse(rawDate).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> _markRepetition(String id, bool present) async {
    if (!present) {
      final reason = await _showReasonDialog();
      if (reason == null || reason.isEmpty) return;
      try {
        await _service.markRepetitionAbsence(id, reason);
        setState(() => _statusMap[id] = 'absent');
        if (!mounted) return;
        _showSnackBar('Absence déclarée', const Color(0xFFEF4444));
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    } else {
      try {
        await _service.markRepetitionPresence(id);
        setState(() => _statusMap[id] = 'present');
        if (!mounted) return;
        _showSnackBar('Présence confirmée ✅', const Color(0xFF22C55E));
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
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
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2DD4BF)),
            SizedBox(width: 8),
            Text('Motif d\'absence'),
          ],
        ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar stylisé
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2DD4BF),
            indicatorWeight: 3,
            labelColor: const Color(0xFF2DD4BF),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Répétitions'),
              Tab(text: 'Concerts'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRepetitionsList(),
                    _buildConcertsList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRepetitionsList() {
    if (_repetitions.isEmpty) {
      return _buildEmptyState('Aucune répétition', Icons.library_music_rounded);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _repetitions.length,
        itemBuilder: (context, index) {
          final rep = _repetitions[index];
          final id = rep['_id'];
          final status = _statusMap[id];
          final isPast = _isPastDate(rep['date']);
          return _buildRepetitionCard(rep, id, status, isPast);
        },
      ),
    );
  }

  Widget _buildConcertsList() {
    if (_concerts.isEmpty) {
      return _buildEmptyState('Aucun concert', Icons.celebration_rounded);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _concerts.length,
        itemBuilder: (context, index) {
          final concert = _concerts[index];
          final id = concert['_id'];
          final status = _statusMap[id];
          final isPast = _isPastDate(concert['dateHeure']);
          return _buildConcertCard(concert, id, status, isPast);
        },
      ),
    );
  }

  Widget _buildRepetitionCard(
      dynamic rep, String id, String? status, bool isPast) {
    // Déterminer couleurs et labels selon statut
    Color headerColor;
    Color bgColor;
    String statusLabel;
    IconData statusIcon;
    Color statusBadgeColor;

    if (status == 'present') {
      headerColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFF0FDF4);
      statusLabel = 'Présent';
      statusIcon = Icons.check_circle_rounded;
      statusBadgeColor = const Color(0xFF16A34A);
    } else if (status == 'absent') {
      headerColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFFF1F1);
      statusLabel = 'Absent';
      statusIcon = Icons.cancel_rounded;
      statusBadgeColor = const Color(0xFFDC2626);
    } else if (status == 'absent_default') {
      headerColor = const Color(0xFF6B7280);
      bgColor = const Color(0xFFF9FAFB);
      statusLabel = 'Absent (auto)';
      statusIcon = Icons.remove_circle_outline_rounded;
      statusBadgeColor = const Color(0xFF6B7280);
    } else {
      headerColor = const Color(0xFF2DD4BF);
      bgColor = Colors.white;
      statusLabel = 'Non marqué';
      statusIcon = Icons.radio_button_unchecked_rounded;
      statusBadgeColor = const Color(0xFF2DD4BF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: headerColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rep['location'] ?? 'Lieu non défini',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Badge statut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(rep['date']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    // Badge "Passé" si date dépassée
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B7280).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Passé',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                if (rep['startTime'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: Color(0xFF9B8EC4)),
                      const SizedBox(width: 8),
                      Text(
                        '${rep['startTime']} → ${rep['endTime'] ?? ''}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                // Boutons selon état
                if (isPast && status == 'absent_default')
                  // Absent automatique — aucune action
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Color(0xFF6B7280)),
                        SizedBox(width: 6),
                        Text(
                          'Marqué absent automatiquement',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else if (isPast && status != null)
                  // Date passée + déjà marqué → pas de modification
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: statusBadgeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusBadgeColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 14, color: statusBadgeColor),
                        const SizedBox(width: 6),
                        Text(
                          'Répétition passée — modification impossible',
                          style: TextStyle(
                              color: statusBadgeColor, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else if (status == null)
                  // Pas encore marqué + date future → boutons
                  Row(
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
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Déjà marqué + date future → bouton modifier
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _statusMap.remove(id)),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: headerColor,
                        side: BorderSide(color: headerColor),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcertCard(
      dynamic concert, String id, String? status, bool isPast) {
    Color headerColor;
    Color bgColor;
    String statusLabel;
    IconData statusIcon;
    Color statusBadgeColor;

    if (status == 'present') {
      headerColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFF0FDF4);
      statusLabel = 'Disponible';
      statusIcon = Icons.check_circle_rounded;
      statusBadgeColor = const Color(0xFF16A34A);
    } else if (status == 'absent') {
      headerColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFFF1F1);
      statusLabel = 'Indisponible';
      statusIcon = Icons.cancel_rounded;
      statusBadgeColor = const Color(0xFFDC2626);
    } else if (status == 'absent_default') {
      headerColor = const Color(0xFF6B7280);
      bgColor = const Color(0xFFF9FAFB);
      statusLabel = 'Absent (auto)';
      statusIcon = Icons.remove_circle_outline_rounded;
      statusBadgeColor = const Color(0xFF6B7280);
    } else {
      headerColor = const Color(0xFF9B8EC4);
      bgColor = Colors.white;
      statusLabel = 'Non marqué';
      statusIcon = Icons.radio_button_unchecked_rounded;
      statusBadgeColor = const Color(0xFF9B8EC4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: headerColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    concert['title'] ?? 'Concert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(concert['dateHeure']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B7280).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Passé',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                if (concert['location'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Color(0xFF9B8EC4)),
                      const SizedBox(width: 8),
                      Text(
                        concert['location'],
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (isPast && status == 'absent_default')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Color(0xFF6B7280)),
                        SizedBox(width: 6),
                        Text(
                          'Marqué absent automatiquement',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else if (isPast && status != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: statusBadgeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusBadgeColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 14, color: statusBadgeColor),
                        const SizedBox(width: 6),
                        Text(
                          'Concert passé — modification impossible',
                          style: TextStyle(
                              color: statusBadgeColor, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else if (status == null)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _markConcert(id, true),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Disponible'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _markConcert(id, false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Indisponible'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _statusMap.remove(id)),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: headerColor,
                        side: BorderSide(color: headerColor),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
              style:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }
}