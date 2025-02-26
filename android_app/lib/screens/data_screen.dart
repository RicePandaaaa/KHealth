import 'dart:math';
import 'dart:io';

import '../main.dart';
import '../services/file_storage.dart';
import '../services/bluetooth_manager.dart';
import '../widgets/line_chart_widget.dart';

import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'home_screen.dart';
import 'bluetooth_screen.dart';
import 'button_screen.dart';
import 'recent_readings_screen.dart';



class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> with RouteAware {
  // State variable to keep track of the active button.
  int _activeButtonIndex = 0;

  // Aggregate values; if there is no data, these remain null.
  double? dailyMin;
  double? dailyAvg;
  double? dailyMax;
  double? weeklyMin;
  double? weeklyAvg;
  double? weeklyMax;
  double? monthlyMin;
  double? monthlyAvg;
  double? monthlyMax;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the route observer to refresh data when coming back.
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // This method is called when the current route has been popped back to (e.g., after deletion).
  @override
  void didPopNext() {
    loadDataFromFile(); // Refresh aggregate data.
  }

  @override
  void initState() {
    super.initState();
    loadDataFromFile();
  }

  // Loads the file data, parses the entries, and computes aggregates.
  Future<void> loadDataFromFile() async {
    List<DataEntry> entries = await FileStorage.parseData();
    DateTime now = DateTime.now();

    // Daily: entries matching today's date.
    List<DataEntry> dailyEntries = entries.where((entry) =>
        entry.date.year == now.year &&
        entry.date.month == now.month &&
        entry.date.day == now.day).toList();

    // Weekly: entries from the last 7 days.
    DateTime weekAgo = now.subtract(const Duration(days: 7));
    List<DataEntry> weeklyEntries =
        entries.where((entry) => entry.date.isAfter(weekAgo)).toList();

    // Monthly: entries from the last 30 days.
    DateTime monthAgo = now.subtract(const Duration(days: 30));
    List<DataEntry> monthlyEntries =
        entries.where((entry) => entry.date.isAfter(monthAgo)).toList();

    setState(() {
      // Daily aggregates.
      if (dailyEntries.isEmpty) {
        dailyMin = null;
        dailyAvg = null;
        dailyMax = null;
      } else {
        dailyMin = _computeMin(dailyEntries);
        dailyAvg = _computeAvg(dailyEntries);
        dailyMax = _computeMax(dailyEntries);
      }

      // Weekly aggregates.
      if (weeklyEntries.isEmpty) {
        weeklyMin = null;
        weeklyAvg = null;
        weeklyMax = null;
      } else {
        weeklyMin = _computeMin(weeklyEntries);
        weeklyAvg = _computeAvg(weeklyEntries);
        weeklyMax = _computeMax(weeklyEntries);
      }

      // Monthly aggregates.
      if (monthlyEntries.isEmpty) {
        monthlyMin = null;
        monthlyAvg = null;
        monthlyMax = null;
      } else {
        monthlyMin = _computeMin(monthlyEntries);
        monthlyAvg = _computeAvg(monthlyEntries);
        monthlyMax = _computeMax(monthlyEntries);
      }
    });
  }

