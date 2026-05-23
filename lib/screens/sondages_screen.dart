// screens/choriste/sondages_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/survey_service.dart';
import '../../models/survey_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cso_ui.dart';
import 'survey_detail_screen.dart';

class SondagesScreen extends StatefulWidget {
  const SondagesScreen({super.key});

  @override
  State<SondagesScreen> createState() => _SondagesScreenState();
}

class _SondagesScreenState extends State<SondagesScreen>
    with SingleTickerProviderStateMixin {
  final SurveyService _service = SurveyService();

  List<SurveyModel> _surveys = [];
  bool _isLoading = true;
  String? _error;

  // Filtre actif : 'tous' | 'actif' | 'clos'
  String _filter = 'tous';

  // Map surveyId -> a-t-il répondu
  final Map<String, bool> _dejaRepondu = {};

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await _service.getSurveys();
      final surveys = raw.map((j) => SurveyModel.fromJson(j)).toList();

      // Vérifier pour chaque sondage actif si le choriste a déjà répondu
      final Map<String, bool> repMap = {};
      for (final s in surveys) {
        if (s.statut == 'actif') {
          final rep = await _service.getMaReponse(s.id);
          repMap[s.id] = rep != null;
        }
      }

      if (!mounted) return;
      setState(() {
        _surveys = surveys;
        _dejaRepondu.addAll(repMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les sondages.';
        _isLoading = false;
      });
    }
  }

  List<SurveyModel> get _filtered {
    if (_filter == 'tous') return _surveys;
    return _surveys.where((s) => s.statut == _filter).toList();
  }

  int _countByStatus(String statut) =>
      _surveys.where((s) => s.statut == statut).length;

  // ── Couleurs ────────────────────────────────────────────────

  Color _typeColor(String type) {
    switch (type) {
      case 'disponibilite':
        return const Color(0xFF3B82F6);
      case 'voyage':
        return const Color(0xFF8B5CF6);
      case 'restaurant':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'actif':
        return const Color(0xFF16A34A);
      case 'clos':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statutBg(String statut) {
    switch (statut) {
      case 'actif':
        return const Color(0xFFDCFCE7);
      case 'clos':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CsoUi.screenBody(
      child: RefreshIndicator(
      onRefresh: _loadSurveys,
      color: AppColors.accent,
      child: _isLoading
          ? CsoUi.loading()
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildFilterBar(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    _filtered.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmpty(),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildCard(_filtered[i]),
                                childCount: _filtered.length,
                              ),
                            ),
                          ),
                  ],
                ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('📋', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sondages',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'Participez aux sondages du chœur',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        // Badge total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_surveys.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ── Filter bar (like web: Tous | Actif | Clôturé) ────────────

  Widget _buildFilterBar() {
    final filters = [
      {'key': 'tous', 'label': 'Tous', 'count': _surveys.length},
      {'key': 'actif', 'label': 'Actif', 'count': _countByStatus('actif')},
      {'key': 'clos', 'label': 'Clôturé', 'count': _countByStatus('clos')},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          final count = f['count'] as int;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filter = f['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Card ─────────────────────────────────────────────────────

  Widget _buildCard(SurveyModel survey) {
    final typeColor = _typeColor(survey.type);
    final statutColor = _statutColor(survey.statut);
    final statutBg = _statutBg(survey.statut);
    final aRepondu = _dejaRepondu[survey.id] == true;
    final isActif = survey.statut == 'actif';

    return GestureDetector(
      onTap: isActif
          ? () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SurveyDetailScreen(survey: survey),
                ),
              );
              if (result == true) _loadSurveys();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(color: typeColor, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1 : type badge + statut badge ──
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(survey.typeEmoji,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          survey.typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Statut badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statutColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          survey.statutLabel,
                          style: TextStyle(
                            color: statutColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Déjà répondu
                  if (aRepondu)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 11, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'Répondu',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Titre ──
              Text(
                survey.titre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),

              if (survey.description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  survey.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // ── Infos bas de carte ──
              Row(
                children: [
                  // Date clôture
                  if (survey.dateFin != null) ...[
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Clôture : ${survey.datefinFormatted}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Cible
                  const Icon(Icons.group_rounded,
                      size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      survey.cibleLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Flèche si actif
                  if (isActif && !aRepondu)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Répondre',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty ────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Text('📋', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun sondage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _filter == 'tous'
                  ? 'Aucun sondage disponible pour le moment.'
                  : 'Aucun sondage dans cette catégorie.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSurveys,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}