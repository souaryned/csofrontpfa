import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/choriste_service.dart';

class ProgrammeScreen extends StatefulWidget {
  const ProgrammeScreen({super.key});

  @override
  State<ProgrammeScreen> createState() => _ProgrammeScreenState();
}

class _ProgrammeScreenState extends State<ProgrammeScreen> {
  final ChoristeService _service = ChoristeService();
  List<dynamic> _concerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final concerts = await _service.getConcerts();
      setState(() {
        _concerts = concerts;
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
      const months = [
        '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      const days = [
        '', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
      ];
      final hour = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year} à $hour:$min';
    } catch (e) {
      return rawDate;
    }
  }

  bool _isPast(String? rawDate) {
    if (rawDate == null) return false;
    try {
      return DateTime.parse(rawDate).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _buildPosterUrl(String? poster) {
    if (poster == null || poster.isEmpty) return '';
    if (poster.startsWith('/uploads')) {
      return '${ApiConfig.baseUrl}$poster';
    }
    return '${ApiConfig.baseUrl}/uploads/posters/$poster';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2DD4BF),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : _concerts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _concerts.length,
                  itemBuilder: (context, index) {
                    return _buildConcertCard(_concerts[index]);
                  },
                ),
    );
  }

  Widget _buildConcertCard(dynamic concert) {
    final String? poster = concert['poster'];
    final String posterUrl = _buildPosterUrl(poster);
    final bool hasPoster = posterUrl.isNotEmpty;
    final bool isPast = _isPast(concert['dateHeure']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Poster ──
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                hasPoster
                    ? Image.network(
                        posterUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildPosterPlaceholder();
                        },
                      )
                    : _buildPosterPlaceholder(),
                // Badge passé / à venir
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPast
                          ? Colors.black.withValues(alpha: 0.6)
                          : const Color(0xFF2DD4BF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPast ? 'Passé' : 'À venir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Infos ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concert['title'] ?? 'Concert',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDate(concert['dateHeure']),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (concert['location'] != null &&
                    concert['location'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Color(0xFF9B8EC4)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          concert['location'],
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: Color(0xFF2DD4BF),
              size: 36,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Affiche non disponible',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: Icon(
              Icons.celebration_rounded,
              size: 40,
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucun concert programmé',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
        ],
      ),
    );
  }
}