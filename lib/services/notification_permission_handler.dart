import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionHandler {
  // Проверка наличия разрешения
  static Future<bool> checkPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  // Запрос разрешения
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  // Открыть настройки приложения (если пользователь запретил)
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}