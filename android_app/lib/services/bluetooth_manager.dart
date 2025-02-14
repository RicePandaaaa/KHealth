import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager {
  // Singleton instance
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;
  BluetoothManager._internal();

  // Instance of FlutterBluePlus that will be used for scanning and connection
  final FlutterBluePlus flutterBlue = FlutterBluePlus();

  // Currently connected Bluetooth device (if any)
  BluetoothDevice? connectedDevice;

  // Connect to a device and listen for disconnect events.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;

      // Listen for disconnection events
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
        }
      });
    } catch (e) {
      // TODO: Handle connection errors
    }
  }

  // Disconnect from the currently connected device.
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        connectedDevice = null;
      } catch (e) {
        // TODO: Handle disconnection errors
      }
    }
  }
} 