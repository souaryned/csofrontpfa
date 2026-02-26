import 'package:flutter/material.dart';
import '../../services/choriste_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ChoristeService _service = ChoristeService();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _service.getChoristeDashboard();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final date = DateTime.parse(rawDate);
      const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF2DD4BF),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // ✅ BLOC CSO — propre, sous-titre bien visible
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Logo rempli sans espace
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ CSO en dégradé teal→bleu
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF2DD4BF), Color(0xFF60A5FA)],
                              ).createShader(bounds),
                              child: const Text(
                                'CSO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // ✅ Sous-titre blanc bien visible
                            const Text(
                              'Carthage Symphony Orchestra',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Icône décorative
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF2DD4BF),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.celebration_rounded,
                          color: const Color(0xFF3B82F6),
                          bgColor: const Color(0xFFEFF6FF),
                          label: 'Concerts',
                          sublabel: 'Participés',
                          value: '${_dashboardData?['statistics']?['totalConcerts'] ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.library_music_rounded,
                          color: const Color(0xFF2DD4BF),
                          bgColor: const Color(0xFFF0FDFA),
                          label: 'Répétitions',
                          sublabel: 'Assistées',
                          value: '${_dashboardData?['statistics']?['totalRepetitions'] ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Mes dernières répétitions', const Color(0xFF2DD4BF)),
                  const SizedBox(height: 12),
                  _buildRepetitionsList(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Mes concerts participés', const Color(0xFF3B82F6)),
                  const SizedBox(height: 12),
                  _buildConcertsList(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required String sublabel,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          Text(sublabel, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRepetitionsList() {
    final reps = _dashboardData?['repetitionsAttended'] as List?;
    if (reps == null || reps.isEmpty) {
      return _buildEmptyCard('Aucune répétition assistée', Icons.library_music_rounded, const Color(0xFF2DD4BF));
    }
    return Column(
      children: reps.take(3).map((rep) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.library_music_rounded, color: Color(0xFF2DD4BF), size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rep['concert']?['title'] ?? 'Répétition', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_formatDate(rep['date']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                child: const Text('✓ Présent', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConcertsList() {
    final concerts = _dashboardData?['concertsParticipated'] as List?;
    if (concerts == null || concerts.isEmpty) {
      return _buildEmptyCard('Aucun concert participé', Icons.celebration_rounded, const Color(0xFF3B82F6));
    }
    return Column(
      children: concerts.take(3).map((concert) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.celebration_rounded, color: Color(0xFF3B82F6), size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(concert['title'] ?? 'Concert', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_formatDate(concert['dateHeure']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                    if (concert['location'] != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.location_on, size: 11, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(concert['location'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(icon, size: 32, color: color.withValues(alpha: 0.4))),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}