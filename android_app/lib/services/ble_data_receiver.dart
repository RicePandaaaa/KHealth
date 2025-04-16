import 'dart:ffi' as ffi; // Core FFI library
import 'dart:io' show Platform; // For checking OS Platform
import 'package:ffi/ffi.dart'; // For calloc (memory allocation)

import 'dart:convert'; // for utf8.decode
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'file_storage.dart'; // Assuming this file exists and provides necessary storage functions

// --- FFI Setup ---

// Define the C function signature using FFI types
// Corresponds to: double score(double* input)
typedef NativeScore = ffi.Double Function(ffi.Pointer<ffi.Double>);

// Define the Dart function signature using Dart types
typedef ScoreFunction = double Function(ffi.Pointer<ffi.Double>);

// Load the native library.
// IMPORTANT: Replace 'native_code' with the actual name you used
// in add_library(...) in your CMakeLists.txt if it's different.
final String libName = 'native_code';
final ffi.DynamicLibrary _nativeLib = Platform.isAndroid
    ? ffi.DynamicLibrary.open('lib$libName.so')
    // Add paths for other platforms if needed (iOS, Windows, Linux, macOS)
    // Example for iOS (might need framework handling depending on setup):
    // : Platform.isIOS ? ffi.DynamicLibrary.process()
    : throw UnsupportedError('Unsupported platform for FFI'); // Default error for other platforms

// Look up the C function 'score'
// IMPORTANT: The string 'score' must exactly match the function name in your C file.
final ScoreFunction score = _nativeLib
    .lookup<ffi.NativeFunction<NativeScore>>('score')
    .asFunction<ScoreFunction>();

// --- End FFI Setup ---


// --- Main Class Definition ---

class BLEDataReceiver {
  final String targetServiceUUID;
  final String targetCharacteristicUUID;

  BLEDataReceiver({
    required this.targetServiceUUID,
    required this.targetCharacteristicUUID,
  });

  /// Discovers device services, subscribes to notifications on the target characteristic,
  /// parses received data, calls a native C function, and potentially saves results.
  Future<void> subscribeToData(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      // Find the target service and characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == targetServiceUUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == targetCharacteristicUUID.toLowerCase() &&
                characteristic.properties.notify) {
              targetCharacteristic = characteristic;
              break; // Found the characteristic
            }
          }
        }
        if (targetCharacteristic != null) break; // Found the service and characteristic
      }

      // Check if characteristic was found
      if (targetCharacteristic == null) {
        print("Target service/characteristic with notify property not found.");
        return;
      }

      // Subscribe to notifications
      await targetCharacteristic.setNotifyValue(true);
      print("Subscription request sent to characteristic: ${targetCharacteristic.uuid}");

      // Listen to incoming data stream
      targetCharacteristic.lastValueStream.listen((data) async {
        // Pointer variable, declared outside try block for finally access
        ffi.Pointer<ffi.Double>? inputPointer;

        try {
          // Ensure data is not empty
          if (data.isEmpty) {
            print("Received empty data packet.");
            return;
          }

          // Convert the received List<int> to a string.
          String receivedData = utf8.decode(data);
          print("Received BLE data: $receivedData");

          // Parse the comma-separated values.
          List<String> values = receivedData.split(',');

          // Check if we have at least two values
          if (values.length >= 2) {
            // Extract the first two values. Use tryParse for safety.
            double? value1 = double.tryParse(values[0].trim());
            double? value2 = double.tryParse(values[1].trim());

            // Ensure parsing was successful for both values
            if (value1 != null && value2 != null) {

              // --- Prepare Input for C function ---
              // 1. Allocate memory on the native heap for an array of 2 doubles.
              //    `calloc` initializes the memory to zero bytes.
              inputPointer = calloc<ffi.Double>(2);

              // 2. Store the Dart double values into the allocated native memory.
              inputPointer[0] = value1; // First double
              inputPointer[1] = value2; // Second double

              print("Calling native 'score' function with inputs: ${inputPointer[0]}, ${inputPointer[1]}");

              // --- Call the C Function ---
              // Pass the pointer to the allocated memory to the native function.
              // 'score' is the Dart function reference we got from lookup earlier.
              final double scoreResult = score(inputPointer);

              print("Native function returned score: $scoreResult");

              await FileStorage.writeValue(scoreResult);

            } else {
              print("Failed to parse one or both double values from: $receivedData");
            }
          } else {
            print("Invalid data format: expected 2 comma-separated values, received: $receivedData");
          }
        } catch (e, stacktrace) {
          // Catch potential errors during processing or FFI call
          print("Error processing BLE data or calling native function: $e");
          print("Stacktrace: $stacktrace");
        } finally {
          // --- CRITICAL: Clean Up Native Memory ---
          // Always free the allocated memory to prevent memory leaks.
          // This happens even if errors occurred within the try block.
          if (inputPointer != null) {
            calloc.free(inputPointer);
             print("Freed native memory.");
          }
        }
      }); // End of listen callback

      print("Successfully subscribed to BLE data notifications from ${targetCharacteristic.uuid}.");

    } catch (e) {
      print("Error during service discovery or subscription: $e");
    }
  } // End of subscribeToData method

} // End of BLEDataReceiver class