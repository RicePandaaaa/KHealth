/**
 * ESP32 Firmware to read NanoVNA V2 data via USB Host (CDC-ACM)
 * using chunked FIFO reads, processing points on-the-fly to find
 * the resonant frequency (S11), and sending the result via BLE.
 *
 */

#include <stdio.h>
#include <string.h>
#include <inttypes.h> // For PRIu32 etc.
#include <math.h>     // For sqrt, log10, atan2, INFINITY, M_PI, isfinite
#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"
#include "nvs_flash.h"
#include "esp_timer.h" // For timing measurements if needed

// --- FreeRTOS ---
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

// --- USB Host ---
#include "usb/usb_host.h"
#include "usb/cdc_acm_host.h"

// --- NimBLE ---
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_att.h"          // For ble_att_svr_write_local() - Maybe not needed if only notifying
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"


// --- Configuration ---
#define APP_MAIN_TASK_PRIORITY    (tskIDLE_PRIORITY + 3)
#define NANOVNA_TASK_PRIORITY     (APP_MAIN_TASK_PRIORITY + 1) // Task doing USB reads
#define USB_HOST_TASK_PRIORITY    (NANOVNA_TASK_PRIORITY + 1) // USB library background task
#define NIMBLE_HOST_TASK_PRIORITY (USB_HOST_TASK_PRIORITY) // NimBLE background task priority

// TODO: Confirm VID/PID for the mode where 0x18 command works!
#define NANOVNA_VID           (0x04B4) // <<< YOUR OBSERVED VID
#define NANOVNA_PID           (0x0008) // <<< YOUR OBSERVED PID
#define NANOVNA_INTERFACE     (0)

// --- Sweep Configuration (VALUES TO BE WRITTEN TO NANOVNA) ---
#define CONFIGURED_SWEEP_START_HZ     (2200000000ULL) // 2.2 GHz (Use ULL suffix for uint64_t)
#define CONFIGURED_SWEEP_STEP_HZ      (195312ULL)     // 1.955 MHz step (Use ULL suffix for uint64_t)
#define CONFIGURED_SWEEP_POINTS       (1024)          // Number of points
#define CONFIGURED_VALUES_PER_FREQ    (10)            // Values per frequency

// --- Sweep Configuration (MATCHES VALUES WRITTEN ABOVE) ---
// Use the configured values below for ESP32 internal calculations
#define TOTAL_SWEEP_POINTS    (CONFIGURED_SWEEP_POINTS) // Use the configured value (1024)
#define SWEEP_START_HZ        ((double)CONFIGURED_SWEEP_START_HZ) // Use for calculations if needed
#define SWEEP_STEP_HZ         ((double)CONFIGURED_SWEEP_STEP_HZ)  // Use for calculations
// SWEEP_STOP_HZ is calculated if needed: Start + (Points - 1) * Step

// --- FIFO Read Configuration ---
#define DFU_CMD_READFIFO      (0x18)
#define FIFO_ADDR_VALUES      (0x30)
#define VALUE_SIZE            (32)      // Size of each point's data block from FIFO

#define CHUNK_NUM_VALUES      (128)     // Points to read per USB transaction (KEEP THIS OR ADJUST AS NEEDED)
// *** UPDATED NUM_CHUNKS based on 1024 points / 128 points/chunk ***
#define NUM_CHUNKS            (TOTAL_SWEEP_POINTS / CHUNK_NUM_VALUES) // Should be 8 for 1024/128

// Check for divisibility
#if (TOTAL_SWEEP_POINTS % CHUNK_NUM_VALUES != 0)
#error "TOTAL_SWEEP_POINTS must be divisible by CHUNK_NUM_VALUES"
#endif

#define CHUNK_EXPECTED_BYTES  (CHUNK_NUM_VALUES * VALUE_SIZE) // Bytes expected PER CHUNK

#define TX_BUFFER_SIZE        (64)      // Buffer for sending commands (in cdc_acm_host_device_config_t)
// Adjust RX buffer size for ONE chunk + overhead
#define RX_BUFFER_SIZE        (CHUNK_EXPECTED_BYTES + 256)
#define TX_CMD_BUFFER_SIZE    (10)      // Local buffer for constructing commands
#define TX_TIMEOUT_MS         (1000)    // Timeout for sending command
#define RX_CHUNK_TIMEOUT_MS   (10000)   // Timeout for receiving ONE chunk (e.g., 10 seconds)


// --- BLE Configuration ---
#define BLE_DEVICE_NAME "ESP32_NanoVNA_Stream" // Updated name
// Replace these with your own if you want
static const ble_uuid128_t SERVICE_UUID = BLE_UUID128_INIT(
    0x4f, 0xaf, 0xc2, 0x01, 0x1f, 0xb5, 0x45, 0x9e,
    0x8f, 0xcc, 0xc5, 0xc9, 0xc3, 0x31, 0x91, 0x4b // Same UUIDs okay
);
static const ble_uuid128_t CHARACTERISTIC_UUID = BLE_UUID128_INIT(
    0xbe, 0xb5, 0x48, 0x3e, 0x36, 0xe1, 0x46, 0x88,
    0xb7, 0xf5, 0xea, 0x07, 0x36, 0x1b, 0x26, 0xa8 // Same UUIDs okay
);
#define BLE_TRIGGER_STRING "DATA REQUESTED"
#define BLE_NOTIFY_BUF_SIZE 100 // Max size for notification string

