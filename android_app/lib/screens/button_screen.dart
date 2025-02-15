import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'data_screen.dart';
import 'bluetooth_screen.dart';
import '../services/bluetooth_manager.dart';

class ButtonScreen extends StatefulWidget {
  const ButtonScreen({super.key});

  @override
  ButtonScreenState createState() => ButtonScreenState();
}

class ButtonScreenState extends State<ButtonScreen> {
  double _progress = 0.0;
  bool _isLoading = false;

  void _startProgress() {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _isLoading = false;
      });
    });

    for (int i = 1; i <= 5; i++) {
      Future.delayed(Duration(seconds: i), () {
        setState(() {
          _progress = i / 5;
        });
      });
    }
  }

  // Updated AppBar with Bluetooth icon.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF36927D),
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
            color: BluetoothManager().connectedDevice != null ?const Color.fromARGB(255, 105, 179, 240) : Colors.white,
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
      backgroundColor: const Color(0xFF36927D),
      appBar: _buildAppBar(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            color: Colors.white,
            thickness: 2,
            height: 40
          ),
          
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
                          valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 9, 158, 203)),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: const Color.fromARGB(255, 9, 158, 203),
                      padding: const EdgeInsets.all(100),
                    ),
                    onPressed: _startProgress,
                    child: const Text(
                      'Press to Start Scan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
          ),

          const Divider(
            color: Colors.white,
            thickness: 2,
            height: 40
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Device Status: ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                )
              ),

              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 73, 255, 1), 
                    width: 2
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DEVICE ONLINE',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromARGB(255, 73, 255, 1)
                  ),
                ),
              )
            ],
          ),

          const Divider(
            color: Colors.white,
            thickness: 2,
            height: 40
          ),

          SizedBox(
            width: 350,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3521CA),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Back to Home',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFFFFFFF),
                )
              ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: 350,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3521CA),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataScreen()),
                );
              },
              child: const Text(
                'Data History and Analytics',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFFFFFFF),
                )
              ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: 350,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3521CA),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BluetoothScreen()),
                );
              },
              child: const Text(
                'Bluetooth Settings',

                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFFFFFFF),
                )
              ),
            ),
          ),

          const Divider(
            color: Colors.white,
            thickness: 2,
            height: 30
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 20.0),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
