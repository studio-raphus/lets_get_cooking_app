import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grocery_item.dart';

class GroceryList {
  final String id;
  final String name;
  final List<GroceryItem> items;
  final DateTime createdAt;
  final bool isActive;

  GroceryList({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory GroceryList.fromJson(Map<String, dynamic> json) {
    return GroceryList(
      id: json['id'] as String,
      name: json['name'] as String,
      items: (json['items'] as List)
          .map((i) => GroceryItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class GroceryProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<GroceryList> _groceryLists = [];
  bool _isLoading = false;
  String? _error;

  List<GroceryList> get groceryLists => _groceryLists;
  List<GroceryList> get activeLists =>
      _groceryLists.where((list) => list.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all grocery lists
  Future<void> loadGroceryLists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      // For demo mode: if no user, use empty list
      if (user == null) {
        _groceryLists = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('grocery_lists')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _groceryLists = (response as List)
          .map((json) => GroceryList.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _groceryLists = [];
      notifyListeners();
    }
  }

  /// Save a new grocery list
  Future<void> saveGroceryList(String name, List<GroceryItem> items) async {
    try {
      final user = _supabase.auth.currentUser;

      final groceryList = GroceryList(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        items: items,
        createdAt: DateTime.now(),
      );

      // For demo mode: if no user, just store locally
      if (user == null) {
        _groceryLists.insert(0, groceryList);
        notifyListeners();
        return;
      }

      final data = groceryList.toJson();
      data['user_id'] = user.id;

      await _supabase.from('grocery_lists').insert(data);

      _groceryLists.insert(0, groceryList);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a grocery list
  Future<void> deleteGroceryList(String listId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('grocery_lists')
          .delete()
          .eq('id', listId)
          .eq('user_id', user.id);

      _groceryLists.removeWhere((list) => list.id == listId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Archive a grocery list
  Future<void> archiveGroceryList(String listId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('grocery_lists')
          .update({'is_active': false})
          .eq('id', listId)
          .eq('user_id', user.id);

      final index = _groceryLists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        _groceryLists[index] = GroceryList(
          id: _groceryLists[index].id,
          name: _groceryLists[index].name,
          items: _groceryLists[index].items,
          createdAt: _groceryLists[index].createdAt,
          isActive: false,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}