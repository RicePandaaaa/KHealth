#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Replace these UUIDs with your own if needed.
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.print("Received Value: ");
      Serial.println(rxValue.c_str());
      // Process received data here as needed.

      String val = String(random(75,105));
      pCharacteristic->setValue(val);
      Serial.print("Value sent out: ");
      Serial.println(val);
      pCharacteristic->notify();
    }
  }
};

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    Serial.println("Client connected");
  }

  void onDisconnect(BLEServer* pServer) override {
    Serial.println("Client disconnected");
    // Restart advertising so that your Flutter app can reconnect
    BLEDevice::getAdvertising()->start();
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE Server...");

  // Initialize BLE and set the advertised device name
  BLEDevice::init("KHealth_Monitor");

  // Create a BLE Server and set callbacks
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create a BLE Service with the given UUID
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic with read, write, and notify properties
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  // Set an initial value for the characteristic
  pCharacteristic->setValue("Hello from ESP32");

  // Attach the write callback to handle incoming data
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  // Optionally add a descriptor (useful for notifications)
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising the service
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x06);  // Helps with iOS connections
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->start();

  Serial.println("BLE server is now advertising. Waiting for a connection...");
}

void loop() {
  // Delay between notifications
  delay(2000);  // Adjust the delay as needed
}
