import 'package:flutter/material.dart';
import 'home_screen.dart';

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36927D),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF36927D),
        title: InkWell(
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
        centerTitle: false,
      ),

      body: SingleChildScrollView( 
        child:Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 40
            ),

            Image.asset(
              "assets/images/data_screen_filler.png"
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
      ),
    );
  }
}
