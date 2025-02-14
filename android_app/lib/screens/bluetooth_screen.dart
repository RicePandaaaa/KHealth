import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import 'dart:async'; // Import for StreamSubscription
import '../services/bluetooth_manager.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  StreamSubscription<List<ScanResult>>? scanSubscription; // Subscription for scan results

  @override
  void initState() {
    super.initState();
    requestPermissions(); // Request permissions when the screen is opened
  }

  @override
  void dispose() {
    // Cancel scan subscription but do NOT disconnect the device; the connection should persist.
    scanSubscription?.cancel();
    super.dispose();
  }

  // Request Bluetooth permissions dynamically
  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse
    ].request();
  }

  // Start scanning for BLE devices
  void startScan() async {
    // Cancel any existing scan subscriptions to prevent multiple listeners
    await FlutterBluePlus.stopScan();
    scanSubscription?.cancel();

    scanResults.clear();
    if (mounted) {
      setState(() {}); // Clear the UI list
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));


    // Listen to scan results and update the UI
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
        });
      }
    }, onError: (error) {
      // Handle scan errors if necessary
      print("Scan error: $error");
    });
  }

  // Connect to a selected BLE device
  void connectToDevice(BluetoothDevice device) async {
    // Use the global BluetoothManager to connect
    await BluetoothManager().connectToDevice(device);
    if (mounted) {
      setState(() {
        // Update local UI state based on the global connection
        connectedDevice = BluetoothManager().connectedDevice;
      });
    }
  }

  // Disconnect from the device
  Future<void> disconnectDevice() async {
    // Use the global BluetoothManager to disconnect
    await BluetoothManager().disconnectDevice();
    if (mounted) {
      setState(() {
        connectedDevice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36927D), // Updated background color
      appBar: AppBar(
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
        centerTitle: false,
        elevation: 0, // Optional: Remove AppBar shadow
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: const Text("Scan for Devices"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.platformName.isNotEmpty ? device.platformName : "Unknown Device"),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(device),
                    child: const Text("Connect"),
                  ),
                );
              },
            ),
          ),
          if (connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Connected to: ${connectedDevice!.name}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: disconnectDevice,
                    child: const Text("Disconnect"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
