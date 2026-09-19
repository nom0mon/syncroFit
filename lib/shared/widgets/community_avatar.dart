import 'package:flutter/material.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    required this.name,
    this.imageUrl,
    this.radius = 20,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      onForegroundImageError: url != null && url.isNotEmpty ? (_, __) {} : null,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
