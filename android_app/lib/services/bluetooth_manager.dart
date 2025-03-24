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

  // Create a BLEDataReceiver with the big-endian UUID strings as seen in nRF Connect.
  final BLEDataReceiver bleDataReceiver = BLEDataReceiver(
    targetServiceUUID: '4b9131c3-c9c5-cc8f-9e45-b51f01c2af4f', // Service UUID
    targetCharacteristicUUID: 'a8261b36-07ea-f5b7-8846-e1363e48b5be', // Characteristic UUID
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
    try {
      List<BluetoothService> services = await device.discoverServices();
      print("Discovered ${services.length} services");
      for (BluetoothService service in services) {
        print("Service: ${service.uuid}");
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("  Characteristic: ${characteristic.uuid}, properties: ${characteristic.properties}");
          if (characteristic.uuid.toString().toLowerCase() ==
              bleDataReceiver.targetCharacteristicUUID.toLowerCase()) {
            writeCharacteristic = characteristic;
            print("Found write characteristic: ${characteristic.uuid}");
            return;
          }
        }
      }
      print("Write characteristic not found.");
    } catch (e) {
      print("Error in _discoverWriteCharacteristic: $e");
    }
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