// --- Logging ---
static const char *TAG_MAIN = "APP_MAIN";
static const char *TAG_NANO = "NANOVNA_TASK";
static const char *TAG_BLE = "NIMBLE_GATTS";
static const char *TAG_USB = "USB_HOST_LIB"; // For usb_lib_task

// --- Shared Resources ---
// USB/NanoVNA related
static SemaphoreHandle_t device_disconnected_sem; // Signals device disconnection
static SemaphoreHandle_t fifo_data_ready_sem;   // Signals complete FIFO CHUNK received
// Buffer for ONE CHUNK of raw data
static uint8_t chunk_rx_buffer[CHUNK_EXPECTED_BYTES];
static volatile size_t current_chunk_rx_count = 0;     // Bytes received for current chunk
static volatile cdc_acm_dev_hdl_t current_cdc_dev = NULL; // Store current device handle (use carefully)

// BLE related
static uint16_t gatt_chr_handle;                    // Characteristic handle for notifications
static volatile uint16_t current_conn_handle = BLE_HS_CONN_HANDLE_NONE; // Store current connection handle
static char ble_notify_buffer[BLE_NOTIFY_BUF_SIZE]; // Buffer for formatting BLE notification string

// Synchronization between BLE and NanoVNA Task
static SemaphoreHandle_t trigger_nanovna_read_sem; // Signaled by BLE write to trigger USB read

// --- Stream Processing State ---
// Variables to store the minimum S11 found *during* the sweep
static volatile double current_min_s11_db = INFINITY;
static volatile double freq_at_min_s11_hz = 0.0;
static volatile int points_processed_count = 0; // To track how many points were processed

