import 'package:flutter/material.dart';
import 'button_screen.dart';
import 'data_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36927D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF36927D),
        title: Image.asset(
          'assets/images/company_logo.png',
          height: 60,
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 2
            ),

            Image.asset(
              'assets/images/home_readings_filler.png'
            ),

            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 30
            ),
            
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
                    MaterialPageRoute(builder: (context) => const ButtonScreen()),
                  );
                },
                child: const Text(
                  'Start New Reading',
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
                  'View Data History and Analysis',
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
                  // Add functionality for this button press
                },
                child: const Text(
                  'Disconnect/Reconnect to Device',
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

            const Text(
              'Time since Last Reading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Text(
              'Readings Done Today',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 30
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 10.0),
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
      ),
    );
  }
}
