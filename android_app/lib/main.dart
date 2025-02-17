import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';
import 'screens/data_screen.dart';

// Define a global RouteObserver.
final RouteObserver<ModalRoute<dynamic>> routeObserver = RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K+ Health App Demo',
      theme: ThemeData(
        // Main background color for all scaffolds: a really light grey.
        scaffoldBackgroundColor: Colors.grey[350],
        // ElevatedButton theme: teal background with black text.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 20),
          ),
        ),
        // Default text theme: Black text wherever applicable.
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
        ),
        // AppBar theme with teal background.
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const LoadingScreen(), // Start with the loading screen
      navigatorObservers: [routeObserver], // Attach the RouteObserver here.
    );
  }
}
