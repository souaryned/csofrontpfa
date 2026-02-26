import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const AvatarImage({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.radius = 26,
    this.backgroundColor = const Color(0xFF1E293B),
    this.textColor = const Color(0xFF2DD4BF),
  });

  @override
  Widget build(BuildContext context) {
    final initial = fullName?.isNotEmpty == true ? fullName![0].toUpperCase() : '?';

    // Pas d'avatar → afficher l'initiale
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _buildInitial(initial);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // ✅ Clé = URL complète (timestamp inclus) → cache automatiquement invalidé
          cacheKey: avatarUrl,
          placeholder: (context, url) => Container(
            width: radius * 2,
            height: radius * 2,
            color: backgroundColor,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
            ),
          ),
          errorWidget: (context, url, error) => _buildInitial(initial),
        ),
      ),
    );
  }

  Widget _buildInitial(String initial) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}