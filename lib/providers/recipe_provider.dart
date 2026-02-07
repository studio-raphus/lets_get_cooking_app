import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';

class RecipeProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get wantToCookRecipes => _recipes.where((r) => r.wantToCook).toList();
  List<Recipe> get cookedRecipes => _recipes.where((r) => r.isCooked).toList(); // Updated to use isCooked
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _recipes = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('recipes')
          .select()
          .eq('user_id', user.id) // Ensure we only get current user's data
          .order('created_at', ascending: false);

      _recipes = (response as List)
          .map((json) => Recipe.fromJson(json))
          .toList();

    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading recipes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new recipe
  Future<void> addRecipe(Recipe recipe) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final recipeData = recipe.toJson();
      recipeData['user_id'] = user.id;

      await _supabase.from('recipes').insert(recipeData);
      await loadRecipes();
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  /// Update an existing recipe
  Future<void> updateRecipe(Recipe recipe) async {
    try {
      final user = _supabase.auth.currentUser;

      // For demo mode: if no user, just update locally
      if (user == null) {
        debugPrint('Demo mode - updating recipe locally only');
        final index = _recipes.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _recipes[index] = recipe;
          notifyListeners();
        }
        return;
      }

      await _supabase
          .from('recipes')
          .update(recipe.toJson())
          .eq('id', recipe.id)
          .eq('user_id', user.id);

      final index = _recipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) {
        _recipes[index] = recipe;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Error updating recipe: $e');
      rethrow;
    }
  }

  /// Delete a recipe
  Future<void> deleteRecipe(String recipeId) async {
    try {
      final user = _supabase.auth.currentUser;

      // For demo mode: if no user, just delete locally
      if (user == null) {
        debugPrint('Demo mode - deleting recipe locally only');
        _recipes.removeWhere((r) => r.id == recipeId);
        notifyListeners();
        return;
      }

      await _supabase
          .from('recipes')
          .delete()
          .eq('id', recipeId)
          .eq('user_id', user.id);

      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Error deleting recipe: $e');
      rethrow;
    }
  }

  /// Toggle cooked status
  Future<void> toggleCookedStatus(String recipeId) async {
    try {
      final index = _recipes.indexWhere((r) => r.id == recipeId);
      if (index == -1) return;

      final recipe = _recipes[index];
      final updatedRecipe = recipe.copyWith(
        wantToCook: !recipe.wantToCook,
        cookedDate: !recipe.wantToCook ? null : DateTime.now(),
      );

      await updateRecipe(updatedRecipe);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Error toggling cooked status: $e');
    }
  }

  /// Search recipes
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return _recipes;

    final lowerQuery = query.toLowerCase();
    return _recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
          recipe.ingredients
              .any((ing) => ing.item.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get recipes by tag
  List<Recipe> getRecipesByTag(String tag) {
    return _recipes
        .where((recipe) =>
        recipe.tags.any((t) => t.toLowerCase() == tag.toLowerCase()))
        .toList();
  }
}