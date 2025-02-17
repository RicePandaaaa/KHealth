import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/file_storage.dart';

class RecentReadingsScreen extends StatefulWidget {
  const RecentReadingsScreen({super.key});

  @override
  State<RecentReadingsScreen> createState() => _RecentReadingsScreenState();
}

class _RecentReadingsScreenState extends State<RecentReadingsScreen> {
  List<DataEntry> _allEntries = [];
  int currentPage = 0;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  /// Loads all entries from file_storage, sorts them descending (most-recent first),
  /// and updates the state.
  Future<void> loadEntries() async {
    List<DataEntry> entries = await FileStorage.parseData();
    // Sort list descending by date (most recent first)
    entries.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _allEntries = entries;
      // Reset page to 0 if current page is now out of bounds.
      if (currentPage > (entries.length - 1) / itemsPerPage) {
        currentPage = 0;
      }
    });
  }

  /// Permanently removes an entry from the file.
  /// This function reads the file, removes the first matching line,
  /// and then rewrites the file.
  Future<void> deleteEntry(DataEntry entry) async {
    // Read the full file content.
    String content = await FileStorage.readData();

    List<String> lines = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    // Construct the target line using the same format as FileStorage.writeValue.
    final formattedDate = '${entry.date.year}-'
        '${entry.date.month.toString().padLeft(2, '0')}-'
        '${entry.date.day.toString().padLeft(2, '0')}';
    String targetLine = "$formattedDate,${entry.value}";
    
    // Remove only the first occurrence that matches.
    bool removed = false;
    List<String> newLines = [];
    for (String line in lines) {
      if (!removed && line.trim() == targetLine) {
        removed = true;
        continue;
      }
      newLines.add(line);
    }
    
    // Get the file reference. We recreate the file path as in FileStorage.
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/ble_data.txt';
    File file = File(filePath);
    
    // Rewrite the file with updated contents.
    await file.writeAsString(newLines.join("\n") + (newLines.isNotEmpty ? "\n" : ""));
    print("Deleted entry: $targetLine");
    
    // Reload entries after deletion.
    await loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    int totalEntries = _allEntries.length;
    int totalPages = (totalEntries / itemsPerPage).ceil();

    // Calculate start and end indices for current page.
    int startIndex = currentPage * itemsPerPage;
    int endIndex = ((currentPage + 1) * itemsPerPage).clamp(0, totalEntries);

    List<DataEntry> currentEntries = _allEntries.sublist(startIndex, endIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Readings"),
      ),
      body: Column(
        children: [
          Expanded(
            child: currentEntries.isEmpty
                ? const Center(child: Text("No readings available."))
                : ListView.builder(
                    itemCount: currentEntries.length,
                    itemBuilder: (context, index) {
                      final DataEntry entry = currentEntries[index];
                      final formattedDate = '${entry.date.year}-'
                          '${entry.date.month.toString().padLeft(2, '0')}-'
                          '${entry.date.day.toString().padLeft(2, '0')}';
                      return ListTile(
                        title: Text(formattedDate),
                        subtitle: Text("Value: ${entry.value}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await deleteEntry(entry);
                          },
                        ),
                      );
                    },
                  ),
          ),
          // Pagination controls.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left (more recent) button - only active if not on the first page.
              if (currentPage > 0)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentPage--;
                    });
                  },
                  child: const Icon(Icons.arrow_left),
                ),
              Text("Page ${currentPage + 1} / $totalPages"),
              // Right (later readings) button.
              if (currentPage < totalPages - 1)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentPage++;
                    });
                  },
                  child: const Icon(Icons.arrow_right),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
} 