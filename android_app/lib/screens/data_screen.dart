import 'package:flutter/material.dart';
import 'home_screen.dart';

String imageLink = "assets/images/daily_readings.png";

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
              imageLink
            ),

            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 30
            ),

            const Text(
              "Daily Levels (mg/dL)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Min: 65",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Avg: 90",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Max: 100",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 30
            ),

            const Text(
              "Weekly Levels (mg/dL)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

                        Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Min: 65",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Avg: 90",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Max: 100",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(
              color: Colors.white,
              thickness: 2,
              height: 30
            ),

            const Text(
              "Monthly Levels (mg/dL)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

                        Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Min: 65",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Avg: 90",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 125,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD8B7),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    alignment: Alignment.center,
                    child: const Text(
                      "Max: 100",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
