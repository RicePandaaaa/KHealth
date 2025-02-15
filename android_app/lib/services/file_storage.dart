import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorage {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/ble_data.txt');
  }

  /// Writes [data] to the file by appending a newline.
  static Future<File> writeData(String data) async {
    final file = await _localFile;
    return file.writeAsString('$data\n', mode: FileMode.append);
  }
} 