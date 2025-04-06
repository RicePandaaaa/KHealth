#include <stdio.h>
#include <string.h>
#include <inttypes.h> // For PRIu32 etc.
#include <math.h>     // For sqrt, log10, atan2
#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

#include "usb/usb_host.h"
#include "usb/cdc_acm_host.h"

// --- Configuration ---
// TODO: Confirm VID/PID for the mode where 0x18 command works!
// If it's normal mode, use 0x0483 / 0x5740
// If it's DFU mode, use the VID/PID observed for that mode (e.g., 04B4:0008 or 0483:DF11)
#define NANOVNA_VID         (0x04B4) // <<< YOUR OBSERVED VID
#define NANOVNA_PID         (0x0008) // <<< YOUR OBSERVED PID
#define NANOVNA_INTERFACE   (0)

// --- FIFO Read Configuration ---
#define DFU_CMD_READFIFO    (0x18)
#define FIFO_ADDR_VALUES    (0x30)
#define NUM_VALUES          (200)    // How many 32-byte value blocks to read
#define VALUE_SIZE          (32)    // Size of each block from FIFO
#define EXPECTED_RX_BYTES   (NUM_VALUES * VALUE_SIZE) // Total bytes expected

#define TX_BUFFER_SIZE      (64)    // Buffer for sending commands (in cdc_acm_host_device_config_t)
#define RX_BUFFER_SIZE      (EXPECTED_RX_BYTES + 128) // MUST be >= EXPECTED_RX_BYTES + some overhead (in cdc_acm_host_device_config_t)
#define TX_CMD_BUFFER_SIZE  (10)    // Local buffer for constructing the command
#define TX_TIMEOUT_MS       (1000)  // Timeout for sending command
#define RX_TIMEOUT_MS       (5000)  // Timeout for waiting for *complete* FIFO data

// --- Task and Logging ---
#define USB_HOST_TASK_PRIORITY   (5)
static const char *TAG = "NANOVNA_FIFO_HOST";

// --- Shared Resources ---
static SemaphoreHandle_t device_disconnected_sem; // Signals device disconnection
static SemaphoreHandle_t fifo_data_ready_sem;   // Signals complete FIFO block received
static uint8_t fifo_rx_buffer[EXPECTED_RX_BYTES]; // Buffer to accumulate FIFO data
static volatile size_t current_rx_count = 0;      // Bytes received for current FIFO read
static cdc_acm_dev_hdl_t current_cdc_dev = NULL; // Store current device handle globally (use carefully)

// --- S11 Calculation Storage ---
double s11Magnitudes[NUM_VALUES];
double s11Phases[NUM_VALUES];


/**
 * @brief Data received callback - Accumulates FIFO data
 */
static bool handle_rx(const uint8_t *data, size_t data_len, void *user_arg)
{
    // ESP_LOGD(TAG, "RX Callback: Received %d bytes. Total so far: %d", data_len, current_rx_count + data_len);

    // Check if we are expecting FIFO data
    if (current_rx_count < EXPECTED_RX_BYTES) {
        size_t bytes_to_copy = data_len;
        // Prevent buffer overflow
        if (current_rx_count + bytes_to_copy > EXPECTED_RX_BYTES) {
            ESP_LOGW(TAG, "RX Overflow: Received %d, already have %d, expected %d total. Truncating.",
                     data_len, current_rx_count, EXPECTED_RX_BYTES);
            bytes_to_copy = EXPECTED_RX_BYTES - current_rx_count;
        }

        if (bytes_to_copy > 0) {
            memcpy(fifo_rx_buffer + current_rx_count, data, bytes_to_copy);
            current_rx_count += bytes_to_copy;
            // ESP_LOGD(TAG, "Copied %d bytes. Total now: %d", bytes_to_copy, current_rx_count);
        }

        // Check if we have received the complete block
        if (current_rx_count >= EXPECTED_RX_BYTES) {
            ESP_LOGI(TAG, ">>> Complete FIFO block (%d bytes) received!", EXPECTED_RX_BYTES);
            // Signal the main task
            BaseType_t higher_task_woken = pdFALSE;
            xSemaphoreGiveFromISR(fifo_data_ready_sem, &higher_task_woken);
             // Optional: Yield if a higher priority task was woken
            // if (higher_task_woken == pdTRUE) {
            //     portYIELD_FROM_ISR();
            // }
        }
    } else {
        // Received data when not expecting FIFO data or after completion
         ESP_LOGW(TAG, "Unexpected RX data (%d bytes) received.", data_len);
         ESP_LOG_BUFFER_HEXDUMP(TAG, data, data_len, ESP_LOG_WARN);
    }

    return true; // We processed this chunk (even if unexpected)
}

