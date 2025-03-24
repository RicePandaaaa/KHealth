import 'dart:convert'; // for utf8.decode
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'file_storage.dart';

class BLEDataReceiver {
  // Replace these with your ESP32's service and characteristic UUIDs.
  final String targetServiceUUID;
  final String targetCharacteristicUUID;
  
  BLEDataReceiver({
    required this.targetServiceUUID,
    required this.targetCharacteristicUUID,
  });

  /// Discovers device services, subscribes to notifications on the target characteristic,
  /// and saves any received data to a local file.
  Future<void> subscribeToData(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() ==
          targetServiceUUID.toLowerCase()) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
                  targetCharacteristicUUID.toLowerCase() &&
              characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((data) async {
              // Convert the received List<int> to a string.
              String receivedData = utf8.decode(data);
              print("Received BLE data: $receivedData");

              // Filter out the default "0" value.
              if (receivedData.trim() == "0" ||
                  receivedData.trim() == "0.0") {
                print("Ignoring default 0 value");
                return;
              }

              // Parse the comma-separated values.
              List<String> values = receivedData.split(',');
              if (values.isNotEmpty) {
                // Extract the first value.
                double glucoseValue = double.tryParse(values[0].trim()) ?? 0.0;
                if (glucoseValue == 0.0) {
                  print("Ignoring parsed default 0 value");
                  return;
                }
                // Save the glucose value into a local file.
                await FileStorage.writeValue(glucoseValue);
              } else {
                print("Invalid data format received: $receivedData");
              }
            });
            print("Subscribed to BLE data notifications.");
            return; // Exit after subscribing to the correct characteristic.
          }
        }
      }
    }
    print("Target service/characteristic not found on the connected device.");
  }
}
