import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image
            recipe.imageUrl != null
                ? Image.network(
              recipe.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: colorScheme.surfaceContainerHighest),
            )
                : Container(
              color: colorScheme.secondaryContainer,
              child: Icon(Icons.restaurant, size: 64, color: colorScheme.onSecondaryContainer),
            ),

            // 2. Gradient Overlay (for readability)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),

            // 3. Ripple Effect for Touch
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),

            // 4. Top Badges (Cook time / Tags)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time Badge
                  if (recipe.cookTime != null)
                    _buildGlassBadge(
                        context,
                        icon: Icons.timer_outlined,
                        label: recipe.cookTime!
                    ),

                  // Primary Tag Badge
                  if (recipe.tags.isNotEmpty)
                    _buildGlassBadge(
                        context,
                        label: recipe.tags.first.toUpperCase(),
                        isAccent: true
                    ),
                ],
              ),
            ),

            // 5. Bottom Info (Glassmorphism Panel)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white.withOpacity(0.15), // Frosted glass
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.local_dining, size: 14, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.ingredients.length} Ingredients',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8)),
                            ),
                            const Spacer(),
                            if (recipe.isCooked)
                              Icon(Icons.check_circle, size: 16, color: colorScheme.secondary)
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBadge(BuildContext context, {IconData? icon, required String label, bool isAccent = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: isAccent
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Colors.black.withOpacity(0.4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 12),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}