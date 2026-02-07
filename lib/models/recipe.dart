class Recipe {
  final String id;
  final String title;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final String? sourceUrl;
  final String sourceType; // 'url', 'video', 'image', 'manual'
  final String? imageUrl;
  final String? prepTime;
  final String? cookTime;
  final int? servings;
  final List<String> tags;
  final bool wantToCook;
  final bool isCooked; // Added field
  final DateTime? cookedDate;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.sourceUrl,
    required this.sourceType,
    this.imageUrl,
    this.prepTime,
    this.cookTime,
    this.servings,
    List<String>? tags,
    this.wantToCook = true,
    this.isCooked = false, // Added default value
    this.cookedDate,
    DateTime? createdAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  Recipe copyWith({
    String? id,
    String? title,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    String? sourceUrl,
    String? sourceType,
    String? imageUrl,
    String? prepTime,
    String? cookTime,
    int? servings,
    List<String>? tags,
    bool? wantToCook,
    bool? isCooked, // Added parameter
    DateTime? cookedDate,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceType: sourceType ?? this.sourceType,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      tags: tags ?? this.tags,
      wantToCook: wantToCook ?? this.wantToCook,
      isCooked: isCooked ?? this.isCooked, // Added assignment
      cookedDate: cookedDate ?? this.cookedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'source_url': sourceUrl,
      'source_type': sourceType,
      'image_url': imageUrl,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'servings': servings,
      'tags': tags,
      'want_to_cook': wantToCook,
      'is_cooked': isCooked, // Added to JSON
      'cooked_date': cookedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      ingredients: (json['ingredients'] as List?)
          ?.map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList() ??
          [],
      instructions: (json['instructions'] as List?)
          ?.map((i) => i.toString())
          .toList() ??
          [],
      sourceUrl: json['source_url'] as String?,
      sourceType: json['source_type'] as String,
      imageUrl: json['image_url'] as String?,
      prepTime: json['prep_time'] as String?,
      cookTime: json['cook_time'] as String?,
      servings: json['servings'] as int?,
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList(),
      wantToCook: json['want_to_cook'] as bool? ?? true,
      isCooked: json['is_cooked'] as bool? ?? false, // Added from JSON
      cookedDate: json['cooked_date'] != null
          ? DateTime.parse(json['cooked_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Ingredient {
  final String item;
  final double quantity;
  final String unit;

  Ingredient({
    required this.item,
    required this.quantity,
    required this.unit,
  });

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
}