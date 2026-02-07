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
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Grocery List',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For: ${widget.recipeName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress indicator
                    _buildProgressIndicator(),
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
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.share, size: 20),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.copy, size: 20),
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
                    return _buildCategorySection(entry.key, entry.value);
                  },
                ),
              ),

              // Save to list button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _saveToGroceryLists,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Save to My Lists',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    final total = _items.length;
    final checked = _checkedItems.length;
    final progress = total > 0 ? checked / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$checked of $total items',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Colors.green),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Map<GroceryCategory, List<GroceryItem>> _getGroupedItems() {
    final Map<GroceryCategory, List<GroceryItem>> grouped = {};

    for (final item in _items) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }

    // Sort by category order
    final sortedMap = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );

    return sortedMap;
  }

  Widget _buildCategorySection(GroceryCategory category, List<GroceryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 20,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _getCategoryName(category),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _buildGroceryItem(item)),
      ],
    );
  }

  Widget _buildGroceryItem(GroceryItem item) {
    final isChecked = _checkedItems.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? Colors.green.shade200 : Colors.grey.shade200,
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
          style: TextStyle(
            fontSize: 16,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey.shade600 : Colors.black,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        activeColor: Colors.green,
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(GroceryCategory category) {
    switch (category) {
      case GroceryCategory.produce:
        return Icons.eco;
      case GroceryCategory.dairy:
        return Icons.local_drink;
      case GroceryCategory.meat:
        return Icons.restaurant;
      case GroceryCategory.pantry:
        return Icons.inventory_2;
      case GroceryCategory.bakery:
        return Icons.bakery_dining;
      case GroceryCategory.frozen:
        return Icons.ac_unit;
      case GroceryCategory.other:
        return Icons.shopping_basket;
    }
  }

  String _getCategoryName(GroceryCategory category) {
    switch (category) {
      case GroceryCategory.produce:
        return 'Produce';
      case GroceryCategory.dairy:
        return 'Dairy & Eggs';
      case GroceryCategory.meat:
        return 'Meat & Seafood';
      case GroceryCategory.pantry:
        return 'Pantry';
      case GroceryCategory.bakery:
        return 'Bakery';
      case GroceryCategory.frozen:
        return 'Frozen';
      case GroceryCategory.other:
        return 'Other';
    }
  }

  void _shareGroceryList() {
    final shareText = _generateGroceryListText();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Grocery List',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how to share your list',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Share as text
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.message, color: Colors.blue),
                ),
                title: const Text('Share as Text'),
                subtitle: const Text('Send via Messages, WhatsApp, etc.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(shareText, subject: 'Grocery List: ${widget.recipeName}');
                },
              ),

              const SizedBox(height: 8),

              // Export to Reminders (iOS) / Keep (Android)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.orange),
                ),
                title: const Text('Export to Reminders'),
                subtitle: const Text('Create checklist in Reminders app'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _exportToReminders();
                },
              ),

              const SizedBox(height: 8),

              // Send via Email
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.email, color: Colors.green),
                ),
                title: const Text('Send via Email'),
                subtitle: const Text('Email the list to someone'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    shareText,
                    subject: 'Grocery List: ${widget.recipeName}',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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

    buffer.writeln('Generated by Recipe Action');
    return buffer.toString();
  }

  void _copyToClipboard() {
    final text = _generateGroceryListText();
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 12),
            Text('Grocery list copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exportToReminders() {
    // In a real app, this would integrate with platform-specific APIs
    // For now, we'll use the share functionality with a hint
    final text = _generateGroceryListText();
    Share.share(
      text,
      subject: 'Grocery List: ${widget.recipeName}',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share to your Reminders app from the share menu'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _saveToGroceryLists() {
    // This would save to the user's saved grocery lists
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Grocery list saved!'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}