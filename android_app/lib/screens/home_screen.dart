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
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            textStyle: const TextStyle(fontSize: 24),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ButtonScreen()),
            );
          },
          child: const Text('Go to Scan Screen'),
        ),
      ),
    );
  }
}
