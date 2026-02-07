class Ingredient {
  final String item;
  final double quantity;
  final String unit;

  Ingredient({
    required this.item,
    required this.quantity,
    required this.unit,
  });

  String get displayText => '$quantity $unit $item'.trim();

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      item: json['item'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  Ingredient copyWith({
    String? item,
    double? quantity,
    String? unit,
  }) {
    return Ingredient(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}