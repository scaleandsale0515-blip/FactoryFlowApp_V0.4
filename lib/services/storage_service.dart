import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  static final StorageService instance = StorageService._init();
  StorageService._init();

  Future<bool> requestPermission() async {
    var status = await Permission.storage.request();

    if (status.isGranted) return true;

    // For Android 11+
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    return false;
  }

  Future<Directory?> getAppFolder() async {
    if (!await requestPermission()) return null;

    final dir = Directory('/storage/emulated/0/FactoryFlow_Data');

    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<bool> checkOldDataExists() async {
    final dir = Directory('/storage/emulated/0/FactoryFlow_Data');
    return await dir.exists();
  }
}
