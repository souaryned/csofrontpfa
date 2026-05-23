// models/survey_model.dart

class SurveyOption {
  final String valeur;
  final String label;

  SurveyOption({required this.valeur, required this.label});

  factory SurveyOption.fromJson(Map<String, dynamic> json) => SurveyOption(
        valeur: json['valeur'] ?? '',
        label: json['label'] ?? '',
      );
}

class SurveyQuestion {
  final String id;
  final String texte;
  final String type; // texte | radio | checkbox | date | select
  final List<SurveyOption> options;
  final bool obligatoire;

  SurveyQuestion({
    required this.id,
    required this.texte,
    required this.type,
    required this.options,
    required this.obligatoire,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
        id: json['id'] ?? '',
        texte: json['texte'] ?? '',
        type: json['type'] ?? 'texte',
        options: (json['options'] as List? ?? [])
            .map((o) => SurveyOption.fromJson(o))
            .toList(),
        obligatoire: json['obligatoire'] == true,
      );
}

class SurveyModel {
  final String id;
  final String titre;
  final String description;
  final String type; // disponibilite | voyage | restaurant | autre
  final String statut; // brouillon | actif | clos
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final List<SurveyQuestion> questions;
  final List<String> ciblePupitres;
  final DateTime createdAt;

  SurveyModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.type,
    required this.statut,
    this.dateDebut,
    this.dateFin,
    required this.questions,
    required this.ciblePupitres,
    required this.createdAt,
  });

  factory SurveyModel.fromJson(Map<String, dynamic> json) => SurveyModel(
        id: json['_id'] ?? '',
        titre: json['titre'] ?? '',
        description: json['description'] ?? '',
        type: json['type'] ?? 'autre',
        statut: json['statut'] ?? 'brouillon',
        dateDebut: json['dateDebut'] != null
            ? DateTime.tryParse(json['dateDebut'])
            : null,
        dateFin: json['dateFin'] != null
            ? DateTime.tryParse(json['dateFin'])
            : null,
        questions: (json['questions'] as List? ?? [])
            .map((q) => SurveyQuestion.fromJson(q))
            .toList(),
        ciblePupitres: (json['ciblePupitres'] as List? ?? [])
            .map((p) => p.toString())
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );

  // ── Helpers UI ──────────────────────────────────────────────

  String get typeLabel {
    switch (type) {
      case 'disponibilite':
        return 'Disponibilité';
      case 'voyage':
        return 'Voyage';
      case 'restaurant':
        return 'Restaurant';
      default:
        return 'Personnalisé';
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'disponibilite':
        return '📅';
      case 'voyage':
        return '✈️';
      case 'restaurant':
        return '🍽️';
      default:
        return '📝';
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'actif':
        return 'Actif';
      case 'clos':
        return 'Clôturé';
      default:
        return 'Brouillon';
    }
  }

  String get cibleLabel {
    if (ciblePupitres.isEmpty) return 'Tous les choristes';
    return ciblePupitres.map(_pupitreLabel).join(', ');
  }

  static String _pupitreLabel(String p) {
    switch (p) {
      case 'soprano':
        return 'Soprano';
      case 'alto':
        return 'Alto';
      case 'ténor':
        return 'Ténor';
      case 'basse':
        return 'Basse';
      default:
        return p;
    }
  }

  String get datefinFormatted {
    if (dateFin == null) return '';
    const months = [
      '',
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    return '${dateFin!.day} ${months[dateFin!.month]} ${dateFin!.year}';
  }
}