/**
 * @brief Device event callback
 */
static void handle_event(const cdc_acm_host_dev_event_data_t *event, void *user_ctx)
{
    switch (event->type) {
    case CDC_ACM_HOST_DEVICE_DISCONNECTED:
        ESP_LOGW(TAG, "NanoVNA Disconnected");
        current_cdc_dev = NULL; // Clear global handle
        esp_err_t close_err = cdc_acm_host_close(event->data.cdc_hdl);
         if (close_err != ESP_OK && close_err != ESP_ERR_INVALID_STATE) {
             ESP_LOGE(TAG, "Error closing CDC handle: %s", esp_err_to_name(close_err));
        }
        // Reset rx count in case disconnect happened mid-read
        current_rx_count = 0;
        xSemaphoreGive(device_disconnected_sem); // Signal the main loop
        break;
    case CDC_ACM_HOST_ERROR:
         ESP_LOGE(TAG, "CDC-ACM error occurred: %s", esp_err_to_name(event->data.error));
         // Consider signaling disconnect on error? Maybe give device_disconnected_sem?
         break;
    // ... other cases like SERIAL_STATE if needed ...
    default:
         ESP_LOGD(TAG, "Unsupported CDC event: %i", event->type);
        break;
    }
}

/**
 * @brief USB Host library handling task (No changes needed from previous)
 */
static void usb_lib_task(void *arg)
{
    ESP_LOGI(TAG, "USB host library task started");
    while (1) {
        uint32_t event_flags;
        esp_err_t err = usb_host_lib_handle_events(portMAX_DELAY, &event_flags);
         if (err != ESP_OK && err != ESP_ERR_TIMEOUT) {
            ESP_LOGE(TAG, "usb_host_lib_handle_events failed: %s", esp_err_to_name(err));
        }

        if (event_flags & USB_HOST_LIB_EVENT_FLAGS_NO_CLIENTS) {
            ESP_LOGI(TAG, "No clients registered, freeing devices...");
            if (usb_host_device_free_all() != ESP_OK){
                ESP_LOGW(TAG,"Failed to free all devices");
           };
        }
        if (event_flags & USB_HOST_LIB_EVENT_FLAGS_ALL_FREE) {
            ESP_LOGI(TAG, "All devices freed");
        }
    }
    vTaskDelete(NULL);
}


/**
 * @brief Processes the received FIFO data and calculates S11 parameters
 */
