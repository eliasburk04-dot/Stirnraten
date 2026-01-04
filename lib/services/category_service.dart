import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomCategory {
  final String name;
  final List<String> words;

  CustomCategory({required this.name, required this.words});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'words': words,
    };
  }

  factory CustomCategory.fromMap(Map<String, dynamic> map) {
    return CustomCategory(
      name: map['name'] ?? '',
      words: List<String>.from(map['words'] ?? []),
    );
  }
}

class CategoryService {
  static const String _storageKey = 'custom_categories';

  Future<List<CustomCategory>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? categoriesJson = prefs.getString(_storageKey);
    
    if (categoriesJson == null) return [];

    try {
      final List<dynamic> decoded = json.decode(categoriesJson);
      return decoded.map((item) => CustomCategory.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCategory(String name, List<String> words) async {
    final categories = await getCustomCategories();
    
    // Remove if already exists with same name
    categories.removeWhere((c) => c.name == name);
    
    categories.add(CustomCategory(name: name, words: words));
    
    await _saveToPrefs(categories);
  }

  Future<void> deleteCategory(String name) async {
    final categories = await getCustomCategories();
    categories.removeWhere((c) => c.name == name);
    await _saveToPrefs(categories);
  }

  Future<void> _saveToPrefs(List<CustomCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(categories.map((c) => c.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
