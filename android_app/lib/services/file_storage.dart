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
  /// The parameter [data] should be a string in the format "YYYY-MM-DD,HH:mm,value"
  /// (for example: "2023-10-01,14:30,95") so it can later be parsed.
  static Future<File> writeData(String data) async {
    final file = await _localFile;
    // Debug: print what we're appending.
    print("Appending data to file: $data");
    return file.writeAsString('$data\n', mode: FileMode.append);
  }

  /// Writes a [value] by automatically appending the current date and time.
  ///
  /// The file will receive a new line in the format "YYYY-MM-DD,HH:mm:ss.SSS,value".
  /// (Uses 24hr format with milliseconds.)
  static Future<File> writeValue(double value) async {
    final now = DateTime.now();
    // Format date ensuring two-digit month and day.
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // Format time in 24hr format with two digits for hour and minute, and include seconds and milliseconds.
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    String newData = '$formattedDate,$formattedTime,$value';

    return writeData(newData);
  }

  /// Reads the file content as a string.
  static Future<String> readData() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();
      return contents;
    } catch (e) {
      return '';
    }
  }

  /// Parses the file contents into a list of [DataEntry] objects.
  ///
  /// Each line should be in the format "YYYY-MM-DD,HH:mm,value".
  /// Lines that do not parse correctly are skipped.
  static Future<List<DataEntry>> parseData() async {
    String content = await readData();
    List<String> lines =
        content.split('\n').where((line) => line.trim().isNotEmpty).toList();

    List<DataEntry> entries = [];
    for (String line in lines) {
      List<String> parts = line.split(',');
      // Expect three parts: date, time, and value.
      if (parts.length == 3) {
        String datePart = parts[0].trim();
        String timePart = parts[1].trim();
        String valuePart = parts[2].trim();

        // Use manual parsing for the date and time.
        try {
          List<String> dateComponents = datePart.split('-');
          List<String> timeComponents = timePart.split(':');
          List<String> secondComponents = timeComponents[2].split('.');

          if (dateComponents.length == 3 && timeComponents.length == 3) {
            int year = int.parse(dateComponents[0]);
            int month = int.parse(dateComponents[1]);
            int day = int.parse(dateComponents[2]);
            int hour = int.parse(timeComponents[0]);
            int minute = int.parse(timeComponents[1]);
            int second = int.parse(secondComponents[0]);
            int millisecond = int.parse(secondComponents[1]);

            DateTime dateTime = DateTime(year, month, day, hour, minute, second, millisecond);
            double? value = double.tryParse(valuePart);
            if (value != null) {
              entries.add(DataEntry(date: dateTime, value: value));
            }
          }
        } catch (e) {}
      }
    }
    return entries;
  }
} 