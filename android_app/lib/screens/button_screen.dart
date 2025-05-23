import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/bluetooth_manager.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'bluetooth_screen.dart';

class ButtonScreen extends StatefulWidget {
  const ButtonScreen({super.key});

  @override
  ButtonScreenState createState() => ButtonScreenState();
}

class ButtonScreenState extends State<ButtonScreen> {
  double _progress = 0.0;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache images that are used in your app to make image switching instant.
    precacheImage(const AssetImage("assets/images/daily_readings.png"), context);
    precacheImage(const AssetImage("assets/images/weekly_readings.png"), context);
    precacheImage(const AssetImage("assets/images/monthly_readings.png"), context);
  }

  void _startProgress() {
    setState(() {
      BluetoothManager().sendData("DATA REQUESTED");
      _isLoading = true;
      _progress = 0.0;
    });

    // For testing: Finish the progress almost instantly.
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _progress = 1.0;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20),
          SizedBox(
            width: 350,
            child: _isLoading
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: CircularProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 9, 158, 203)),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(100),
                    ),
                    onPressed: _startProgress,
                    child: const Text(
                      'Start Scan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const Divider(
            color: Colors.teal,
            thickness: 2,
            height: 40,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Device Status: ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: BluetoothManager().connectedDevice != null
                          ? Colors.lightBlue
                          : Colors.red,
                      width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  BluetoothManager().connectedDevice != null
                      ? 'ONLINE'
                      : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 24,
                    color: BluetoothManager().connectedDevice != null
                        ? Colors.lightBlue
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const Divider(
            color: Colors.teal,
            thickness: 2,
            height: 40,
          ),

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
        ],
      ),
    );
  }
}
