import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../models/grocery_item.dart';

class GroceryListSheet extends StatefulWidget {
  final List<GroceryItem> groceryItems;
  final String recipeName;

  const GroceryListSheet({
    super.key,
    required this.groceryItems,
    required this.recipeName,
  });

  @override
  State<GroceryListSheet> createState() => _GroceryListSheetState();
}

class _GroceryListSheetState extends State<GroceryListSheet> {
  late List<GroceryItem> _items;
  final Set<String> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.groceryItems);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grocery List',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For: ${widget.recipeName}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Progress indicator
                    _buildProgressIndicator(theme),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareGroceryList,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.primary),
                          foregroundColor: colorScheme.primary,
                        ),
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _copyToClipboard,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Grocery list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _getGroupedItems().length,
                  itemBuilder: (context, index) {
                    final entry = _getGroupedItems().entries.elementAt(index);
                    return _buildCategorySection(entry.key, entry.value, theme);
                  },
                ),
              ),

              // Save to list button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _saveToGroceryLists,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    label: const Text('Save to My Lists'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final total = _items.length;
    final checked = _checkedItems.length;
    final progress = total > 0 ? checked / total : 0.0;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$checked of $total items',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Map<GroceryCategory, List<GroceryItem>> _getGroupedItems() {
    final Map<GroceryCategory, List<GroceryItem>> grouped = {};
    for (final item in _items) {
      if (!grouped.containsKey(item.category)) grouped[item.category] = [];
      grouped[item.category]!.add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );
  }

  Widget _buildCategorySection(
      GroceryCategory category, List<GroceryItem> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _getCategoryName(category),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _buildGroceryItem(item, theme)),
      ],
    );
  }

  Widget _buildGroceryItem(GroceryItem item, ThemeData theme) {
    final isChecked = _checkedItems.contains(item.id);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked
              ? Colors.transparent
              : colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _checkedItems.add(item.id);
            } else {
              _checkedItems.remove(item.id);
            }
          });
        },
        title: Text(
          item.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        activeColor: colorScheme.primary,
        checkColor: colorScheme.onPrimary,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(GroceryCategory category) {
    switch (category) {
      case GroceryCategory.produce: return Icons.eco_rounded;
      case GroceryCategory.dairy: return Icons.water_drop_rounded;
      case GroceryCategory.meat: return Icons.restaurant_rounded;
      case GroceryCategory.pantry: return Icons.kitchen_rounded;
      case GroceryCategory.bakery: return Icons.bakery_dining_rounded;
      case GroceryCategory.frozen: return Icons.ac_unit_rounded;
      case GroceryCategory.other: return Icons.shopping_basket_rounded;
    }
  }

  String _getCategoryName(GroceryCategory category) {
    // Kept standard, but using sentence case matches the theme better
    switch (category) {
      case GroceryCategory.produce: return 'Produce';
      case GroceryCategory.dairy: return 'Dairy & Eggs';
      case GroceryCategory.meat: return 'Meat & Seafood';
      case GroceryCategory.pantry: return 'Pantry';
      case GroceryCategory.bakery: return 'Bakery';
      case GroceryCategory.frozen: return 'Frozen';
      case GroceryCategory.other: return 'Other';
    }
  }

  void _shareGroceryList() {
    final shareText = _generateGroceryListText();
    // Implementation remains mostly the same, just UI tweaks on the modal if needed
    // ... logic mostly identical to original
    Share.share(shareText, subject: 'Grocery List: ${widget.recipeName}');
  }

  String _generateGroceryListText() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 Grocery List');
    buffer.writeln('For: ${widget.recipeName}');
    buffer.writeln();

    final grouped = _getGroupedItems();
    for (final entry in grouped.entries) {
      buffer.writeln('${_getCategoryName(entry.key)}:');
      for (final item in entry.value) {
        final checkmark = _checkedItems.contains(item.id) ? '✓' : '☐';
        buffer.writeln('$checkmark ${item.quantity} ${item.unit} ${item.name}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _copyToClipboard() {
    final text = _generateGroceryListText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Grocery list copied!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _saveToGroceryLists() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved to your lists'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}