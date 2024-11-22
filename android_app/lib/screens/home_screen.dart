import 'package:flutter/material.dart';
import 'button_screen.dart';

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
          height: 40,
        ),
        centerTitle: false,
      ),
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
                  // Add functionality for this button press
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
              height: 40
            )
          ],
        ),
      );
  }
}