// --- Forward Declarations ---
static void nimble_host_task(void *param);
static void usb_lib_task(void *param);
static void nanovna_control_task(void *param);
static int gatt_chr_access_cb(uint16_t conn_handle_, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static int gap_event_handler(struct ble_gap_event *event, void *arg);
static void ble_app_on_sync(void);
static void ble_app_on_reset(int reason);
static bool process_chunk_and_update_min(int chunk_index); // NEW: Processes chunk and updates running minimum


// =========================================================================
// == USB Host Callbacks and Processing Logic                           ==
// =========================================================================

/**
 * @brief USB Data received callback - Accumulates CHUNK data
 */
static bool handle_usb_rx(const uint8_t *data, size_t data_len, void *user_arg)
{
    // Check if we are expecting data for the current chunk
    if (current_chunk_rx_count < CHUNK_EXPECTED_BYTES) {
        size_t bytes_to_copy = data_len;
        if (current_chunk_rx_count + bytes_to_copy > CHUNK_EXPECTED_BYTES) {
            ESP_LOGW(TAG_NANO, "Chunk RX Overflow: Received %d, have %d, expected %d. Truncating.",
                     (int)data_len, (int)current_chunk_rx_count, (int)CHUNK_EXPECTED_BYTES);
            bytes_to_copy = CHUNK_EXPECTED_BYTES - current_chunk_rx_count;
        }

        if (bytes_to_copy > 0) {
            memcpy(chunk_rx_buffer + current_chunk_rx_count, data, bytes_to_copy);
            current_chunk_rx_count += bytes_to_copy;
        }

        // Check if we have received the complete CHUNK
        if (current_chunk_rx_count >= CHUNK_EXPECTED_BYTES) {
            // ESP_LOGD(TAG_NANO, "Complete chunk received (%d bytes).", CHUNK_EXPECTED_BYTES); // Use Debug level
            BaseType_t higher_task_woken = pdFALSE;
            xSemaphoreGiveFromISR(fifo_data_ready_sem, &higher_task_woken);
            // No need to yield from ISR if giving to a normal task
        }
    } else {
         ESP_LOGW(TAG_NANO, "Unexpected USB RX data (%d bytes) received after chunk completion.", (int)data_len);
         // ESP_LOG_BUFFER_HEXDUMP(TAG_NANO, data, data_len, ESP_LOG_WARN); // Can be noisy
    }
    return true; // Consume the data regardless
}


/**
 * @brief USB Device event callback
 */
static void handle_usb_event(const cdc_acm_host_dev_event_data_t *event, void *user_ctx)
{
    switch (event->type) {
    case CDC_ACM_HOST_DEVICE_DISCONNECTED:
        ESP_LOGW(TAG_NANO, "NanoVNA Disconnected (Event)");
        if (current_cdc_dev == event->data.cdc_hdl) { // Check if it's the device we were using
            current_cdc_dev = NULL; // Clear global handle
             // Reset rx count in case disconnect happened mid-read
             current_chunk_rx_count = 0;
            // Attempt to close handle (might already be closing)
            esp_err_t close_err = cdc_acm_host_close(event->data.cdc_hdl);
            if (close_err != ESP_OK && close_err != ESP_ERR_INVALID_STATE && close_err != ESP_ERR_NOT_FOUND) {
                ESP_LOGE(TAG_NANO, "Error closing CDC handle in disconnect event: %s", esp_err_to_name(close_err));
            }
            xSemaphoreGive(device_disconnected_sem); // Signal the main loop
        } else {
             ESP_LOGW(TAG_NANO,"Disconnect event for an unknown/different handle (%p)", event->data.cdc_hdl);
        }
        break;
    case CDC_ACM_HOST_ERROR:
         ESP_LOGE(TAG_NANO, "CDC-ACM error event occurred: %s (Handle: %p)", esp_err_to_name(event->data.error), event->data.cdc_hdl);
         // Treat error as potential disconnection? Difficult to recover reliably.
         if (current_cdc_dev == event->data.cdc_hdl) {
            current_cdc_dev = NULL;
            current_chunk_rx_count = 0;
             esp_err_t close_err = cdc_acm_host_close(event->data.cdc_hdl);
             if (close_err != ESP_OK && close_err != ESP_ERR_INVALID_STATE && close_err != ESP_ERR_NOT_FOUND) {
                 ESP_LOGE(TAG_NANO, "Error closing CDC handle on error event: %s", esp_err_to_name(close_err));
             }
            xSemaphoreGive(device_disconnected_sem);
         }
         break;
    default:
         // ESP_LOGD(TAG_NANO, "Unsupported CDC event: %i", event->type);
         break;
    }
}

/**
 * @brief Processes ONE chunk of received FIFO data point-by-point,
 * updating the global minimum S11 and corresponding frequency.
 * @param chunk_index The index of the current chunk (0 to NUM_CHUNKS - 1)
 * @return true if processing was successful, false on critical error (like bad index)
 */
static bool process_chunk_and_update_min(int chunk_index)
{
    ESP_LOGD(TAG_NANO, "Processing chunk %d for minimum S11...", chunk_index);
    bool success = true;

    for (int i = 0; i < CHUNK_NUM_VALUES; ++i) {
        size_t buffer_offset = i * VALUE_SIZE; // Offset within the chunk_rx_buffer

        int32_t fwd0Re, fwd0Im, rev0Re, rev0Im;
        uint16_t freqIndex; // Variable to hold the frequency index from VNA data

        // Basic bounds check for buffer read
        if (buffer_offset + VALUE_SIZE > CHUNK_EXPECTED_BYTES) {
            ESP_LOGE(TAG_NANO, "Internal Error: Buffer offset out of bounds during chunk processing!");
            success = false;
            break; // Stop processing this chunk
        }

        // Parse data using memcpy (assumes correct endianness - usually little-endian for STM32/ESP32)
        memcpy(&fwd0Re,   chunk_rx_buffer + buffer_offset + 0, 4);
        memcpy(&fwd0Im,   chunk_rx_buffer + buffer_offset + 4, 4);
        memcpy(&rev0Re,   chunk_rx_buffer + buffer_offset + 8, 4);
        memcpy(&rev0Im,   chunk_rx_buffer + buffer_offset + 12, 4);
        memcpy(&freqIndex, chunk_rx_buffer + buffer_offset + 24, 2); // Parse freqIndex

        // --- Use freqIndex to determine storage location and calculate frequency ---
        // Important: Assumes freqIndex corresponds to the overall sweep point (0 to TOTAL_SWEEP_POINTS-1)
        if (freqIndex >= TOTAL_SWEEP_POINTS) {
            ESP_LOGW(TAG_NANO, "Warning: freqIndex %u out of bounds (0-%d) in chunk %d, point %d. Skipping point.",
                     freqIndex, TOTAL_SWEEP_POINTS - 1, chunk_index, i);
            continue; // Skip this point if index is bad, but don't fail the whole chunk unless necessary
        }

        // --- Calculate Frequency from Index using CONFIGURED Step ---
        // Freq = Configured_Start + Index * Configured_Step
        double currentFreqHz = (double)CONFIGURED_SWEEP_START_HZ + (double)freqIndex * (double)CONFIGURED_SWEEP_STEP_HZ;

        // --- Calculate S11 ---
        double a = (double)rev0Re; double b = (double)rev0Im;
        double c = (double)fwd0Re; double d = (double)fwd0Im;
        double denom = c * c + d * d;
        double s11_re = 0.0, s11_im = 0.0;
        double current_s11_mag_db = INFINITY; // Default to infinity for this point

        if (denom > 1e-12) { // Check for non-zero denominator
            s11_re = (a * c + b * d) / denom;
            s11_im = (b * c - a * d) / denom;

            // --- Calculate Magnitude (dB) ---
            double mag_sq = s11_re * s11_re + s11_im * s11_im;
            if (mag_sq > 1e-18) { // Avoid log10(0) for valid points
                current_s11_mag_db = 10.0 * log10(mag_sq); // Use 10*log10(mag_sq) = 20*log10(mag)
            } else {
                current_s11_mag_db = -INFINITY; // Treat as perfect match or below noise floor
            }
        } else {
             // Denominator near zero -> S11 is effectively infinite magnitude
             current_s11_mag_db = INFINITY;
             // ESP_LOGW(TAG_NANO,"S11 calculation: Near-zero denominator at freqIndex %u", freqIndex);
        }

        ESP_LOGI(TAG_NANO, "current_s11_mag_db: %.9f dB at %.9f MHz (Point Index %u)",
                 current_s11_mag_db, currentFreqHz / 1e6, freqIndex);
        // --- Update Running Minimum ---
        // We only update if the current point's magnitude is finite and less than the minimum found so far
        if (isfinite(current_s11_mag_db) && current_s11_mag_db < current_min_s11_db) {
            current_min_s11_db = current_s11_mag_db;
            freq_at_min_s11_hz = currentFreqHz;
            // Optional: Log when the minimum is updated
             ESP_LOGD(TAG_NANO, "New min S11: %.4f dB at %.6f MHz (Point Index %u)",
                      current_min_s11_db, freq_at_min_s11_hz / 1e6, freqIndex);
        }

        // --- Phase calculation (optional, can be removed if not needed) ---
        // double current_s11_phase_deg = atan2(s11_im, s11_re) * 180.0 / M_PI;

        // Increment processed point counter (regardless of whether it was the minimum)
        points_processed_count++;

        // Optional detailed logging per point: Use Verbose level
         //ESP_LOGV(TAG_NANO, "Chunk %d, Idx %d (FqIdx %u, %.2f MHz): S11: %.4f dB",
         //         chunk_index, i, freqIndex, currentFreqHz / 1e6, current_s11_mag_db);

    } // End for loop over points in chunk
    return success; // Return true if loop completed (even if some points were skipped)
}

// =========================================================================
// == NimBLE GATT Server Logic                                            ==
// =========================================================================

/**
 * @brief GATT Characteristic Access Callback
 */
static int gatt_chr_access_cb(uint16_t conn_handle_,
                              uint16_t attr_handle,
                              struct ble_gatt_access_ctxt *ctxt,
                              void *arg)
{
    switch (ctxt->op) {
        case BLE_GATT_ACCESS_OP_WRITE_CHR: {
            ESP_LOGI(TAG_BLE, "GATT Write received (conn=0x%x, attr=0x%x)", conn_handle_, attr_handle);
            uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
            if (len > 0) {
                char buf[50]; // Buffer for received command string
                int rc = ble_hs_mbuf_to_flat(ctxt->om, buf, sizeof(buf) -1, NULL); // Read mbuf into flat buffer
                 if (rc == 0) {
                     buf[len] = '\0'; // Null terminate
                     ESP_LOGI(TAG_BLE, "Write data: \"%s\" (%d bytes)", buf, len);

                     // Check if the received command is "DATA REQUESTED"
                     if (strncmp(buf, BLE_TRIGGER_STRING, len) == 0 && len == strlen(BLE_TRIGGER_STRING)) {
                         ESP_LOGI(TAG_BLE, "Received trigger string! Signaling NanoVNA task.");
                         // Signal the NanoVNA task to perform a read
                         xSemaphoreGive(trigger_nanovna_read_sem);
                     } else {
                         ESP_LOGW(TAG_BLE, "Ignoring unknown write data.");
                     }
                 } else {
                     ESP_LOGE(TAG_BLE, "Failed to read mbuf flat (rc=%d)", rc);
                 }
            }
             return 0; // Success for write operation
        }

         case BLE_GATT_ACCESS_OP_READ_CHR: {
             ESP_LOGI(TAG_BLE, "GATT Read received (conn=0x%x, attr=0x%x)", conn_handle_, attr_handle);
             // Optionally return status or last result. For now, just return latest buffer.
             int rc = os_mbuf_append(ctxt->om, ble_notify_buffer, strlen(ble_notify_buffer));
             return (rc == 0) ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
         }

         default:
             ESP_LOGW(TAG_BLE,"Unhandled GATT Op: %d", ctxt->op);
             return BLE_ATT_ERR_UNLIKELY;
    }
}

/**
 * @brief Define the GATT service and characteristic
 */
static const struct ble_gatt_svc_def gatt_svr_svcs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &SERVICE_UUID.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &CHARACTERISTIC_UUID.u,
                .access_cb = gatt_chr_access_cb,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &gatt_chr_handle, // Store characteristic value handle
            },
            { 0 } // End of characteristics
        }
    },
    { 0 } // End of services
};

