import 'package:flutter/material.dart';
import '../models/grocery_item.dart';

class GroceryListSheet extends StatefulWidget {
  final List<GroceryItem> initialItems;

  const GroceryListSheet({
    super.key,
    required this.initialItems,
  });

  @override
  State<GroceryListSheet> createState() => _GroceryListSheetState();
}

class _GroceryListSheetState extends State<GroceryListSheet> {
  // We can track selections here if needed in the future
  late List<GroceryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group items by category for display
    final groupedItems = <String, List<GroceryItem>>{};
    for (var item in _items) {
      final categoryName = item.category.name.toUpperCase();
      groupedItems.putIfAbsent(categoryName, () => []).add(item);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Grocery List Preview',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: groupedItems.length,
              itemBuilder: (context, index) {
                final category = groupedItems.keys.elementAt(index);
                final items = groupedItems[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        category,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: theme.colorScheme.secondary,
                              size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name, // Assuming item has a name property
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          Text(
                            '${item.quantity > 0 ? item.quantity : ''} ${item.unit}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: FilledButton(
              onPressed: () {
                // TODO: Add logic to save to main grocery list provider
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Items added to your main list!')),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Add All to My List'),
            ),
          ),
        ],
      ),
    );
  }
}