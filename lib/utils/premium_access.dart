import '../data/words.dart';
import '../engine/stirnraten_engine.dart';

class PremiumAccess {
  static const Set<StirnratenCategory> freeCategories = <StirnratenCategory>{
    StirnratenCategory.films,
    StirnratenCategory.series,
    StirnratenCategory.music,
    StirnratenCategory.animals,
    StirnratenCategory.food,
    StirnratenCategory.places,
    StirnratenCategory.sports,
    StirnratenCategory.plants,
    StirnratenCategory.history,
    StirnratenCategory.household,
  };

  static bool isCategoryFree(StirnratenCategory category) {
    return freeCategories.contains(category);
  }

  static bool isModeFree(GameMode mode) {
    return mode == GameMode.classic;
  }

  static bool isCategoryLocked({
    required StirnratenCategory category,
    required bool isPremium,
  }) {
    if (isPremium) return false;
    return !isCategoryFree(category);
  }

  static bool isModeLocked({
    required GameMode mode,
    required bool isPremium,
  }) {
    if (isPremium) return false;
    return !isModeFree(mode);
  }
}