/**
 * @brief GAP Event Handler
 */
static int gap_event_handler(struct ble_gap_event *event, void *arg)
{
    struct ble_gap_conn_desc desc;
    int rc;

    switch (event->type) {
        case BLE_GAP_EVENT_CONNECT:
            ESP_LOGI(TAG_BLE, "BLE GAP Event: %s", event->connect.status == 0 ? "CONNECT" : "CONNECT_FAIL");
            if (event->connect.status == 0) {
                rc = ble_gap_conn_find(event->connect.conn_handle, &desc);
                if (rc == 0) {
                     ESP_LOGI(TAG_BLE, "Client connected; conn_handle=0x%x", event->connect.conn_handle);
                     // Store connection handle - ASSUMES ONLY ONE CLIENT for simplicity
                     current_conn_handle = event->connect.conn_handle;
                }
            } else {
                // Connection failed, restart advertising
                ble_app_on_sync(); // Call sync again to restart advertising
            }
            return 0;

        case BLE_GAP_EVENT_DISCONNECT:
            ESP_LOGI(TAG_BLE, "BLE GAP Event: DISCONNECT; reason=0x%x", event->disconnect.reason);
             // Check if it was the handle we were tracking
             if(event->disconnect.conn.conn_handle == current_conn_handle) {
                 current_conn_handle = BLE_HS_CONN_HANDLE_NONE; // Reset connection handle
             }
            // Restart advertising
            ble_app_on_sync();
            return 0;

         case BLE_GAP_EVENT_ADV_COMPLETE:
            ESP_LOGI(TAG_BLE, "BLE GAP Event: ADV_COMPLETE");
             // Can sometimes happen if advertising times out (though we use BLE_HS_FOREVER)
             // Restart advertising if needed
             ble_app_on_sync();
             return 0;

        // Handle MTU changes (good practice)
        case BLE_GAP_EVENT_MTU:
             ESP_LOGI(TAG_BLE, "BLE GAP MTU changed; conn=0x%x, tx_mtu=%d",
                      event->mtu.conn_handle, event->mtu.value);
             return 0;

         default:
             ESP_LOGD(TAG_BLE, "Unhandled GAP Event: %d", event->type);
             return 0;
    }
}

