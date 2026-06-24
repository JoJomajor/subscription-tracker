import 'package:flutter/material.dart';

class IconLibrary {
  // Базовый набор иконок по категориям
  static final Map<String, IconData> categoryIcons = {
    'Видео': Icons.play_circle_fill,
    'Музыка': Icons.music_note,
    'Игры': Icons.sports_esports,
    'Софт': Icons.laptop_mac,
    'Другое': Icons.category,
  };

  // Метод для получения иконки по названию категории
  static IconData getIconForCategory(String category) {
    return categoryIcons[category] ?? Icons.subscriptions;
  }
}