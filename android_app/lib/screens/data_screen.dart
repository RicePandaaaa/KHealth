import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart'; // Import to access the global routeObserver.
import 'home_screen.dart';
import '../services/file_storage.dart';
import '../services/bluetooth_manager.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'recent_readings_screen.dart';

// Make sure that you import or define your global route observer.
// For example, if defined in main.dart:
// import '../main.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> with RouteAware {
  String imageLink = "assets/images/daily_readings.png";
  
  // State variable to keep track of the active button.
  int _activeButtonIndex = 0;

  // Aggregated level variables.
  double dailyMin = 0;
  double dailyAvg = 0;
  double dailyMax = 0;
  double weeklyMin = 0;
  double weeklyAvg = 0;
  double weeklyMax = 0;
  double monthlyMin = 0;
  double monthlyAvg = 0;
  double monthlyMax = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the route observer to refresh data when coming back.
    routeObserver.subscribe(this, ModalRoute.of(context)!);

    // Precache images so that image switches happen instantly.
    precacheImage(const AssetImage("assets/images/daily_readings.png"), context);
    precacheImage(const AssetImage("assets/images/weekly_readings.png"), context);
    precacheImage(const AssetImage("assets/images/monthly_readings.png"), context);
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
      dailyMin = _computeMin(dailyEntries);
      dailyAvg = _computeAvg(dailyEntries);
      dailyMax = _computeMax(dailyEntries);

      weeklyMin = _computeMin(weeklyEntries);
      weeklyAvg = _computeAvg(weeklyEntries);
      weeklyMax = _computeMax(weeklyEntries);

      monthlyMin = _computeMin(monthlyEntries);
      monthlyAvg = _computeAvg(monthlyEntries);
      monthlyMax = _computeMax(monthlyEntries);
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

  void updateImage(String newPath) {
    setState(() {
      imageLink = newPath;
    });
  }

  PreferredSizeWidget _buildAppBar() {
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
          child: Icon(
            Icons.bluetooth,
            color: BluetoothManager().connectedDevice != null ? Colors.lightBlue : Colors.red,
            size: 30.0,
          ),
        ),
      ],
      centerTitle: false,
    );
  }

  // A widget that displays a label and an aggregate value.
  Widget _buildLevelBox(String label, double value) {
    Color boxColor = _getBoxColor(value);
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
            value.toStringAsFixed(1),
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
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(imageLink),
            ),
            // Buttons to switch the displayed image.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeButtonIndex == 0 ? Colors.teal : Colors.white,
                          foregroundColor: _activeButtonIndex == 0 ? Colors.white : Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 2.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 0;
                          });
                          updateImage("assets/images/daily_readings.png");
                        },
                        child: const Text("Today", style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeButtonIndex == 1 ? Colors.teal : Colors.white,
                          foregroundColor: _activeButtonIndex == 1 ? Colors.white : Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 2.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 1;
                          });
                          updateImage("assets/images/weekly_readings.png");
                        },
                        child: const Text("7 Days", style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeButtonIndex == 2 ? Colors.teal : Colors.white,
                          foregroundColor: _activeButtonIndex == 2 ? Colors.white : Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 2.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 2;
                          });
                          updateImage("assets/images/monthly_readings.png");
                        },
                        child: const Text("30 Days", style: TextStyle(fontSize: 18)),
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
                  const Text("Daily Levels (mg/dL)", style: TextStyle(color: Colors.black, fontSize: 20)),
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
                  const Text("Weekly Levels (mg/dL)", style: TextStyle(color: Colors.black, fontSize: 20)),
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
                  const Text("Monthly Levels (mg/dL)", style: TextStyle(color: Colors.black, fontSize: 20)),
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
            const SizedBox(height: 15),

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
                    MaterialPageRoute(builder: (context) => const RecentReadingsScreen()),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.list, 
                      size: 30,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      "View History",
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
    );
  }
}
