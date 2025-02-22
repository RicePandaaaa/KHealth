import 'package:flutter/material.dart';
import 'button_screen.dart';
import 'data_screen.dart';
import 'bluetooth_screen.dart';
import '../services/bluetooth_manager.dart';
import '../services/file_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart'; // Import the global routeObserver

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  DataEntry? _mostRecent;
  DataEntry? _previous;
  double? _dailyAverage;
  int _dailyCount = 0;

  /// Computes a friendly time-difference string for the last reading.
  String get _lastReadingText {
    if (_mostRecent == null) return "N/A";
    final diff = DateTime.now().difference(_mostRecent!.date);
    if (diff.inHours >= 1) {
      return "${diff.inHours} hour${diff.inHours > 1 ? "s" : ""} ago";
    } else if (diff.inMinutes >= 1) {
      return "${diff.inMinutes} minute${diff.inMinutes > 1 ? "s" : ""} ago";
    } else {
      return "Just now";
    }
  }

  /// Loads data from storage (using FileStorage.parseData) and computes:
  /// - Most recent and previous reading (from all stored entries).
  /// - Daily average and daily count (from today's entries).
  Future<void> _loadData() async {
    List<DataEntry> entries = await FileStorage.parseData();
    if (entries.isNotEmpty) {
      // Sort entries by date descending (most recent first).
      entries.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _mostRecent = entries.first;
        _previous = entries.length > 1 ? entries[1] : null;
      });
    } else {
      setState(() {
        _mostRecent = null;
        _previous = null;
      });
    }

    // Filter entries for today's date.
    final now = DateTime.now();
    List<DataEntry> dailyEntries = entries.where((entry) =>
        entry.date.year == now.year &&
        entry.date.month == now.month &&
        entry.date.day == now.day).toList();

    if (dailyEntries.isNotEmpty) {
      double avg = dailyEntries.fold(0.0, (prev, e) => prev + e.value) / dailyEntries.length;
      setState(() {
        _dailyAverage = avg;
        _dailyCount = dailyEntries.length;
      });
    } else {
      setState(() {
        _dailyAverage = null;
        _dailyCount = 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the route observer
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    // Unsubscribe from the route observer
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the current route has been popped back to
    _loadData(); // Refresh data
  }

  // AppBar with Bluetooth status icon.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
          child: Icon(
            Icons.bluetooth,
            color: BluetoothManager().connectedDevice != null ? Colors.lightBlue : Colors.red,
            size: 40.0,
          ),
        ),
      ],
      centerTitle: false,
      elevation: 0,
    );
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
              const SizedBox(height: 10),
              // Row of two buttons: Insights and Bluetooth.
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal, width: 2.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(0, 60),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DataScreen()),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.chartColumn, size: 25, color: Colors.teal),
                          const SizedBox(width: 8),
                          const Text("Insights", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal, width: 2.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(0, 60),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BluetoothScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth,
                            color: BluetoothManager().connectedDevice != null ? Colors.blue : Colors.red,
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            BluetoothManager().connectedDevice != null ? "Connected" : "Disconnected",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BluetoothManager().connectedDevice != null ? Colors.blue : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // First segment: Three containers for readings.
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 16.0),
                child: Column(
                  children: [
                    // Most Recent Reading.
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Most Recent Reading',
                            style: TextStyle(fontSize: 25, color: Colors.black87),
                          ),
                          Text(
                            _mostRecent != null
                                ? "${_mostRecent!.value.toStringAsFixed(1)} mg/DL"
                                : "N/A",
                            style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    // Previous Reading.
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Previous Reading',
                            style: TextStyle(fontSize: 25, color: Colors.black87),
                          ),
                          Text(
                            _previous != null
                                ? "${_previous!.value.toStringAsFixed(1)} mg/DL"
                                : "N/A",
                            style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    // Daily Average.
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Daily Average',
                            style: TextStyle(fontSize: 25, color: Colors.black87),
                          ),
                          Text(
                            _dailyAverage != null
                                ? "${_dailyAverage!.toStringAsFixed(1)} mg/DL"
                                : "N/A",
                            style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Second segment: Two containers for "Last Reading" and "Readings done today".
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Last Reading',
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _mostRecent != null ? _lastReadingText : "N/A",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Readings done today',
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _dailyCount > 0 ? "$_dailyCount reading${_dailyCount > 1 ? "s" : ""}" : "N/A",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // "Start New Reading" button.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size.fromHeight(60),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ButtonScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.droplet, size: 30, color: Colors.white),
                      const SizedBox(width: 20),
                      const Text(
                        "Start New Reading",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
