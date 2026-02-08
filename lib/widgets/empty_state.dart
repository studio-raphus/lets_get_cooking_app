import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onActionPressed,
  }) : super(key: key);

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Mesh Gradient Background
            CustomPaint(
              painter: MeshGradientPainter(
                animation: _controller,
                colors: theme.colorScheme,
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  // We add a subtle overlay to ensure the icon pops
                  color: Colors.white10,
                ),
                child: Icon(
                  widget.icon,
                  size: 64,
                  // Use primary color but deeper for contrast against the mesh
                  color: theme.colorScheme.primary.withOpacity(0.8),
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              widget.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              widget.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (widget.actionText != null && widget.onActionPressed != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: widget.onActionPressed,
                icon: const Icon(Icons.add),
                label: Text(widget.actionText!),
                style: FilledButton.styleFrom(
                  elevation: 2,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}