/**
 * @brief Called when the BLE stack is "ready" - Starts advertising
 */
static void ble_app_on_sync(void)
{
    int rc;
    // Use default address type (Public or Random Static)
    rc = ble_hs_util_ensure_addr(0);
    assert(rc == 0);

    // Start advertising
    struct ble_gap_adv_params adv_params;
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND; // Undirected Connectable
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN; // General Discoverable

    // Specify Public Address type (or determine dynamically if needed)
    rc = ble_gap_adv_start(BLE_OWN_ADDR_PUBLIC,      // Specify Public Address type
                           NULL,                     // No specific peer address
                           BLE_HS_FOREVER,           // Advertise indefinitely
                           &adv_params,
                           gap_event_handler,        // Callback for GAP events
                           NULL);
    if (rc != 0) {
        ESP_LOGE(TAG_BLE, "Error starting advertising; rc=%d", rc);
    } else {
        ESP_LOGI(TAG_BLE, "BLE Advertising started");
    }
}
/**
 * @brief Called on BLE stack reset
 */
static void ble_app_on_reset(int reason)
{
    ESP_LOGE(TAG_BLE, "Resetting BLE stack; reason=%d", reason);
}


// =========================================================================
// == Background Tasks                                                    ==
// =========================================================================

/**
 * @brief NimBLE host task runner
 */
static void nimble_host_task(void *param)
{
    ESP_LOGI(TAG_BLE, "NimBLE Host Task starting");
    nimble_port_run(); // This function will return only when nimble_port_stop() is called
    nimble_port_freertos_deinit();
     ESP_LOGW(TAG_BLE,"NimBLE Host Task ended"); // Should not happen in normal operation
    vTaskDelete(NULL);
}

/**
 * @brief USB Host library handling task
 */
static void usb_lib_task(void *param)
{
    ESP_LOGI(TAG_USB, "USB host library task started");
    while (1) {
        uint32_t event_flags;
        esp_err_t err = usb_host_lib_handle_events(portMAX_DELAY, &event_flags);
         if (err != ESP_OK && err != ESP_ERR_TIMEOUT) {
             ESP_LOGE(TAG_USB, "usb_host_lib_handle_events failed: %s", esp_err_to_name(err));
        }

        // Check if all clients are gone (e.g., device disconnected and closed)
        if (event_flags & USB_HOST_LIB_EVENT_FLAGS_NO_CLIENTS) {
            ESP_LOGI(TAG_USB, "No clients registered, freeing USB devices...");
           if (usb_host_device_free_all() != ESP_OK){
               ESP_LOGW(TAG_USB,"Failed to free all USB devices");
           };
        }
        // Check if all devices are free (often follows NO_CLIENTS)
        if (event_flags & USB_HOST_LIB_EVENT_FLAGS_ALL_FREE) {
            ESP_LOGI(TAG_USB, "All USB devices freed");
        }
    }
     ESP_LOGW(TAG_USB,"USB Host Library Task ended"); // Should not happen
    vTaskDelete(NULL);
}


/**
 * @brief Task managing NanoVNA connection and CHUNKED triggered reads
 * Processes points on-the-fly to find minimum S11.
 */
