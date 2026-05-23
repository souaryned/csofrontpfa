import 'package:flutter/material.dart';
import '../../services/choriste_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/concert_cards.dart';
import '../../widgets/cso_ui.dart';

enum _ProgrammeFilter { all, upcoming, past }

class ProgrammeScreen extends StatefulWidget {
  const ProgrammeScreen({super.key});

  @override
  State<ProgrammeScreen> createState() => _ProgrammeScreenState();
}

class _ProgrammeScreenState extends State<ProgrammeScreen> {
  final ChoristeService _service = ChoristeService();

  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  bool _isLoading = true;
  _ProgrammeFilter _filter = _ProgrammeFilter.all;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final concerts = await _service.getConcerts();
      final now = DateTime.now();

      final upcoming = concerts.where((c) {
        try {
          return DateTime.parse(c['dateHeure']).isAfter(now);
        } catch (_) {
          return false;
        }
      }).toList()
        ..sort((a, b) {
          final da = DateTime.tryParse(a['dateHeure'] ?? '') ?? DateTime(2099);
          final db = DateTime.tryParse(b['dateHeure'] ?? '') ?? DateTime(2099);
          return da.compareTo(db);
        });

      final past = concerts.where((c) {
        try {
          return !DateTime.parse(c['dateHeure']).isAfter(now);
        } catch (_) {
          return true;
        }
      }).toList()
        ..sort((a, b) {
          final da = DateTime.tryParse(a['dateHeure'] ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['dateHeure'] ?? '') ?? DateTime(0);
          return db.compareTo(da);
        });

      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _past = past;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _visibleUpcoming {
    if (_filter == _ProgrammeFilter.past) return [];
    return _upcoming;
  }

  List<dynamic> get _visiblePast {
    if (_filter == _ProgrammeFilter.upcoming) return [];
    return _past;
  }

  bool get _isEmpty =>
      _visibleUpcoming.isEmpty && _visiblePast.isEmpty && !_isLoading;

  @override
  Widget build(BuildContext context) {
    return CsoUi.screenBody(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.concertAccent,
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(child: _buildFilterChips()),
                      if (_filter != _ProgrammeFilter.past &&
                          _visibleUpcoming.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionLabel(
                            'Prochain concert',
                            Icons.star_rounded,
                            AppColors.concertAccent,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: ConcertFeaturedCard(
                              concert: _visibleUpcoming.first,
                            ),
                          ),
                        ),
                        if (_visibleUpcoming.length > 1) ...[
                          SliverToBoxAdapter(
                            child: _buildSectionLabel(
                              'Autres concerts à venir',
                              Icons.event_rounded,
                              AppColors.concertAccent,
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    10,
                                  ),
                                  child: ConcertCompactCard(
                                    concert: _visibleUpcoming[index + 1],
                                  ),
                                );
                              },
                              childCount: _visibleUpcoming.length - 1,
                            ),
                          ),
                        ],
                      ],
                      if (_visiblePast.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionLabel(
                            'Concerts passés',
                            Icons.history_rounded,
                            AppColors.textMuted,
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  10,
                                ),
                                child: ConcertCompactCard(
                                  concert: _visiblePast[index],
                                  isPast: true,
                                ),
                              );
                            },
                            childCount: _visiblePast.length,
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _upcoming.length + _past.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF831843), Color(0xFFBE185D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.concertAccent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.theater_comedy_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Programme de la saison',
                    style: AppTextStyles.title.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Aucun concert enregistré'
                        : '$total concert${total > 1 ? 's' : ''} · ${_upcoming.length} à venir',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _filterChip('Tous', _ProgrammeFilter.all),
          const SizedBox(width: 8),
          _filterChip('À venir', _ProgrammeFilter.upcoming),
          const SizedBox(width: 8),
          _filterChip('Passés', _ProgrammeFilter.past),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _ProgrammeFilter value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.concertAccent : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.concertAccent : AppColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.concertAccent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              fontSize: 12,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTextStyles.subtitle.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_filter) {
      _ProgrammeFilter.upcoming => 'Aucun concert à venir pour le moment',
      _ProgrammeFilter.past => 'Aucun concert passé enregistré',
      _ => 'Aucun concert programmé',
    };
    return CsoUi.emptyState(
      message: message,
      icon: Icons.celebration_rounded,
      iconColor: AppColors.concertAccent,
    );
  }
}
