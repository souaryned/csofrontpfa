import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/choriste_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cso_ui.dart';

class CongeScreen extends StatefulWidget {
  const CongeScreen({super.key});

  @override
  State<CongeScreen> createState() => _CongeScreenState();
}

class _CongeScreenState extends State<CongeScreen> {
  final ChoristeService _service = ChoristeService();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _loadingConcerts = true;
  List<dynamic> _concerts = [];

  @override
  void initState() {
    super.initState();
    _loadConcerts();
  }

  Future<void> _loadConcerts() async {
    try {
      final concerts = await _service.getConcerts();
      if (!mounted) return;
      setState(() {
        _concerts = concerts;
        _loadingConcerts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConcerts = false);
    }
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isConcertDay(DateTime day) {
    final key = _dayKey(day);
    return _concerts.any((c) {
      final d = _parseDate(c['dateHeure']);
      return d != null && _dayKey(d) == key;
    });
  }

  String? _concertTitleOnDay(DateTime day) {
    for (final c in _concerts) {
      final d = _parseDate(c['dateHeure']);
      if (d != null && _isSameDay(d, day)) {
        return c['title'] as String? ?? 'Concert';
      }
    }
    return null;
  }

  DateTime? _firstConcertDayInRange(DateTime start, DateTime end) {
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      if (_isConcertDay(d)) return d;
      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  Future<void> _pickDate(bool isStart) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? todayOnly.add(const Duration(days: 1)))
          : (_endDate ??
              _startDate?.add(const Duration(days: 1)) ??
              todayOnly.add(const Duration(days: 2))),
      firstDate: isStart ? todayOnly : (_startDate ?? todayOnly),
      lastDate: todayOnly.add(const Duration(days: 365)),
      selectableDayPredicate: (day) => !_isConcertDay(day),
      helpText: isStart ? 'Date de début' : 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (_isConcertDay(picked)) {
        final title = _concertTitleOnDay(picked);
        _showSnackBar(
          'Cette date correspond à un concert${title != null ? ' : $title' : ''}',
          Colors.orange,
        );
        return;
      }
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null &&
              (_endDate!.isBefore(_startDate!) || _isConcertDay(_endDate!))) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choisir';
    const months = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }

  int get _durationDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays;
  }

  Future<void> _submitLeave() async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.id;

    if (_startDate == null || _endDate == null) {
      _showSnackBar('Veuillez sélectionner les deux dates', Colors.orange);
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer un motif', Colors.orange);
      return;
    }

    final blockedDay = _firstConcertDayInRange(_startDate!, _endDate!);
    if (blockedDay != null) {
      final title = _concertTitleOnDay(blockedDay);
      _showSnackBar(
        'La période inclut un jour de concert${title != null ? ' ($title)' : ''}. '
        'Choisissez d\'autres dates.',
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.declareLeave(
        userId!,
        _startDate!.toIso8601String(),
        _endDate!.toIso8601String(),
        _reasonController.text.trim(),
      );
      if (!mounted) return;
      _showSnackBar('Congé déclaré avec succès ✅', const Color(0xFF22C55E));
      setState(() {
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = e.response?.data?['message'] as String?;
      _showSnackBar(
        serverMsg ?? 'Erreur lors de l\'envoi de la demande',
        serverMsg != null && serverMsg.toLowerCase().contains('concert')
            ? Colors.orange
            : const Color(0xFFEF4444),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return CsoUi.screenBody(
      child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: CsoUi.card(accent: AppColors.accent),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_outlined,
                    color: AppColors.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Déclarer un congé', style: AppTextStyles.title),
                      const SizedBox(height: 4),
                      Text(
                        'Votre demande sera envoyée au manager pour validation',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section titre ──
          _buildSectionTitle('Période de congé', Icons.date_range_rounded),
          const SizedBox(height: 12),

          if (!_loadingConcerts && _concerts.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.concertAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.concertAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 18,
                    color: AppColors.concertAccent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les jours de concert ne peuvent pas être sélectionnés.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.concertAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Date cards ──
          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  label: 'Date de début',
                  date: _startDate,
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateCard(
                  label: 'Date de fin',
                  date: _endDate,
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF9B8EC4),
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),

          // ── Duration indicator ──
          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timelapse_rounded,
                        color: Color(0xFF2DD4BF), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Durée : $_durationDays jour(s)',
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_durationDays j',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Motif ──
          _buildSectionTitle('Motif de la demande', Icons.edit_note_rounded),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _reasonController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Décrivez le motif de votre congé...',
                hintStyle: const TextStyle(
                    color: Color(0xFFCBD5E1), fontSize: 14),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF2DD4BF), width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Bouton submit ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitLeave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Soumettre la demande',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: const Color(0xFF2DD4BF)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isSelected ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _formatDate(date),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? color : const Color(0xFFCBD5E1),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSelected ? 'Appuyez pour modifier' : 'Appuyez pour choisir',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}