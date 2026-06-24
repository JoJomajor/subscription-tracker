import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class IconService {
  static Future<IconData?> pickIcon(BuildContext context) async {
    // Просто вызываем метод без параметров, если они конфликтуют
    IconPickerIcon? icon = await showIconPicker(
      context,
    );

    return icon?.data;
  }
}