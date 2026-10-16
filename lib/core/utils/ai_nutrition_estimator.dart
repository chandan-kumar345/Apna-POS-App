import 'dart:math';
import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';

class ProductNutritionStats {
  final int calories; // kcal
  final int cholesterol; // mg
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final int healthScore; // 0 - 100
  final String healthRating; // 'Super Healthy', 'Balanced & Nutritious', etc.
  final Color healthColor;
  final List<String> highlights;

  const ProductNutritionStats({
    required this.calories,
    required this.cholesterol,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.healthScore,
    required this.healthRating,
    required this.healthColor,
    required this.highlights,
  });
}

class AiNutritionEstimator {
  /// Generates realistic, deterministic AI nutritional insights based on dish name, category, and food type
  static ProductNutritionStats estimate(MenuItemModel item) {
    final name = item.name.toLowerCase().trim();
    final cat = item.category.toLowerCase().trim();
    final itemType = item.itemType.toLowerCase();

    // Deterministic pseudo-random seed based on name to ensure consistent values
    int seed = 0;
    for (int i = 0; i < name.length; i++) {
      seed = (seed * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final rnd = Random(seed);

    int calories;
    int cholesterol;
    double protein;
    double carbs;
    double fat;
    int healthScore;
    String healthRating;
    Color healthColor;
    List<String> highlights = [];

    final isBeverage = itemType.contains('beverage') || cat.contains('beverage') || cat.contains('drink') || cat.contains('shake') || name.contains('tea') || name.contains('coffee') || name.contains('juice') || name.contains('lassi');
    final isSalad = cat.contains('salad') || name.contains('salad') || name.contains('sprout');
    final isSoup = cat.contains('soup') || name.contains('soup');
    final isDessert = cat.contains('dessert') || cat.contains('sweet') || name.contains('ice cream') || name.contains('halwa') || name.contains('cake') || name.contains('gulab');
    final isPaneerCheese = name.contains('paneer') || name.contains('cheese');
    final isChickenMeat = itemType.contains('non-veg') || itemType.contains('non_veg') || name.contains('chicken') || name.contains('mutton') || name.contains('fish') || name.contains('prawn');
    final isEgg = itemType.contains('egg') || name.contains('egg') || name.contains('omelette');
    final isDalLentils = name.contains('dal') || name.contains('lentil') || name.contains('chole') || name.contains('rajma');
    final isRotiBread = name.contains('roti') || name.contains('naan') || name.contains('paratha') || name.contains('bread');

    if (isSalad) {
      calories = 110 + rnd.nextInt(60);
      cholesterol = 0;
      protein = 3.5 + rnd.nextInt(4);
      carbs = 12.0 + rnd.nextInt(8);
      fat = 2.0 + rnd.nextInt(3);
      healthScore = 92 + rnd.nextInt(7);
      healthRating = 'Super Healthy';
      healthColor = const Color(0xFF059669);
      highlights = ['100% Zero Cholesterol', 'High Dietary Fiber', 'Rich in Vitamins', 'Low Calorie'];
    } else if (isSoup) {
      calories = 90 + rnd.nextInt(70);
      cholesterol = isChickenMeat ? (15 + rnd.nextInt(15)) : 0;
      protein = isChickenMeat ? (12.0 + rnd.nextInt(6)) : (4.0 + rnd.nextInt(4));
      carbs = 10.0 + rnd.nextInt(8);
      fat = 2.0 + rnd.nextInt(4);
      healthScore = 88 + rnd.nextInt(8);
      healthRating = 'Warm & Nourishing';
      healthColor = const Color(0xFF0284C7);
      highlights = ['Easy on Digestion', 'Hydrating & Light', 'Low Fat Choice'];
    } else if (isBeverage) {
      final isDairy = name.contains('shake') || name.contains('lassi') || name.contains('milk');
      calories = isDairy ? (180 + rnd.nextInt(120)) : (60 + rnd.nextInt(60));
      cholesterol = isDairy ? (10 + rnd.nextInt(15)) : 0;
      protein = isDairy ? (5.0 + rnd.nextInt(5)) : (1.0 + rnd.nextInt(2));
      carbs = 20.0 + rnd.nextInt(25);
      fat = isDairy ? (4.0 + rnd.nextInt(5)) : 0.5;
      healthScore = isDairy ? 78 : 84;
      healthRating = isDairy ? 'Calcium Rich' : 'Instant Refreshment';
      healthColor = const Color(0xFF0284C7);
      highlights = isDairy ? ['Natural Calcium', 'Protein Boost', 'Creamy Energy'] : ['Quick Hydration', 'Zero Fat', 'Refreshing'];
    } else if (isDessert) {
      calories = 310 + rnd.nextInt(130);
      cholesterol = 25 + rnd.nextInt(25);
      protein = 4.0 + rnd.nextInt(4);
      carbs = 45.0 + rnd.nextInt(25);
      fat = 12.0 + rnd.nextInt(10);
      healthScore = 65 + rnd.nextInt(8);
      healthRating = 'Indulgent Treat';
      healthColor = const Color(0xFFD97706);
      highlights = ['Rich Flavor', 'Instant Glucose', 'Festive Favorite'];
    } else if (isChickenMeat) {
      calories = 270 + rnd.nextInt(110);
      cholesterol = 55 + rnd.nextInt(35);
      protein = 24.0 + rnd.nextInt(12);
      carbs = 8.0 + rnd.nextInt(15);
      fat = 11.0 + rnd.nextInt(8);
      healthScore = 86 + rnd.nextInt(7);
      healthRating = 'High Protein Power';
      healthColor = const Color(0xFF059669);
      highlights = ['Rich Lean Protein', 'Muscle Recovery', 'Essential Amino Acids', 'Iron & Zinc'];
    } else if (isEgg) {
      calories = 190 + rnd.nextInt(70);
      cholesterol = 180 + rnd.nextInt(40);
      protein = 13.0 + rnd.nextInt(6);
      carbs = 4.0 + rnd.nextInt(8);
      fat = 10.0 + rnd.nextInt(5);
      healthScore = 84 + rnd.nextInt(6);
      healthRating = 'Complete Protein';
      healthColor = const Color(0xFF059669);
      highlights = ['Choline Rich', 'High Bioavailability', 'Brain Health Booster'];
    } else if (isPaneerCheese) {
      calories = 290 + rnd.nextInt(90);
      cholesterol = 22 + rnd.nextInt(18);
      protein = 16.0 + rnd.nextInt(7);
      carbs = 12.0 + rnd.nextInt(10);
      fat = 17.0 + rnd.nextInt(8);
      healthScore = 83 + rnd.nextInt(8);
      healthRating = 'Nutrient Dense';
      healthColor = const Color(0xFF059669);
      highlights = ['Rich Calcium', 'Vegetarian Protein', 'Sustained Satiety'];
    } else if (isDalLentils) {
      calories = 190 + rnd.nextInt(60);
      cholesterol = 0;
      protein = 12.0 + rnd.nextInt(6);
      carbs = 26.0 + rnd.nextInt(10);
      fat = 4.0 + rnd.nextInt(4);
      healthScore = 90 + rnd.nextInt(6);
      healthRating = 'Heart Healthy';
      healthColor = const Color(0xFF059669);
      highlights = ['Zero Cholesterol', 'High Soluble Fiber', 'Folate & Minerals'];
    } else if (isRotiBread) {
      calories = 140 + rnd.nextInt(80);
      cholesterol = 0;
      protein = 4.5 + rnd.nextInt(3);
      carbs = 28.0 + rnd.nextInt(12);
      fat = 3.0 + rnd.nextInt(4);
      healthScore = 82 + rnd.nextInt(8);
      healthRating = 'Wholesome Carbs';
      healthColor = const Color(0xFF475569);
      highlights = ['Whole Wheat Goodness', 'Zero Cholesterol', 'Complex Carbohydrates'];
    } else {
      // General savory dish
      calories = 220 + rnd.nextInt(110);
      cholesterol = 12 + rnd.nextInt(18);
      protein = 9.0 + rnd.nextInt(8);
      carbs = 24.0 + rnd.nextInt(14);
      fat = 8.0 + rnd.nextInt(7);
      healthScore = 81 + rnd.nextInt(10);
      healthRating = 'Balanced Dish';
      healthColor = const Color(0xFF059669);
      highlights = ['Traditional Spices', 'Balanced Macros', 'Cooked Fresh'];
    }

    return ProductNutritionStats(
      calories: calories,
      cholesterol: cholesterol,
      protein: protein,
      carbs: carbs,
      fat: fat,
      healthScore: healthScore,
      healthRating: healthRating,
      healthColor: healthColor,
      highlights: highlights,
    );
  }
}
