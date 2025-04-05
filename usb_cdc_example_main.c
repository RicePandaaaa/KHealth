#include <stdio.h>
#include <string.h>
#include <inttypes.h> // For PRIu32 etc.
#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

#include "usb/usb_host.h"
#include "usb/cdc_acm_host.h"

// --- Configuration ---
// !! IMPORTANT !! Verify VID/PID when NanoVNA is in DFU/Bootloader mode!
// Common STM32 DFU VID/PID are 0x0483 / 0xDF11
// Keep 0x0483 / 0x5740 if your device uses the same for DFU (less common)
#define NANOVNA_DFU_VID     (0x04B4) // Or the VID your device shows in DFU mode
#define NANOVNA_DFU_PID     (0x0008) // Or the PID your device shows in DFU mode
#define NANOVNA_INTERFACE   (0)      // DFU Interface number, usually 0

// Binary DFU Command (INDICATE)
#define DFU_CMD_INDICATE    (0x0d)
#define DFU_RESPONSE_OK     (0x32)

#define TX_BUFFER_SIZE      (64)   // Small is fine for single bytes
#define RX_BUFFER_SIZE      (64)   // Small is fine for single bytes
#define TX_TIMEOUT_MS       (500)  // Timeout for sending data

// --- Task and Logging ---
#define USB_HOST_TASK_PRIORITY   (5)
static const char *TAG = "NANOVNA_DFU_HOST";
static SemaphoreHandle_t device_disconnected_sem;
static volatile bool response_received = false; // Flag for simple response checking
static volatile bool expected_response_ok = false; // Flag if received response was correct

/**
 * @brief Data received callback (DFU Mode)
 */
static bool handle_rx(const uint8_t *data, size_t data_len, void *user_arg)
{
    ESP_LOGI(TAG, "DFU Data received (%d bytes):", data_len);
    ESP_LOG_BUFFER_HEXDUMP(TAG, data, data_len, ESP_LOG_INFO);

    if (data_len == 1 && data[0] == DFU_RESPONSE_OK) {
        ESP_LOGI(TAG, ">>> Correct DFU Response (0x%02X) received!", data[0]);
        expected_response_ok = true;
    } else {
        ESP_LOGW(TAG, ">>> Unexpected DFU Response received!");
        expected_response_ok = false;
    }
    response_received = true; // Signal that *some* response came

    return true; // We processed this chunk
}

// --- handle_event and usb_lib_task remain the same as the previous example ---
// --- (Make sure TAG is updated in logs if desired) ---

static void handle_event(const cdc_acm_host_dev_event_data_t *event, void *user_ctx)
{
    switch (event->type) {
    // ... (cases for ERROR, DISCONNECTED, etc. as before) ...
    case CDC_ACM_HOST_DEVICE_DISCONNECTED:
        ESP_LOGW(TAG, "NanoVNA (DFU Mode) Disconnected");
        // Close the handle passed in the event data
        esp_err_t close_err = cdc_acm_host_close(event->data.cdc_hdl);
        if (close_err != ESP_OK && close_err != ESP_ERR_INVALID_STATE) {
             // Avoid logging error if already closed or closing
             ESP_LOGE(TAG, "Error closing CDC handle: %s", esp_err_to_name(close_err));
        }
        xSemaphoreGive(device_disconnected_sem); // Signal the main loop
        break;
    // ... (other cases) ...
    default:
         ESP_LOGD(TAG, "Unsupported CDC event: %i", event->type);
        break;
    }
}

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