  // Helper methods to compute aggregates.
  double _computeMin(List<DataEntry> entries) {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.value).reduce(min);
  }

  double _computeMax(List<DataEntry> entries) {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.value).reduce(max);
  }

  double _computeAvg(List<DataEntry> entries) {
    if (entries.isEmpty) return 0;
    double total = entries.fold(0, (prev, e) => prev + e.value);
    return total / entries.length;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: GestureDetector(
        onTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        },
        child: Image.asset(
          'assets/images/company_logo.png',
          height: 60,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: BluetoothManager().connectedDevice != null ? Colors.lightBlue : Colors.red,
              size: 30.0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BluetoothScreen()),
              );
            },
          ),
        ),
      ],
      centerTitle: false,
    );
  }

  // A widget that displays a label and an aggregate value.
  Widget _buildLevelBox(String label, double? value) {
    // Use the computed color only when a value exists; otherwise, white.
    Color boxColor = value != null ? _getBoxColor(value) : Colors.white;
    String displayText = value != null ? value.toStringAsFixed(1) : "N/A";
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black, fontSize: 18)),
          Text(
            displayText,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 25,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Returns a color based on the aggregate value.
  Color _getBoxColor(double value) {
    if (value < 70 || value > 100) {
      return Colors.red.shade300;
    } else if ((value >= 70 && value < 75) || (value > 95 && value <= 100)) {
      return Colors.yellow.shade200;
    } else {
      return Colors.green.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Graph Section (replaces the top image)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: FutureBuilder<List<DataEntry>>(
                  future: FileStorage.parseData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()));
                    } else if (snapshot.hasError) {
                      return SizedBox(
                          height: 300,
                          child:
                              Center(child: Text("Error: ${snapshot.error}")));
                    }
                    final allEntries = snapshot.data ?? [];
                    DateTime now = DateTime.now();
                    List<DataEntry> filteredEntries;
                    if (_activeButtonIndex == 0) {
                      // Today – filter by matching year, month, and day.
                      filteredEntries = allEntries
                          .where((entry) =>
                              entry.date.year == now.year &&
                              entry.date.month == now.month &&
                              entry.date.day == now.day)
                          .toList();
                    } else if (_activeButtonIndex == 1) {
                      // Last 7 days.
                      DateTime weekAgo = now.subtract(const Duration(days: 7));
                      filteredEntries = allEntries
                          .where((entry) => entry.date.isAfter(weekAgo))
                          .toList();
                    } else {
                      // Last 30 days.
                      DateTime monthAgo = now.subtract(const Duration(days: 30));
                      filteredEntries = allEntries
                          .where((entry) => entry.date.isAfter(monthAgo))
                          .toList();
                    }
                    if (filteredEntries.isEmpty) {
                      return const SizedBox(
                          height: 300,
                          child: Center(child: Text("No data available for chart.")));
                    }
                    return LineChartWidget(entries: filteredEntries);
                  },
                ),
              ),

              // Buttons to switch the displayed graph view.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activeButtonIndex == 0
                                ? Colors.teal
                                : Colors.white,
                            foregroundColor: _activeButtonIndex == 0
                                ? Colors.white
                                : Colors.teal,
                            side: const BorderSide(
                                color: Colors.teal, width: 2.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              _activeButtonIndex = 0;
                            });
                          },
                          child: const Text("Today", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activeButtonIndex == 1
                                ? Colors.teal
                                : Colors.white,
                            foregroundColor: _activeButtonIndex == 1
                                ? Colors.white
                                : Colors.teal,
                            side: const BorderSide(
                                color: Colors.teal, width: 2.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              _activeButtonIndex = 1;
                            });
                          },
                          child: const Text("7 Days", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activeButtonIndex == 2
                                ? Colors.teal
                                : Colors.white,
                            foregroundColor: _activeButtonIndex == 2
                                ? Colors.white
                                : Colors.teal,
                            side: const BorderSide(
                                color: Colors.teal, width: 2.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              _activeButtonIndex = 2;
                            });
                          },
                          child: const Text("30 Days", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Display the aggregated data.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
                child: Column(
                  children: [
                    const Text("Daily Levels (mg/dL)",
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                    Row(
                      children: [
                        Expanded(child: _buildLevelBox("Min", dailyMin)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Avg", dailyAvg)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Max", dailyMax)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Weekly Levels (mg/dL)",
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                    Row(
                      children: [
                        Expanded(child: _buildLevelBox("Min", weeklyMin)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Avg", weeklyAvg)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Max", weeklyMax)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Monthly Levels (mg/dL)",
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                    Row(
                      children: [
                        Expanded(child: _buildLevelBox("Min", monthlyMin)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Avg", monthlyAvg)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildLevelBox("Max", monthlyMax)),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Buttons Section.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row with "Home" and "History" buttons.
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const FaIcon(
                              FontAwesomeIcons.house,
                              color: Colors.teal,
                            ),
                            label: const Text("Home"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomeScreen()),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const FaIcon(
                              FontAwesomeIcons.list,
                              color: Colors.teal,
                            ),
                            label: const Text("History"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const RecentReadingsScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size.fromHeight(60),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ButtonScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.droplet,
                              size: 30,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 20),
                            const Text(
                              "Start New Reading",
                              style: TextStyle(
                                  fontSize: 25, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    
                    // Button to download data as PDF
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size.fromHeight(60),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _generatePdf,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download, size: 30, color: Colors.white),
                            const SizedBox(width: 20),
                            const Text(
                              "Download Data (PDF)",
                              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    // Fetch data entries
    List<DataEntry> entries = await FileStorage.parseData();

    // Add a page to the PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('User Data Report', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Data Entries:', style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              ...entries.map((entry) {
                return pw.Text(
                  'Date: ${entry.date}, Value: ${entry.value.toStringAsFixed(1)} mg/dL',
                  style: pw.TextStyle(fontSize: 14),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Save the PDF to a file
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/user_data_report.pdf");
    await file.writeAsBytes(await pdf.save());

    // Use the printing package to share the PDF
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'user_data_report.pdf');
  }
}
