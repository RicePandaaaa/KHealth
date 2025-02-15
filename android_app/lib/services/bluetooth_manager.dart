import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_data_receiver.dart';

class BluetoothManager {
  // Singleton instance
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;
  BluetoothManager._internal();

  // Instance of FlutterBluePlus used for scanning and connection
  final FlutterBluePlus flutterBlue = FlutterBluePlus();

  // Currently connected Bluetooth device (if any)
  BluetoothDevice? connectedDevice;

  // Create a BLEDataReceiver. Replace the UUIDs with your ESP32's actual ones.
  final BLEDataReceiver bleDataReceiver = BLEDataReceiver(
    targetServiceUUID: '4fafc201-1fb5-459e-8fcc-c5c9c331914b', // Update with your service UUID
    targetCharacteristicUUID: 'beb5483e-36e1-4688-b7f5-ea07361b26a8', // Update with your characteristic UUID
  );

  // Connect to a device and subscribe to data notifications.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      print("Connected to ${device.platformName}");

      // Subscribe to BLE data notifications globally.
      await bleDataReceiver.subscribeToData(device);

      // Listen for disconnection events.
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          print("Disconnected from ${device.platformName}");
        }
      });
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  // Disconnect from the currently connected device.
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        print("Device disconnected");
        connectedDevice = null;
      } catch (e) {
        print("Error disconnecting: $e");
      }
    }
  }
} 