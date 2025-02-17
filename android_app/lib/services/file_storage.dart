import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// A model representing a data entry that contains a date and a value.
class DataEntry {
  final DateTime date;
  final double value;

  DataEntry({required this.date, required this.value});

  @override
  String toString() => 'DataEntry(date: $date, value: $value)';
}

class FileStorage {
  // Returns the app's documents directory path.
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Returns a reference to the predetermined file (e.g., ble_data.txt).
  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/ble_data.txt');
  }

  /// Writes [data] to the file by appending a newline.
  ///
  /// The parameter [data] should be a string in the format "YYYY-MM-DD,Value"
  /// (for example: "2023-10-01,95") so it can later be parsed.
  static Future<File> writeData(String data) async {
    final file = await _localFile;
    // Debug: print what we're appending.
    print("Appending data to file: $data");
    return file.writeAsString('$data\n', mode: FileMode.append);
  }

  /// Writes a [value] by automatically appending the current date.
  ///
  /// The file will receive a new line in the format "YYYY-MM-DD,Value".
  static Future<File> writeValue(double value) async {
    final now = DateTime.now();
    // Format date ensuring two-digit month and day.
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    String newData = '$formattedDate,$value';
    // Debug: Show the combined new data entry.
    print("Storing new data entry: $newData");
    return writeData(newData);
  }

  /// Reads the file content as a string.
  static Future<String> readData() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();
      // Debug: Log the content read from file.
      print("Read data from file:\n$contents");
      return contents;
    } catch (e) {
      print('Error reading file: $e');
      return '';
    }
  }

  /// Parses the file contents into a list of [DataEntry] objects.
  ///
  /// Each line should be in the format "YYYY-MM-DD,Value".
  /// Lines that do not parse correctly are skipped.
  static Future<List<DataEntry>> parseData() async {
    String content = await readData();
    List<String> lines =
        content.split('\n').where((line) => line.trim().isNotEmpty).toList();

    List<DataEntry> entries = [];
    for (String line in lines) {
      List<String> parts = line.split(',');
      if (parts.length == 2) {
        DateTime? date = DateTime.tryParse(parts[0].trim());
        double? value = double.tryParse(parts[1].trim());
        if (date != null && value != null) {
          entries.add(DataEntry(date: date, value: value));
        }
      }
    }

    // Debug: Print out the parsed entries.
    print("Parsed ${entries.length} entries from file: $entries");
    return entries;
  }
} 