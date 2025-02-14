import asyncio
from bleak import BleakServer

SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"

class ESP32BLEEmulator(BleakServer):
    def __init__(self):
        super().__init__()
        self.add_service(SERVICE_UUID)
        self.add_characteristic(CHARACTERISTIC_UUID, ["read", "write"], self.read_data, self.write_data)

    async def read_data(self, _):
        print("Flutter requested data!")
        return b"Simulated ESP32 Data"

    async def write_data(self, _, value):
        print(f"Received from Flutter: {value.decode()}")

async def main():
    emulator = ESP32BLEEmulator()
    await emulator.start()
    print("ESP32 BLE Emulator is Running...")
    await asyncio.sleep(1000)  # Keep the server running

asyncio.run(main())
