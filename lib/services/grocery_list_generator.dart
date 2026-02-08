import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/grocery_item.dart';

class GroceryListGenerator {
  /// Generate a consolidated grocery list from multiple recipes
  List<GroceryItem> generateFromRecipes(List<Recipe> recipes) {
    debugPrint('🛒 Generating grocery list from ${recipes.length} recipes');

    Map<String, GroceryItem> consolidatedItems = {};

    for (var recipe in recipes) {
      debugPrint('  📖 Processing recipe: ${recipe.title}');
      debugPrint('     Ingredients: ${recipe.ingredients.length}');

      for (var ingredient in recipe.ingredients) {
        final normalizedName = _normalizeIngredientName(ingredient.item);
        final normalizedUnit = _normalizeUnit(ingredient.unit);

        // Create unique key: name + unit
        final itemKey = '${normalizedName}_$normalizedUnit';

        if (consolidatedItems.containsKey(itemKey)) {
          // Same ingredient with same unit - combine quantities
          final existing = consolidatedItems[itemKey]!;
          final newQuantity = existing.quantity + ingredient.quantity;

          consolidatedItems[itemKey] = existing.copyWith(
            quantity: newQuantity,
            recipes: [...existing.recipes, recipe.title],
          );

          debugPrint('     ✅ Combined: ${ingredient.item} ($normalizedUnit) - ${existing.quantity} + ${ingredient.quantity} = $newQuantity');
        } else {
          // New ingredient or different unit
          final category = _categorizeIngredient(ingredient.item);

          consolidatedItems[itemKey] = GroceryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString() + itemKey.hashCode.toString(),
            name: ingredient.item,
            quantity: ingredient.quantity,
            unit: normalizedUnit,
            category: category,
            recipes: [recipe.title],
          );

          debugPrint('     ➕ Added: ${ingredient.item} (${ingredient.quantity} $normalizedUnit) - ${category.name}');
        }
      }
    }