static void nanovna_control_task(void *param)
{
     ESP_LOGI(TAG_NANO,"NanoVNA Control Task Started");

     // --- Main application loop for USB Connection Lifecycle ---
     while (true) {
         // Reset global handle before attempting connection
         current_cdc_dev = NULL;

         // Configuration for the USB device when opened
         const cdc_acm_host_device_config_t dev_config = {
             .connection_timeout_ms = 5000,
             .out_buffer_size = TX_BUFFER_SIZE,
             .in_buffer_size = RX_BUFFER_SIZE, // Sized for ONE CHUNK
             .event_cb = handle_usb_event,
             .data_cb = handle_usb_rx,
             .user_arg = NULL
         };

         ESP_LOGI(TAG_NANO, "Waiting for NanoVNA (VID:0x%04X, PID:0x%04X) to connect...", NANOVNA_VID, NANOVNA_PID);
         // This call blocks until device connects or timeout
         esp_err_t err = cdc_acm_host_open(NANOVNA_VID, NANOVNA_PID, NANOVNA_INTERFACE, &dev_config, (cdc_acm_dev_hdl_t *)&current_cdc_dev); // Cast needed for volatile

         if (err != ESP_OK) {
             ESP_LOGD(TAG_NANO, "NanoVNA not found or failed to open (%s). Retrying...", esp_err_to_name(err));
             vTaskDelay(pdMS_TO_TICKS(2000));
             continue; // Retry connection
         }

         // --- Device is Connected ---
         ESP_LOGI(TAG_NANO, "NanoVNA connected, device handle: %p", current_cdc_dev);

         // Set DTR/RTS (important for some devices)
         ESP_LOGI(TAG_NANO, "Setting DTR and RTS control lines");
         err = cdc_acm_host_set_control_line_state(current_cdc_dev, true, true);
          if (err != ESP_OK) {
              ESP_LOGW(TAG_NANO,"Failed to set DTR/RTS: %s", esp_err_to_name(err));
         }
         vTaskDelay(pdMS_TO_TICKS(100)); // Short delay

         // ********************************************************************
         // ** START: ADDED CONFIGURATION COMMANDS                          **
         // ********************************************************************
         ESP_LOGI(TAG_NANO, "Sending configuration commands...");

         // Command sequences based on previous analysis
         // sweepStartHz = 2,200,000,000 -> WRITE8 @ Addr 00
         const uint8_t cmd_set_start_hz[] = {0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x83, 0x21, 0x56, 0x00};
         // sweepStepHz = 391,000 -> WRITE8 @ Addr 10
         const uint8_t cmd_set_step_hz[] = {0x23, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0xF7, 0x58};
         // sweepPoints = 1024 -> WRITE2 @ Addr 20
         const uint8_t cmd_set_points[] = {0x21, 0x20, 0x04, 0x00};
         // valuesPerFrequency = 10 -> WRITE2 @ Addr 22
         const uint8_t cmd_set_vals_per_freq[] = {0x21, 0x22, 0x00, 0x0A};

         bool config_ok = true;

         ESP_LOGI(TAG_NANO, "Setting Sweep Start Frequency...");
         err = cdc_acm_host_data_tx_blocking(current_cdc_dev, cmd_set_start_hz, sizeof(cmd_set_start_hz), TX_TIMEOUT_MS);
         if (err != ESP_OK) {
             ESP_LOGE(TAG_NANO, "Failed to send sweepStartHz config: %s", esp_err_to_name(err));
             config_ok = false;
         }
         vTaskDelay(pdMS_TO_TICKS(50)); // Small delay between commands

         if (config_ok) {
             ESP_LOGI(TAG_NANO, "Setting Sweep Step Frequency...");
             err = cdc_acm_host_data_tx_blocking(current_cdc_dev, cmd_set_step_hz, sizeof(cmd_set_step_hz), TX_TIMEOUT_MS);
             if (err != ESP_OK) {
                 ESP_LOGE(TAG_NANO, "Failed to send sweepStepHz config: %s", esp_err_to_name(err));
                 config_ok = false;
             }
         }
         vTaskDelay(pdMS_TO_TICKS(50)); // Small delay between commands

         if (config_ok) {
             ESP_LOGI(TAG_NANO, "Setting Sweep Points...");
             err = cdc_acm_host_data_tx_blocking(current_cdc_dev, cmd_set_points, sizeof(cmd_set_points), TX_TIMEOUT_MS);
             if (err != ESP_OK) {
                 ESP_LOGE(TAG_NANO, "Failed to send sweepPoints config: %s", esp_err_to_name(err));
                 config_ok = false;
             }
         }
         vTaskDelay(pdMS_TO_TICKS(50)); // Small delay between commands

         if (config_ok) {
             ESP_LOGI(TAG_NANO, "Setting Values Per Frequency...");
             err = cdc_acm_host_data_tx_blocking(current_cdc_dev, cmd_set_vals_per_freq, sizeof(cmd_set_vals_per_freq), TX_TIMEOUT_MS);
             if (err != ESP_OK) {
                 ESP_LOGE(TAG_NANO, "Failed to send valuesPerFrequency config: %s", esp_err_to_name(err));
                 config_ok = false;
             }
         }

         if (config_ok) {
             ESP_LOGI(TAG_NANO, "Configuration commands sent successfully.");
         } else {
             ESP_LOGE(TAG_NANO, "Configuration failed! Check connection and device state.");
             // Decide how to handle config failure - maybe disconnect and retry?
             // For now, we'll proceed, but the device might not be configured correctly.
         }
         // ********************************************************************
         // ** END: ADDED CONFIGURATION COMMANDS                            **
         // ********************************************************************


         // --- Inner loop: Wait for BLE trigger and perform CHUNKED read ---
         while (current_cdc_dev != NULL) {
             ESP_LOGI(TAG_NANO, "Waiting for BLE trigger to read %d points in %d chunks...", TOTAL_SWEEP_POINTS, NUM_CHUNKS);
             // Wait indefinitely for the trigger semaphore from BLE callback
             if (xSemaphoreTake(trigger_nanovna_read_sem, portMAX_DELAY) == pdTRUE) {
                 ESP_LOGI(TAG_NANO, "BLE trigger received! Starting chunked read and on-the-fly minimum S11 calculation...");

                 // --- RESET stream processing state for this sweep ---
                 current_min_s11_db = INFINITY;
                 freq_at_min_s11_hz = 0.0;
                 points_processed_count = 0;
                 // ----------------------------------------------------

                 bool read_error = false;
                 // Optional: Add overall timeout start time
                 // int64_t start_time = esp_timer_get_time();

                 // Clear the FIFO (opcode 0x20 = WRITE, 0x30 = FIFO_ADDR_VALUES, 0x00 = dummy)
                uint8_t clear_fifo_cmd[] = { 0x20, FIFO_ADDR_VALUES, 0x00 };
                esp_err_t err = cdc_acm_host_data_tx_blocking(
                    current_cdc_dev,
                    clear_fifo_cmd,
                    sizeof(clear_fifo_cmd),
                    TX_TIMEOUT_MS
                );
                if (err != ESP_OK) {
                    ESP_LOGE(TAG_NANO, "Failed to clear FIFO: %s", esp_err_to_name(err));
                    // handle error…
                }

                 for (int chunk = 0; chunk < NUM_CHUNKS; ++chunk) {
                     // Check if device disconnected during multi-chunk read
                     if (current_cdc_dev == NULL) {
                         ESP_LOGW(TAG_NANO,"Device disconnected during chunk read (%d/%d).", chunk + 1, NUM_CHUNKS);
                         read_error = true;
                         break; // Exit chunk loop
                     }

                     // Prepare the READFIFO command for the current chunk
                     // NOTE: NanoVNA expects number of POINTS for 0x18 command, not bytes.
                     uint8_t fifoCmd[3] = {DFU_CMD_READFIFO, FIFO_ADDR_VALUES, CHUNK_NUM_VALUES & 0xFF};
                     ESP_LOGI(TAG_NANO, "Requesting Chunk %d/%d (%d points)...", chunk + 1, NUM_CHUNKS, CHUNK_NUM_VALUES);

                     // Reset receive state for the chunk
                     current_chunk_rx_count = 0;
                     xSemaphoreTake(fifo_data_ready_sem, 0); // Clear stale signal before waiting

                     // Send the command
                     err = cdc_acm_host_data_tx_blocking(current_cdc_dev, fifoCmd, sizeof(fifoCmd), TX_TIMEOUT_MS);
                     if (err != ESP_OK) {
                         ESP_LOGE(TAG_NANO, "Failed to send READFIFO command for chunk %d: %s", chunk + 1, esp_err_to_name(err));
                         read_error = true;
                         break; // Exit chunk loop on TX error
                     }

                     // Wait for the complete chunk data
                     // ESP_LOGD(TAG_NANO, "Waiting for %d bytes for chunk %d...", CHUNK_EXPECTED_BYTES, chunk + 1);
                     BaseType_t got_semaphore = xSemaphoreTake(fifo_data_ready_sem, pdMS_TO_TICKS(RX_CHUNK_TIMEOUT_MS));

                     if (got_semaphore == pdTRUE && current_chunk_rx_count >= CHUNK_EXPECTED_BYTES) {
                         // Double check count, semaphore might be given slightly early in some scenarios?
                         if (current_chunk_rx_count < CHUNK_EXPECTED_BYTES) {
                             ESP_LOGW(TAG_NANO, "Semaphore received for chunk %d but rx count %d < expected %d.", chunk + 1, (int)current_chunk_rx_count, (int)CHUNK_EXPECTED_BYTES);
                             // Treat as incomplete data
                             read_error = true;
                             break;
                         }
                         ESP_LOGD(TAG_NANO, "Chunk %d data received (%d bytes). Processing and updating minimum...", chunk + 1, (int)current_chunk_rx_count);
                         // Process this chunk's points and update the running minimum S11/Frequency
                         if (!process_chunk_and_update_min(chunk)) {
                             ESP_LOGE(TAG_NANO, "Error processing data for chunk %d.", chunk + 1);
                             read_error = true;
                             break; // Exit chunk loop on processing error
                         }
                         // points_processed_count is incremented inside process_chunk_and_update_min
                     } else {
                         ESP_LOGE(TAG_NANO, "TIMEOUT or incomplete data for chunk %d. Got %d/%d bytes.",
                                  chunk + 1, (int)current_chunk_rx_count, (int)CHUNK_EXPECTED_BYTES);
                         read_error = true;
                         break; // Exit chunk loop on RX error/timeout
                     }
                     // Small delay between chunks? Maybe not needed if VNA/USB handles it.
                     // vTaskDelay(pdMS_TO_TICKS(20));

                 } // --- End of chunk loop ---

                 // --- After attempting all chunks ---
                 memset(ble_notify_buffer, 0, BLE_NOTIFY_BUF_SIZE); // Clear notification buffer

                 if (!read_error && points_processed_count >= TOTAL_SWEEP_POINTS) {
                     ESP_LOGI(TAG_NANO, "All %d chunks received and %d points processed successfully.", NUM_CHUNKS, (int)points_processed_count);
                     // Check if a valid minimum was found (i.e., not still INFINITY)
                     if (isfinite(current_min_s11_db)) {
                         ESP_LOGI(TAG_NANO, "Overall Resonant Point Found:");
                         ESP_LOGI(TAG_NANO, "  Frequency: %.6f MHz", freq_at_min_s11_hz / 1e6); // Increased precision
                         ESP_LOGI(TAG_NANO, "  Min S11 Mag: %.4f dB", current_min_s11_db);      // Increased precision

                         // Format notification string: "FreqGHz,MagdB" (adjust precision to fit)
                         snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "%.6f,%.4f", // Using more precision
                                  freq_at_min_s11_hz / 1e9, // Freq in GHz
                                  current_min_s11_db);      // Mag in dB
                     } else {
                         ESP_LOGW(TAG_NANO, "Sweep completed but no valid finite S11 minimum found.");
                         snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "Error: No finite min");
                     }
                 } else {
                      ESP_LOGE(TAG_NANO, "Failed to complete full sweep read. Error occurred or not all points processed (%d/%d).",
                              (int)points_processed_count, TOTAL_SWEEP_POINTS);
                      // Prepare error notification
                      snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "Error: Read failed (%d/%d pts)", (int)points_processed_count, TOTAL_SWEEP_POINTS);
                 }

                 // Send notification (success or error message) via BLE
                 if (current_conn_handle != BLE_HS_CONN_HANDLE_NONE) {
                     ESP_LOGI(TAG_NANO,"Sending BLE Notification: \"%s\"", ble_notify_buffer);
                     struct os_mbuf *om = ble_hs_mbuf_from_flat(ble_notify_buffer, strlen(ble_notify_buffer));
                     if (om) {
                         int rc = ble_gatts_notify_custom(current_conn_handle, gatt_chr_handle, om);
                         if (rc != 0) {
                             ESP_LOGE(TAG_NANO, "BLE notify failed; rc=%d", rc);
                         }
                     } else {
                         ESP_LOGE(TAG_NANO,"Failed to allocate mbuf for BLE notification");
                     }
                 } else {
                     ESP_LOGW(TAG_NANO,"No BLE client connected, cannot send notification.");
                 }

             } // End if(xSemaphoreTake trigger)
         } // --- End of inner communication loop ---

         ESP_LOGI(TAG_NANO, "NanoVNA disconnected or error occurred in inner loop. Waiting for USB disconnect event to be fully processed...");
         // Wait until the disconnect event is processed by handle_usb_event
         // This ensures state is clean (current_cdc_dev=NULL) before retry.
         xSemaphoreTake(device_disconnected_sem, portMAX_DELAY);
         ESP_LOGI(TAG_NANO, "Proceeding to wait for new USB connection.");

     } // --- End of outer USB connection loop ---

     ESP_LOGW(TAG_NANO,"NanoVNA Control Task ended"); // Should not happen
     vTaskDelete(NULL);
}