void app_main(void)
{
    device_disconnected_sem = xSemaphoreCreateBinary();
    assert(device_disconnected_sem != NULL);

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
        cdc_acm_dev_hdl_t cdc_dev = NULL;

        // Configuration for the device when opened
        const cdc_acm_host_device_config_t dev_config = {
            .connection_timeout_ms = 5000,
            .out_buffer_size = TX_BUFFER_SIZE,
            .in_buffer_size = RX_BUFFER_SIZE,
            .event_cb = handle_event,
            .data_cb = handle_rx, // Our DFU-specific handler
            .user_arg = NULL
        };

        ESP_LOGI(TAG, "Waiting for NanoVNA in DFU Mode (VID:0x%04X, PID:0x%04X)...", NANOVNA_DFU_VID, NANOVNA_DFU_PID);
        ESP_LOGW(TAG, "Ensure NanoVNA is connected AND in DFU/Bootloader mode!");

        // 4. Wait for and open the NanoVNA device *in DFU mode*
        esp_err_t err = cdc_acm_host_open(NANOVNA_DFU_VID, NANOVNA_DFU_PID, NANOVNA_INTERFACE, &dev_config, &cdc_dev);

        if (err != ESP_OK) {
            // Don't log error here, just retry silently. Remove W log if too noisy.
            // ESP_LOGW(TAG, "Failed to open DFU device: %s. Retrying...", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }

        // --- Device is Connected and Open ---
        ESP_LOGI(TAG, "NanoVNA DFU connected, device handle: %p", cdc_dev);
        // cdc_acm_host_desc_print(cdc_dev); // Optional: Print descriptors

        // Might not need DTR/RTS for DFU, but doesn't usually hurt
        ESP_LOGI(TAG, "Setting DTR and RTS control lines");
        err = cdc_acm_host_set_control_line_state(cdc_dev, true, true);
        if (err != ESP_OK) {
             ESP_LOGW(TAG,"Failed to set DTR/RTS: %s", esp_err_to_name(err));
             // Continue anyway for DFU
        }

        // --- Communication Loop (while connected) ---
        while (true) {
            // Prepare the command byte
            const uint8_t command_byte = DFU_CMD_INDICATE;
            ESP_LOGI(TAG, "Sending DFU INDICATE command: 0x%02X", command_byte);

            // Reset response flags before sending
            response_received = false;
            expected_response_ok = false;

            // 5. Send the single command byte
            err = cdc_acm_host_data_tx_blocking(cdc_dev, &command_byte, 1, TX_TIMEOUT_MS);

            if (err != ESP_OK) {
                ESP_LOGE(TAG, "Failed to send DFU command: %s", esp_err_to_name(err));
                // Assume disconnection on TX error, break inner loop
                break;
            }

            // Wait briefly for the asynchronous response to arrive via handle_rx
            ESP_LOGI(TAG, "Command sent. Waiting briefly for response...");
            // This simple polling isn't ideal, a semaphore signaled from handle_rx would be better
            for (int i = 0; i < 50; ++i) { // Poll for up to 500ms (50 * 10ms)
                 if (response_received) break;
                 vTaskDelay(pdMS_TO_TICKS(10));
            }

            // Check result
            if (response_received) {
                if (expected_response_ok) {
                    ESP_LOGI(TAG, "DFU INDICATE successful!");
                } else {
                    ESP_LOGW(TAG, "DFU INDICATE failed: Incorrect response.");
                }
            } else {
                 ESP_LOGW(TAG, "DFU INDICATE failed: No response received within timeout.");
            }


            // Wait before sending the next command
            ESP_LOGI(TAG, "Waiting 5 seconds before next command...");
            vTaskDelay(pdMS_TO_TICKS(5000));

            // Check if the device disconnected during the delay
            if (xSemaphoreTake(device_disconnected_sem, 0) == pdTRUE) {
                 ESP_LOGI(TAG,"Device disconnected while waiting, breaking communication loop.");
                 break;
            }
        } // --- End of communication loop ---

        ESP_LOGI(TAG, "Device communication loop ended. Waiting for potential reconnect.");
        xSemaphoreTake(device_disconnected_sem, portMAX_DELAY); // Wait until disconnect fully handled
        ESP_LOGI(TAG, "Proceeding to wait for new connection.");

    } // --- End of main application loop (while(true)) ---
}
