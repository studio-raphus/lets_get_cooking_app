import '../models/recipe.dart';
import '../models/grocery_item.dart';

class GroceryListGenerator {
  /// Generate a consolidated grocery list from multiple recipes
  List<GroceryItem> generateFromRecipes(List<Recipe> recipes) {
    Map<String, GroceryItem> consolidatedItems = {};

    for (var recipe in recipes) {
      for (var ingredient in recipe.ingredients) {
        String normalizedName = _normalizeIngredientName(ingredient.item);

        if (consolidatedItems.containsKey(normalizedName)) {
          // If same unit, combine quantities
          final existing = consolidatedItems[normalizedName]!;
          if (_isSameUnit(existing.unit, ingredient.unit)) {
            consolidatedItems[normalizedName] = existing.copyWith(
              quantity: existing.quantity + ingredient.quantity,
              recipes: [...existing.recipes, recipe.title],
            );
          } else {
            // Different units, create separate item
            final newId = '${normalizedName}_${DateTime.now().millisecondsSinceEpoch}';
            consolidatedItems[newId] = GroceryItem(
              id: newId,
              name: ingredient.item,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
              category: _categorizeIngredient(ingredient.item),
              recipes: [recipe.title],
            );
          }
        } else {
          consolidatedItems[normalizedName] = GroceryItem(
            name: ingredient.item,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            category: _categorizeIngredient(ingredient.item),
            recipes: [recipe.title],
          );
        }
      }
    }

    // Sort by category
    final items = consolidatedItems.values.toList();
    items.sort((a, b) => a.category.index.compareTo(b.category.index));

    return items;
  }

  /// Normalize ingredient name for matching (lowercase, remove plurals, etc.)
  String _normalizeIngredientName(String name) {
    String normalized = name.toLowerCase().trim();

    // Remove common modifiers
    normalized = normalized
        .replaceAll(RegExp(r'\b(fresh|dried|frozen|raw|cooked|chopped|diced|sliced|minced)\b'), '')
        .trim();

    // Simple plural handling
    if (normalized.endsWith('es')) {
      normalized = normalized.substring(0, normalized.length - 2);
    } else if (normalized.endsWith('s') && !normalized.endsWith('ss')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  /// Check if two units are the same (with basic normalization)
  bool _isSameUnit(String unit1, String unit2) {
    final normalized1 = _normalizeUnit(unit1);
    final normalized2 = _normalizeUnit(unit2);
    return normalized1 == normalized2;
  }

  /// Normalize units for comparison
  String _normalizeUnit(String unit) {
    final unitMap = {
      // Volume
      'cup': 'cup',
      'cups': 'cup',
      'c': 'cup',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tbsp': 'tbsp',
      'tbs': 'tbsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'tsp': 'tsp',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'ml': 'ml',
      'liter': 'l',
      'liters': 'l',
      'l': 'l',
      'fluid ounce': 'fl oz',
      'fluid ounces': 'fl oz',
      'fl oz': 'fl oz',

      // Weight
      'gram': 'g',
      'grams': 'g',
      'g': 'g',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'kg': 'kg',
      'ounce': 'oz',
      'ounces': 'oz',
      'oz': 'oz',
      'pound': 'lb',
      'pounds': 'lb',
      'lb': 'lb',

      // Other
      'pinch': 'pinch',
      'pinches': 'pinch',
      'piece': 'piece',
      'pieces': 'piece',
    };

    return unitMap[unit.toLowerCase().trim()] ?? unit.toLowerCase();
  }

  /// Categorize ingredient into grocery categories
  GroceryCategory _categorizeIngredient(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Produce
    final produceKeywords = [
      'lettuce', 'tomato', 'onion', 'garlic', 'carrot', 'celery', 'potato',
      'apple', 'banana', 'orange', 'lemon', 'lime', 'berry', 'spinach',
      'kale', 'broccoli', 'cauliflower', 'cucumber', 'pepper', 'mushroom',
      'avocado', 'zucchini', 'squash', 'cabbage', 'cilantro', 'parsley',
      'basil', 'mint', 'ginger', 'scallion', 'shallot', 'leek'
    ];

    // Dairy
    final dairyKeywords = [
      'milk', 'cream', 'butter', 'cheese', 'yogurt', 'egg', 'sour cream',
      'half-and-half', 'whipping cream', 'heavy cream', 'parmesan',
      'mozzarella', 'cheddar', 'feta', 'ricotta', 'cottage cheese'
    ];

    // Meat & Seafood
    final meatKeywords = [
      'chicken', 'beef', 'pork', 'turkey', 'lamb', 'fish', 'salmon',
      'tuna', 'shrimp', 'bacon', 'sausage', 'ground beef', 'steak',
      'ham', 'duck', 'veal', 'cod', 'tilapia', 'crab', 'lobster'
    ];

    // Pantry
    final pantryKeywords = [
      'flour', 'sugar', 'salt', 'pepper', 'oil', 'vinegar', 'rice',
      'pasta', 'beans', 'lentils', 'oats', 'quinoa', 'sauce', 'stock',
      'broth', 'can', 'canned', 'dried', 'spice', 'herb', 'honey',
      'maple syrup', 'vanilla', 'baking powder', 'baking soda', 'yeast',
      'chocolate', 'cocoa', 'nuts', 'almond', 'walnut', 'peanut'
    ];

    // Bakery
    final bakeryKeywords = [
      'bread', 'bun', 'roll', 'bagel', 'croissant', 'tortilla', 'pita',
      'naan', 'baguette', 'sourdough', 'ciabatta'
    ];

    // Frozen
    final frozenKeywords = [
      'frozen', 'ice cream', 'popsicle', 'frozen vegetables', 'frozen fruit'
    ];

    // Check categories in order
    if (produceKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.produce;
    }
    if (dairyKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.dairy;
    }
    if (meatKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.meat;
    }
    if (bakeryKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.bakery;
    }
    if (frozenKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.frozen;
    }
    if (pantryKeywords.any((keyword) => name.contains(keyword))) {
      return GroceryCategory.pantry;
    }

    return GroceryCategory.other;
  }
}