    // Sort by category, then by name
    final items = consolidatedItems.values.toList();
    items.sort((a, b) {
      final categoryCompare = a.category.index.compareTo(b.category.index);
      if (categoryCompare != 0) return categoryCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    debugPrint('✅ Generated ${items.length} grocery items across ${GroceryCategory.values.length} categories');

    return items;
  }

  /// Normalize ingredient name for matching
  String _normalizeIngredientName(String name) {
    String normalized = name.toLowerCase().trim();

    // Remove common adjectives/modifiers
    final modifiers = [
      'fresh', 'dried', 'frozen', 'raw', 'cooked', 'chopped', 'diced',
      'sliced', 'minced', 'crushed', 'grated', 'shredded', 'whole',
      'large', 'small', 'medium', 'ripe', 'unripe', 'peeled', 'skinless',
      'boneless', 'organic', 'free-range', 'grass-fed', 'wild-caught',
      'extra', 'virgin', 'light', 'dark', 'unsalted', 'salted', 'sweetened',
      'unsweetened', 'active', 'dry', 'instant', 'all-purpose', 'plain'
    ];

    for (var modifier in modifiers) {
      normalized = normalized.replaceAll(RegExp(r'\b' + modifier + r'\b'), '').trim();
    }

    // Remove parenthetical notes
    normalized = normalized.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    // Handle plurals
    if (normalized.endsWith('ies')) {
      normalized = normalized.substring(0, normalized.length - 3) + 'y';
    } else if (normalized.endsWith('ves')) {
      normalized = normalized.substring(0, normalized.length - 3) + 'f';
    } else if (normalized.endsWith('es') && !normalized.endsWith('sses')) {
      normalized = normalized.substring(0, normalized.length - 2);
    } else if (normalized.endsWith('s') && !normalized.endsWith('ss')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Clean up extra whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  /// Normalize units for comparison and consolidation
  String _normalizeUnit(String unit) {
    final unitMap = {
      // Volume - US
      'cup': 'cup',
      'cups': 'cup',
      'c': 'cup',
      'c.': 'cup',

      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tbsp': 'tbsp',
      'tbsp.': 'tbsp',
      'tbs': 'tbsp',
      'T': 'tbsp',

      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'tsp': 'tsp',
      'tsp.': 'tsp',
      't': 'tsp',

      'fluid ounce': 'fl oz',
      'fluid ounces': 'fl oz',
      'fl oz': 'fl oz',
      'fl. oz.': 'fl oz',
      'fl.oz': 'fl oz',

      'pint': 'pint',
      'pints': 'pint',
      'pt': 'pint',

      'quart': 'quart',
      'quarts': 'quart',
      'qt': 'quart',

      'gallon': 'gallon',
      'gallons': 'gallon',
      'gal': 'gallon',

      // Volume - Metric
      'milliliter': 'ml',
      'milliliters': 'ml',
      'ml': 'ml',
      'mL': 'ml',

      'liter': 'L',
      'liters': 'L',
      'l': 'L',
      'L': 'L',

      // Weight - US
      'ounce': 'oz',
      'ounces': 'oz',
      'oz': 'oz',
      'oz.': 'oz',

      'pound': 'lb',
      'pounds': 'lb',
      'lb': 'lb',
      'lb.': 'lb',
      'lbs': 'lb',

      // Weight - Metric
      'gram': 'g',
      'grams': 'g',
      'g': 'g',
      'gr': 'g',

      'kilogram': 'kg',
      'kilograms': 'kg',
      'kg': 'kg',
      'kilo': 'kg',
      'kilos': 'kg',

      // Other
      'pinch': 'pinch',
      'pinches': 'pinch',
      'dash': 'dash',
      'dashes': 'dash',
      'piece': 'piece',
      'pieces': 'piece',
      'slice': 'slice',
      'slices': 'slice',
      'clove': 'clove',
      'cloves': 'clove',
      'can': 'can',
      'cans': 'can',
      'package': 'package',
      'packages': 'package',
      'bag': 'bag',
      'bags': 'bag',
      'box': 'box',
      'boxes': 'box',
      'jar': 'jar',
      'jars': 'jar',
      'bottle': 'bottle',
      'bottles': 'bottle',
      'bunch': 'bunch',
      'bunches': 'bunch',
      'head': 'head',
      'heads': 'head',
      'stalk': 'stalk',
      'stalks': 'stalk',
      'sprig': 'sprig',
      'sprigs': 'sprig',
      'leaf': 'leaf',
      'leaves': 'leaf',
      'sheet': 'sheet',
      'sheets': 'sheet',
      'stick': 'stick',
      'sticks': 'stick',
    };

    final lower = unit.toLowerCase().trim();
    return unitMap[lower] ?? lower;
  }

  /// Categorize ingredient into grocery store sections
  GroceryCategory _categorizeIngredient(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Produce - Fresh fruits, vegetables, herbs
    final produceKeywords = [
      // Vegetables
      'lettuce', 'spinach', 'kale', 'arugula', 'cabbage', 'bok choy',
      'tomato', 'onion', 'garlic', 'shallot', 'scallion', 'leek',
      'carrot', 'celery', 'broccoli', 'cauliflower', 'brussels sprout',
      'potato', 'sweet potato', 'yam', 'beet', 'turnip', 'radish',
      'cucumber', 'zucchini', 'squash', 'eggplant', 'bell pepper',
      'jalapeño', 'serrano', 'habanero', 'chili', 'pepper',
      'mushroom', 'avocado', 'asparagus', 'artichoke', 'corn',
      'peas', 'green bean', 'snap pea', 'edamame',

      // Fruits
      'apple', 'banana', 'orange', 'lemon', 'lime', 'grapefruit',
      'berry', 'strawberry', 'blueberry', 'raspberry', 'blackberry',
      'grape', 'melon', 'watermelon', 'cantaloupe', 'honeydew',
      'pear', 'peach', 'plum', 'nectarine', 'apricot',
      'mango', 'pineapple', 'papaya', 'kiwi', 'passion fruit',
      'cherry', 'date', 'fig', 'pomegranate',

      // Herbs (fresh)
      'cilantro', 'parsley', 'basil', 'mint', 'dill', 'thyme',
      'rosemary', 'sage', 'oregano', 'tarragon', 'chive',

      // Other
      'ginger', 'lemongrass', 'green', 'salad', 'herb'
    ];

    // Dairy & Eggs
    final dairyKeywords = [
      'milk', 'cream', 'half-and-half', 'heavy cream', 'whipping cream',
      'sour cream', 'crème fraîche', 'buttermilk',
      'butter', 'margarine', 'ghee',
      'cheese', 'parmesan', 'mozzarella', 'cheddar', 'swiss', 'gouda',
      'feta', 'goat cheese', 'brie', 'camembert', 'ricotta', 'cottage cheese',
      'cream cheese', 'mascarpone',
      'yogurt', 'greek yogurt', 'kefir',
      'egg', 'eggs'
    ];

    // Meat & Seafood
    final meatKeywords = [
      'chicken', 'turkey', 'duck', 'goose', 'quail',
      'beef', 'steak', 'ground beef', 'chuck', 'ribeye', 'sirloin', 'tenderloin',
      'pork', 'bacon', 'ham', 'sausage', 'chorizo', 'prosciutto', 'pancetta',
      'lamb', 'veal', 'venison', 'bison', 'rabbit',
      'fish', 'salmon', 'tuna', 'cod', 'halibut', 'tilapia', 'mahi-mahi',
      'trout', 'bass', 'mackerel', 'sardine', 'anchovy',
      'shrimp', 'prawn', 'crab', 'lobster', 'scallop', 'clam', 'mussel',
      'oyster', 'calamari', 'squid', 'octopus',
      'seafood', 'shellfish'
    ];

    // Pantry - Dry goods, canned, condiments
    final pantryKeywords = [
      // Grains & Pasta
      'flour', 'rice', 'pasta', 'noodle', 'quinoa', 'couscous', 'bulgur',
      'barley', 'farro', 'oat', 'cornmeal', 'polenta',

      // Baking
      'sugar', 'brown sugar', 'powdered sugar', 'confectioner', 'honey',
      'maple syrup', 'agave', 'molasses', 'corn syrup',
      'baking powder', 'baking soda', 'yeast', 'vanilla extract',
      'almond extract', 'cocoa', 'chocolate chip', 'chocolate',

      // Canned/Jarred
      'can', 'canned', 'tomato paste', 'tomato sauce', 'crushed tomato',
      'diced tomato', 'beans', 'chickpea', 'lentil', 'broth', 'stock',
      'coconut milk', 'evaporated milk', 'condensed milk',

      // Oils & Vinegars
      'oil', 'olive oil', 'vegetable oil', 'canola oil', 'coconut oil',
      'sesame oil', 'vinegar', 'balsamic', 'wine vinegar', 'rice vinegar',
      'apple cider vinegar',

      // Condiments & Sauces
      'ketchup', 'mustard', 'mayonnaise', 'mayo', 'relish', 'pickle',
      'soy sauce', 'worcestershire', 'hot sauce', 'sriracha', 'tabasco',
      'fish sauce', 'oyster sauce', 'hoisin', 'teriyaki',
      'salsa', 'pesto', 'tahini', 'hummus',

      // Spices & Seasonings
      'salt', 'pepper', 'spice', 'cumin', 'paprika', 'chili powder',
      'cinnamon', 'nutmeg', 'ginger powder', 'garlic powder', 'onion powder',
      'bay leaf', 'curry', 'turmeric', 'coriander', 'cardamom', 'clove',
      'allspice', 'cayenne', 'red pepper flake', 'italian seasoning',
      'herbs de provence', 'taco seasoning',

      // Nuts & Seeds
      'nut', 'almond', 'walnut', 'pecan', 'cashew', 'peanut', 'pistachio',
      'hazelnut', 'macadamia', 'pine nut',
      'seed', 'sunflower seed', 'pumpkin seed', 'sesame seed', 'chia seed',
      'flax seed', 'poppy seed',

      // Other
      'peanut butter', 'jam', 'jelly', 'preserves', 'spread'
    ];

    // Bakery
    final bakeryKeywords = [
      'bread', 'bun', 'roll', 'bagel', 'croissant', 'muffin',
      'tortilla', 'pita', 'naan', 'flatbread', 'wrap',
      'baguette', 'sourdough', 'ciabatta', 'focaccia', 'brioche',
      'english muffin', 'hamburger bun', 'hot dog bun', 'dinner roll'
    ];

    // Frozen
    final frozenKeywords = [
      'frozen', 'ice cream', 'sorbet', 'gelato', 'popsicle',
      'frozen vegetable', 'frozen fruit', 'frozen pizza',
      'frozen meal', 'frozen dinner', 'tv dinner'
    ];

    // Check categories (order matters - most specific first)
    if (frozenKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.frozen;
    }
    if (dairyKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.dairy;
    }
    if (meatKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.meat;
    }
    if (bakeryKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.bakery;
    }
    if (produceKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.produce;
    }
    if (pantryKeywords.any((k) => name.contains(k))) {
      return GroceryCategory.pantry;
    }

    // Default to pantry if no match
    return GroceryCategory.pantry;
  }
}