static void process_fifo_data(void)
{
    ESP_LOGI(TAG, "Processing %d bytes of FIFO data...", EXPECTED_RX_BYTES);

    for (int i = 0; i < NUM_VALUES; ++i) {
        size_t offset = i * VALUE_SIZE;
        if (offset + VALUE_SIZE > EXPECTED_RX_BYTES) {
            ESP_LOGE(TAG, "Processing error: Offset %d out of bounds!", offset);
            break;
        }

        int32_t fwd0Re, fwd0Im, rev0Re, rev0Im;
        // uint16_t freqIndex; // Uncomment if you need the frequency index

        // Parse forward (reference) channel (Bytes 0-7)
        memcpy(&fwd0Re, fifo_rx_buffer + offset + 0, 4);
        memcpy(&fwd0Im, fifo_rx_buffer + offset + 4, 4);
        // Parse reflected channel (Bytes 8-15)
        memcpy(&rev0Re, fifo_rx_buffer + offset + 8, 4);
        memcpy(&rev0Im, fifo_rx_buffer + offset + 12, 4);
        // Parse frequency index (Bytes 24-25) - Uncomment if needed
        // memcpy(&freqIndex, fifo_rx_buffer + offset + 24, 2);

        // Convert forward and reflected values to doubles
        double a = (double)rev0Re;
        double b = (double)rev0Im;
        double c = (double)fwd0Re;
        double d = (double)fwd0Im;

        // Complex division: S11 = (a+ib) / (c+id) = (ac+bd)/(c²+d²) + i(bc-ad)/(c²+d²)
        double denom = c * c + d * d;
        double s11_re, s11_im;
        if (denom != 0) {
            s11_re = (a * c + b * d) / denom;
            s11_im = (b * c - a * d) / denom;
        } else {
            // Avoid division by zero - handle as appropriate (e.g., invalid data)
            s11_re = 0.0;
            s11_im = 0.0;
            ESP_LOGW(TAG,"S11 calculation: Division by zero at index %d", i);
        }

        // Compute magnitude in dB: 20 * log10(|S11|) = 10 * log10(re²+im²)
        double mag_sq = s11_re * s11_re + s11_im * s11_im;
        if (mag_sq > 1e-18) { // Avoid log10(0) or very small numbers
             s11Magnitudes[i] = 10.0 * log10(mag_sq); // Use 10*log10(mag_sq) = 20*log10(mag)
        } else {
             s11Magnitudes[i] = -INFINITY; // Or a very large negative number like -200.0
        }

        // Compute phase in degrees
        s11Phases[i] = atan2(s11_im, s11_re) * 180.0 / M_PI;

        // Optional: Log the calculated values for this point
        // ESP_LOGD(TAG, "Index %d: S11 Mag: %.2f dB, Phase: %.2f deg", i, s11Magnitudes[i], s11Phases[i]);
    }

    // Optionally, find the resonant block (minimum S11 magnitude)
    double minS11 = INFINITY; // Use INFINITY from math.h
    int minIndex = -1;
    for (int i = 0; i < NUM_VALUES; i++) {
        if (s11Magnitudes[i] < minS11) {
            minS11 = s11Magnitudes[i];
            minIndex = i;
        }
    }

    if (minIndex >= 0) {
        ESP_LOGI(TAG, "------------------------------------------");
        ESP_LOGI(TAG, "Resonant block index: %d", minIndex);
        ESP_LOGI(TAG, "Min S11 Magnitude: %.3f dB", s11Magnitudes[minIndex]);
        ESP_LOGI(TAG, "Phase at Resonance: %.3f deg", s11Phases[minIndex]);
        ESP_LOGI(TAG, "------------------------------------------");
    } else {
        ESP_LOGW(TAG, "No valid S11 minimum found.");
    }
}

/**
 * @brief Main Application Task
 */
