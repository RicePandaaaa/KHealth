import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'button_screen.dart';
import 'bluetooth_screen.dart';
import '../services/bluetooth_manager.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  String imageLink = "assets/images/daily_readings.png";
  
  // State variable to keep track of the active button.
  // The default active button is 0 (i.e. the first button).
  int _activeButtonIndex = 0;

  // Updatable state variables for the numeric values in each section
  double dailyMin = 65;
  double dailyAvg = 90;
  double dailyMax = 100;

  double weeklyMin = 65;
  double weeklyAvg = 90;
  double weeklyMax = 100;

  double monthlyMin = 65;
  double monthlyAvg = 90;
  double monthlyMax = 100;

  void updateImage(String newPath) {
    setState(() {
      imageLink = newPath; // Update the image path
    });
  }

  // Updated AppBar with Bluetooth status icon.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                imageLink,
              ),
            ),
            // Row with three buttons.
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 0;
                          });
                          updateImage("assets/images/daily_readings.png");
                        },
                        child: const Text(
                          "Today",
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 1;
                          });
                          updateImage("assets/images/weekly_readings.png");
                        },
                        child: const Text(
                          "7 Days",
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeButtonIndex = 2;
                          });
                          updateImage("assets/images/monthly_readings.png");
                        },
                        child: const Text(
                          "30 Days",
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Below the three buttons, replace the existing sections with the following:
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Section 1: Daily Levels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Text(
                      "Daily Levels (mg/dL)",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildLevelBox("Min", dailyMin)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildLevelBox("Avg", dailyAvg)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildLevelBox("Max", dailyMax)),
                    ],
                  ),
                  // Section 2: Weekly Levels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Text(
                      "Weekly Levels (mg/dL)",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildLevelBox("Min", weeklyMin)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildLevelBox("Avg", weeklyAvg)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildLevelBox("Max", weeklyMax)),
                    ],
                  ),
                  // Section 3: Monthly Levels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Text(
                      "Monthly Levels (mg/dL)",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
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

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: SizedBox(
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
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.house, 
                        size: 30,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        "Return to Home",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

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
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Returns the background color based on the value:
  // - Red: if value is below 70 or above 100
  // - Yellow: if value is at the lower end (>= 70 and < 75)
  //           or at the upper end (> 95 and <= 100)
  // - Green: if value is between 75 and 95
  Color _getBoxColor(double value) {
    if (value < 70 || value > 100) {
      return Colors.red.shade300;
    } else if ((value >= 70 && value < 75) || (value > 95 && value <= 100)) {
      return Colors.yellow.shade200;
    } else {
      return Colors.green.shade300;
    }
  }
}
