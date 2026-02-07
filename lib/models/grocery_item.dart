enum GroceryCategory {
  produce,
  dairy,
  meat,
  pantry,
  bakery,
  frozen,
  other,
}

class GroceryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final GroceryCategory category;
  final List<String> recipes; // Which recipes this item is for

  GroceryItem({
    String? id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    List<String>? recipes,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        recipes = recipes ?? [];

  void addQuantity(double additionalQuantity, String additionalUnit) {
    // In a production app, you'd normalize units and combine quantities
    // For now, this is a simple implementation
  }

  GroceryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    GroceryCategory? category,
    List<String>? recipes,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      recipes: recipes ?? this.recipes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category.index,
      'recipes': recipes,
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: GroceryCategory.values[json['category'] as int],
      recipes: (json['recipes'] as List?)?.map((r) => r.toString()).toList(),
    );
  }
}