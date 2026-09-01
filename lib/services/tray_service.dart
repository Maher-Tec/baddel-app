import 'package:tray_manager/tray_manager.dart';

class TrayService {
  const TrayService();

  Future<void> initialize({required String iconPath, required String tooltip}) async {
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip(tooltip);
  }

  Future<void> updateMenu({required bool paused}) async {
    await trayManager.setContextMenu(
      Menu(items: [
        MenuItem(key: 'show', label: 'Open Baddel'),
        MenuItem(key: 'pause', label: paused ? 'Resume detection' : 'Pause detection'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit Baddel'),
      ]),
    );
  }

  Future<void> destroy() => trayManager.destroy();
}