void app_main(void)
{
    // Create semaphores
    device_disconnected_sem = xSemaphoreCreateBinary();
    assert(device_disconnected_sem != NULL);
    fifo_data_ready_sem = xSemaphoreCreateBinary();
    assert(fifo_data_ready_sem != NULL);

    // 1. Install USB Host driver
    ESP_LOGI(TAG, "Installing USB Host Library");
    const usb_host_config_t host_config = { .intr_flags = ESP_INTR_FLAG_LEVEL1 };
    ESP_ERROR_CHECK(usb_host_install(&host_config));

    // 2. Create the USB library event handling task
    BaseType_t task_created = xTaskCreate(usb_lib_task, "usb_lib", 4096, NULL, USB_HOST_TASK_PRIORITY, NULL);
    assert(task_created == pdTRUE);

    // 3. Install the CDC-ACM Host Class Driver
    ESP_LOGI(TAG, "Installing CDC-ACM Host driver");
    ESP_ERROR_CHECK(cdc_acm_host_install(NULL));

    // --- Main application loop ---
    while (true) {
        // Reset global handle
        current_cdc_dev = NULL;

        // Configuration for the device when opened
        const cdc_acm_host_device_config_t dev_config = {
            .connection_timeout_ms = 5000,
            .out_buffer_size = TX_BUFFER_SIZE, // Max size host driver can buffer for TX
            .in_buffer_size = RX_BUFFER_SIZE,  // Max size host driver will buffer for RX before calling handle_rx
            .event_cb = handle_event,
            .data_cb = handle_rx,
            .user_arg = NULL
        };

        ESP_LOGI(TAG, "Waiting for NanoVNA (VID:0x%04X, PID:0x%04X)...", NANOVNA_VID, NANOVNA_PID);
        ESP_LOGW(TAG, "Ensure NanoVNA is connected AND in the correct mode!");

        // 4. Wait for and open the NanoVNA device
        esp_err_t err = cdc_acm_host_open(NANOVNA_VID, NANOVNA_PID, NANOVNA_INTERFACE, &dev_config, &current_cdc_dev);

        if (err != ESP_OK) {
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }

        // --- Device is Connected and Open ---
        ESP_LOGI(TAG, "NanoVNA connected, device handle: %p", current_cdc_dev);

        // Set DTR/RTS (often needed to make device responsive)
        ESP_LOGI(TAG, "Setting DTR and RTS control lines");
        err = cdc_acm_host_set_control_line_state(current_cdc_dev, true, true);
         if (err != ESP_OK) {
             ESP_LOGW(TAG,"Failed to set DTR/RTS: %s", esp_err_to_name(err));
        }
        vTaskDelay(pdMS_TO_TICKS(100)); // Short delay after setting control lines

        // --- Communication Loop (while connected) ---
        while (current_cdc_dev != NULL) { // Loop while device handle is valid
            // Prepare the READFIFO command
            uint8_t fifoCmd[3] = {DFU_CMD_READFIFO, FIFO_ADDR_VALUES, NUM_VALUES & 0xFF};
            ESP_LOGI(TAG, "Sending READFIFO command (0x%02X, 0x%02X, 0x%02X) for %d values",
                     fifoCmd[0], fifoCmd[1], fifoCmd[2], NUM_VALUES);

            // Reset receive state before sending command
            current_rx_count = 0;
            // Ensure semaphore is taken before waiting
            xSemaphoreTake(fifo_data_ready_sem, 0);

            // 5. Send the command
            err = cdc_acm_host_data_tx_blocking(current_cdc_dev, fifoCmd, sizeof(fifoCmd), TX_TIMEOUT_MS);

            if (err != ESP_OK) {
                ESP_LOGE(TAG, "Failed to send READFIFO command: %s", esp_err_to_name(err));
                // Assume disconnection on TX error, break inner loop
                // handle_event should trigger semaphore give for disconnect
                break;
            }

            // 6. Wait for the complete response data (signaled by handle_rx)
            ESP_LOGI(TAG, "Command sent. Waiting for %d bytes of FIFO data...", EXPECTED_RX_BYTES);
            TickType_t start_wait = xTaskGetTickCount();
            BaseType_t got_semaphore = xSemaphoreTake(fifo_data_ready_sem, pdMS_TO_TICKS(RX_TIMEOUT_MS));
            TickType_t end_wait = xTaskGetTickCount();

            if (got_semaphore == pdTRUE) {
                 ESP_LOGI(TAG, "FIFO data received successfully after %lu ms.", pdTICKS_TO_MS(end_wait - start_wait));
                 // 7. Process the received data
                 process_fifo_data();
            } else {
                 ESP_LOGE(TAG, "TIMEOUT: Failed to receive complete FIFO data within %d ms. Got %d bytes.", RX_TIMEOUT_MS, current_rx_count);
                 // Handle timeout - maybe break, maybe retry? Breaking for now.
                 break;
            }

            // Wait before sending the next command
            ESP_LOGI(TAG, "Waiting 1 second before next FIFO read...");
            vTaskDelay(pdMS_TO_TICKS(1000));

            // Check if device disconnected during processing or delay
             if (current_cdc_dev == NULL || xSemaphoreTake(device_disconnected_sem, 0) == pdTRUE) {
                 ESP_LOGI(TAG,"Device disconnected, breaking communication loop.");
                 if(current_cdc_dev != NULL){ // If disconnect wasn't handled by event yet
                     cdc_acm_host_close(current_cdc_dev);
                     current_cdc_dev = NULL;
                 }
                 break;
            }
        } // --- End of communication loop ---

        ESP_LOGI(TAG, "Device communication loop ended. Waiting for potential reconnect.");
        // Ensure disconnect semaphore is taken if we broke out manually
        xSemaphoreTake(device_disconnected_sem, portMAX_DELAY);
        ESP_LOGI(TAG, "Proceeding to wait for new connection.");

    } // --- End of main application loop (while(true)) ---
}
