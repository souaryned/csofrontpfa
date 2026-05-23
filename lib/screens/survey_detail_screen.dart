// screens/choriste/survey_detail_screen.dart
import 'package:flutter/material.dart';
import '../../models/survey_model.dart';
import '../../services/survey_service.dart';

class SurveyDetailScreen extends StatefulWidget {
  final SurveyModel survey;

  const SurveyDetailScreen({super.key, required this.survey});

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen> {
  final SurveyService _service = SurveyService();

  // Map<questionId, valeur> — valeur peut être String ou List<String>
  final Map<String, dynamic> _reponses = {};

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _dejaRepondu = false;
  Map<String, dynamic>? _maReponse;

  @override
  void initState() {
    super.initState();
    _checkReponse();
  }

  Future<void> _checkReponse() async {
    try {
      final rep = await _service.getMaReponse(widget.survey.id);
      if (!mounted) return;
      setState(() {
        _dejaRepondu = rep != null;
        _maReponse = rep;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Validation ───────────────────────────────────────────────

  bool _isValid() {
    for (final q in widget.survey.questions) {
      if (!q.obligatoire) continue;
      final val = _reponses[q.id];
      if (val == null) return false;
      if (val is String && val.trim().isEmpty) return false;
      if (val is List && (val as List).isEmpty) return false;
    }
    return true;
  }

  // ── Submit ───────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isValid()) {
      _showSnack('Veuillez répondre à toutes les questions obligatoires.',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Construire la liste des réponses au format backend : [{questionId, valeur}]
      final List<Map<String, dynamic>> reponsesList = [];
      for (final entry in _reponses.entries) {
        reponsesList.add({
          'questionId': entry.key,
          'valeur': entry.value,
        });
      }

      await _service.soumettreReponses(
        surveyId: widget.survey.id,
        reponses: reponsesList,
      );

      if (!mounted) return;
      _showSnack('✅ Vos réponses ont été envoyées avec succès !');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      String msg = 'Erreur lors de l\'envoi.';
      if (e.toString().contains('409') ||
          e.toString().contains('déjà répondu')) {
        msg = 'Vous avez déjà répondu à ce sondage.';
      }
      _showSnack(msg, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Couleurs type ────────────────────────────────────────────

  Color get _accentColor {
    switch (widget.survey.type) {
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

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.survey.titre,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : _dejaRepondu
              ? _buildDejaRepondu()
              : _buildForm(),
      bottomNavigationBar: (!_isLoading && !_dejaRepondu)
          ? _buildBottomBar()
          : null,
    );
  }

  // ── Déjà répondu ─────────────────────────────────────────────

  Widget _buildDejaRepondu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 40, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vous avez déjà répondu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vos réponses ont bien été enregistrées.\nMerci pour votre participation !',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                // Afficher les réponses déjà soumises
                if (_maReponse != null) _buildReponsesSoumises(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Retour aux sondages'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReponsesSoumises() {
    final reponses = _maReponse?['reponses'] as List? ?? [];
    if (reponses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Vos réponses',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.survey.questions.map((q) {
          final rep = (reponses as List).firstWhere(
            (r) => r['questionId'] == q.id,
            orElse: () => null,
          );
          if (rep == null) return const SizedBox.shrink();

          String valeurLabel = '';
          final valeur = rep['valeur'];
          if (valeur is List) {
            valeurLabel = valeur.map((v) {
              final opt = q.options
                  .firstWhere((o) => o.valeur == v, orElse: () => SurveyOption(valeur: v, label: v));
              return opt.label;
            }).join(', ');
          } else {
            final opt = q.options
                .where((o) => o.valeur == valeur)
                .toList();
            valeurLabel =
                opt.isNotEmpty ? opt.first.label : (valeur?.toString() ?? '');
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.texte,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  valeurLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Formulaire ───────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info card du sondage ──
          _buildSurveyInfoCard(),
          const SizedBox(height: 20),

          // ── Questions ──
          ...widget.survey.questions.asMap().entries.map(
                (e) => _buildQuestionCard(e.key, e.value),
              ),
        ],
      ),
    );
  }

  Widget _buildSurveyInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.survey.typeEmoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.survey.titre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          if (widget.survey.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.survey.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _infoBadge(
                icon: Icons.group_rounded,
                label: widget.survey.cibleLabel,
                color: _accentColor,
              ),
              if (widget.survey.dateFin != null)
                _infoBadge(
                  icon: Icons.lock_clock_rounded,
                  label: 'Clôture : ${widget.survey.datefinFormatted}',
                  color: const Color(0xFFB45309),
                ),
              _infoBadge(
                icon: Icons.quiz_rounded,
                label: '${widget.survey.questions.length} question(s)',
                color: const Color(0xFF6B7280),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Question card ────────────────────────────────────────────

  Widget _buildQuestionCard(int index, SurveyQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header question
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: _accentColor.withOpacity(0.15))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.texte,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (question.obligatoire)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Obligatoire *',
                      style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // Body de la question
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildQuestionInput(question),
          ),
        ],
      ),
    );
  }

  // ── Input selon le type ──────────────────────────────────────

  Widget _buildQuestionInput(SurveyQuestion q) {
    switch (q.type) {
      case 'radio':
        return _buildRadio(q);
      case 'checkbox':
        return _buildCheckbox(q);
      case 'select':
        return _buildSelect(q);
      case 'date':
        return _buildDatePicker(q);
      default:
        return _buildTexte(q);
    }
  }

  // Radio
  Widget _buildRadio(SurveyQuestion q) {
    final selected = _reponses[q.id] as String?;
    return Column(
      children: q.options.map((opt) {
        final isSelected = selected == opt.valeur;
        return GestureDetector(
          onTap: () => setState(() => _reponses[q.id] = opt.valeur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withOpacity(0.07)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _accentColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? _accentColor : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    color: isSelected ? _accentColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? _accentColor
                        : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Checkbox
  Widget _buildCheckbox(SurveyQuestion q) {
    final selected = (_reponses[q.id] as List<String>?) ?? [];
    return Column(
      children: q.options.map((opt) {
        final isSelected = selected.contains(opt.valeur);
        return GestureDetector(
          onTap: () {
            setState(() {
              final List<String> current =
                  List<String>.from(_reponses[q.id] ?? []);
              if (isSelected) {
                current.remove(opt.valeur);
              } else {
                current.add(opt.valeur);
              }
              _reponses[q.id] = current;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withOpacity(0.07)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _accentColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected
                          ? _accentColor
                          : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    color: isSelected ? _accentColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? _accentColor
                        : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Select (dropdown)
  Widget _buildSelect(SurveyQuestion q) {
    final selected = _reponses[q.id] as String?;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected != null ? _accentColor : const Color(0xFFE2E8F0),
          width: selected != null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selected,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Sélectionner une option...',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[400]),
              ),
            ),
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: _accentColor),
            items: q.options
                .map((opt) => DropdownMenuItem<String>(
                      value: opt.valeur,
                      child: Text(opt.label,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1E293B))),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _reponses[q.id] = val);
            },
          ),
        ),
      ),
    );
  }

  // Texte libre
  Widget _buildTexte(SurveyQuestion q) {
    return TextFormField(
      initialValue: _reponses[q.id] as String?,
      maxLines: 3,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: 'Votre réponse...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: (val) => _reponses[q.id] = val,
    );
  }

  // Date
  Widget _buildDatePicker(SurveyQuestion q) {
    final selected = _reponses[q.id] as String?;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: _accentColor),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() =>
              _reponses[q.id] = picked.toIso8601String().split('T').first);
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected != null ? _accentColor : const Color(0xFFE2E8F0),
            width: selected != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 18, color: _accentColor),
            const SizedBox(width: 10),
            Text(
              selected ?? 'Choisir une date...',
              style: TextStyle(
                fontSize: 13,
                color: selected != null
                    ? const Color(0xFF1E293B)
                    : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────

  Widget _buildBottomBar() {
    final obligatoires = widget.survey.questions.where((q) => q.obligatoire);
    final nb = obligatoires.length;
    final repondus = obligatoires
        .where((q) {
          final v = _reponses[q.id];
          if (v == null) return false;
          if (v is String) return v.trim().isNotEmpty;
          if (v is List) return (v as List).isNotEmpty;
          return false;
        })
        .length;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de progression
          if (nb > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$repondus/$nb questions obligatoires',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                Text(
                  '${nb > 0 ? (repondus / nb * 100).round() : 0}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _accentColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: nb > 0 ? repondus / nb : 0,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Bouton envoyer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSubmitting || !_isValid()) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 17),
                        SizedBox(width: 8),
                        Text(
                          'Envoyer mes réponses',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}