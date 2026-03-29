class UserModel {
  final String id;
  final String fullName;
  final String role;
  final String email;
  final String? phone;
  final String? avatar;
  final String? pupitre;       // soprano | alto | ténor | basse
  final bool isChefDePupitre;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    this.phone,
    this.avatar,
    this.pupitre,
    this.isChefDePupitre = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ??
          '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      pupitre: json['pupitre'],
      isChefDePupitre: json['isChefDePupitre'] == true,
    );
  }

  /// Human-readable label for the pupitre (capitalised)
  String get pupitreLabel {
    if (pupitre == null) return '';
    switch (pupitre) {
      case 'soprano': return 'Soprano';
      case 'alto':    return 'Alto';
      case 'ténor':   return 'Ténor';
      case 'basse':   return 'Basse';
      default:        return pupitre!;
    }
  }

  /// Colour associated with the pupitre (used across the app)
  static const Map<String, int> pupitreColors = {
    'soprano': 0xFF7C3AED,  // violet
    'alto':    0xFF0891B2,  // cyan
    'ténor':   0xFF059669,  // emerald
    'basse':   0xFFB45309,  // amber
  };

  int get pupitreColor => pupitreColors[pupitre] ?? 0xFF6B7280;
}