// =========================================================================
// == Main Application Setup                                              ==
// =========================================================================
void app_main(void)
{
    esp_err_t ret;

    // --- 1. Initialize NVS ---
    ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_LOGI(TAG_MAIN, "NVS Initialized.");

    // --- 2. Create Semaphores ---
    device_disconnected_sem = xSemaphoreCreateBinary();
    assert(device_disconnected_sem != NULL);
    fifo_data_ready_sem = xSemaphoreCreateBinary();
    assert(fifo_data_ready_sem != NULL);
    trigger_nanovna_read_sem = xSemaphoreCreateBinary();
    assert(trigger_nanovna_read_sem != NULL);
    ESP_LOGI(TAG_MAIN, "Semaphores Created.");

    // --- 3. Initialize USB Host ---
    ESP_LOGI(TAG_MAIN, "Initializing USB Host Library...");
    const usb_host_config_t host_config = { .intr_flags = ESP_INTR_FLAG_LEVEL1 };
    ESP_ERROR_CHECK(usb_host_install(&host_config));
    ESP_LOGI(TAG_MAIN, "Initializing CDC-ACM Host driver...");
    ESP_ERROR_CHECK(cdc_acm_host_install(NULL)); // Install CDC driver
    // Start USB library task
    BaseType_t task_created = xTaskCreate(usb_lib_task, "usb_lib", 4096, NULL, USB_HOST_TASK_PRIORITY, NULL);
    assert(task_created == pdTRUE);
    ESP_LOGI(TAG_MAIN, "USB Host Initialized and Task Started.");

    // --- 4. Initialize NimBLE ---
    ESP_LOGI(TAG_MAIN, "Initializing NimBLE Stack...");
    nimble_port_init();

    // Configure the BLE host stack
    ble_hs_cfg.sync_cb  = ble_app_on_sync;
    ble_hs_cfg.reset_cb = ble_app_on_reset;
    // Security configuration (optional, adjust as needed)
    ble_hs_cfg.sm_io_cap = BLE_HS_IO_NO_INPUT_OUTPUT; // Example: No bonding/pairing needed
    ble_hs_cfg.sm_bonding = 0;
    ble_hs_cfg.sm_mitm = 0;
    ble_hs_cfg.sm_sc = 0;

    // Initialize standard services: GAP and GATT
    ble_svc_gap_init();
    ble_svc_gatt_init();

    // Register our own GATT services
    ret = ble_gatts_count_cfg(gatt_svr_svcs);
    if (ret != 0) { ESP_LOGE(TAG_MAIN, "ble_gatts_count_cfg failed rc=%d", ret); }
    ret = ble_gatts_add_svcs(gatt_svr_svcs);
    if (ret != 0) { ESP_LOGE(TAG_MAIN, "ble_gatts_add_svcs failed rc=%d", ret); }

    // Set the device name
    ret = ble_svc_gap_device_name_set(BLE_DEVICE_NAME);
    if (ret != 0) { ESP_LOGE(TAG_MAIN, "Failed to set BLE device name rc=%d", ret); }

    // Start the NimBLE host task (needs to run before advertising starts in on_sync)
    nimble_port_freertos_init(nimble_host_task);
    ESP_LOGI(TAG_MAIN, "NimBLE Initialized and Task Started.");

    // --- 5. Start NanoVNA Control Task ---
    // Increased stack size for safety due to chunk processing logic/loops
    task_created = xTaskCreate(nanovna_control_task, "nanovna_task", 8192, NULL, NANOVNA_TASK_PRIORITY, NULL);
    assert(task_created == pdTRUE);
    ESP_LOGI(TAG_MAIN, "NanoVNA Control Task Started.");

    ESP_LOGI(TAG_MAIN, "Initialization Complete. System Running.");
    // app_main can exit now, background tasks will run.
}