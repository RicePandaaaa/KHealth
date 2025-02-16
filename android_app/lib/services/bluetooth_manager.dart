import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_data_receiver.dart';
import 'dart:convert';

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

  // Writeable characteristic for sending data to the board.
  BluetoothCharacteristic? writeCharacteristic;

  // Connect to a device and subscribe to data notifications.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      print("Connected to ${device.platformName}");

      // Subscribe to BLE data notifications globally.
      await bleDataReceiver.subscribeToData(device);

      // Discover a writeable characteristic using the targetCharacteristicUUID.
      await _discoverWriteCharacteristic(device);

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

  // Private helper method to discover and store the writeable characteristic.
  Future<void> _discoverWriteCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() ==
            bleDataReceiver.targetCharacteristicUUID.toLowerCase()) {
          writeCharacteristic = characteristic;
          print("Found write characteristic: ${characteristic.uuid}");
          return;
        }
      }
    }
    print("Write characteristic not found.");
  }

  // Send data to the board. For example, this sends the string "DATA REQUESTED".
  Future<void> sendData(String message) async {
    if (writeCharacteristic == null) {
      print('Write characteristic not available.');
      return;
    }
    try {
      List<int> bytes = utf8.encode(message);
      await writeCharacteristic!.write(bytes, withoutResponse: false);
      print('Sent data: $message');
    } catch (e) {
      print("Error sending data: $e");
    }
  }
} 