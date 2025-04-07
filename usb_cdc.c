#include <stdio.h>
#include <string.h>
#include <inttypes.h> // For PRIu32 etc.
#include <math.h>     // For sqrt, log10, atan2, INFINITY, M_PI
#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"
#include "nvs_flash.h"

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
#include "host/ble_att.h"         // For ble_att_svr_write_local() - Maybe not needed if only notifying
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"


// --- Configuration ---
#define APP_MAIN_TASK_PRIORITY  (tskIDLE_PRIORITY + 3)
#define NANOVNA_TASK_PRIORITY   (APP_MAIN_TASK_PRIORITY + 1) // Task doing USB reads
#define USB_HOST_TASK_PRIORITY  (NANOVNA_TASK_PRIORITY + 1) // USB library background task
#define NIMBLE_HOST_TASK_PRIORITY (USB_HOST_TASK_PRIORITY) // NimBLE background task priority

// TODO: Confirm VID/PID for the mode where 0x18 command works!
#define NANOVNA_VID         (0x04B4) // <<< YOUR OBSERVED VID
#define NANOVNA_PID         (0x0008) // <<< YOUR OBSERVED PID
#define NANOVNA_INTERFACE   (0)

// --- FIFO Read Configuration ---
#define DFU_CMD_READFIFO    (0x18)
#define FIFO_ADDR_VALUES    (0x30)
#define NUM_VALUES          (200)   // How many 32-byte value blocks to read (e.g., 101 points)
#define VALUE_SIZE          (32)    // Size of each block from FIFO
#define EXPECTED_RX_BYTES   (NUM_VALUES * VALUE_SIZE) // Total bytes expected

#define TX_BUFFER_SIZE      (64)    // Buffer for sending commands (in cdc_acm_host_device_config_t)
#define RX_BUFFER_SIZE      (EXPECTED_RX_BYTES + 256) // MUST be >= EXPECTED_RX_BYTES + overhead
#define TX_CMD_BUFFER_SIZE  (10)    // Local buffer for constructing the command
#define TX_TIMEOUT_MS       (1000)  // Timeout for sending command
#define RX_TIMEOUT_MS       (5000)  // Timeout for waiting for *complete* FIFO data

// --- Sweep Configuration (MUST MATCH NANOVNA SETUP) ---
#define SWEEP_START_HZ      (10000000.0)   // UPDATED: 10 MHz (10,000,000 Hz)
#define SWEEP_STOP_HZ       (3000000000.0) // UPDATED: 3 GHz (3,000,000,000 Hz)
#define SWEEP_NUM_POINTS    (201)   // Number of points MUST match FIFO read count (now 201)

// --- BLE Configuration ---
#define BLE_DEVICE_NAME "ESP32_NanoVNA_Reader"
// Replace these with your own if you want
static const ble_uuid128_t SERVICE_UUID = BLE_UUID128_INIT(
    0x4f, 0xaf, 0xc2, 0x01, 0x1f, 0xb5, 0x45, 0x9e,
    0x8f, 0xcc, 0xc5, 0xc9, 0xc3, 0x31, 0x91, 0x4b
);
static const ble_uuid128_t CHARACTERISTIC_UUID = BLE_UUID128_INIT(
    0xbe, 0xb5, 0x48, 0x3e, 0x36, 0xe1, 0x46, 0x88,
    0xb7, 0xf5, 0xea, 0x07, 0x36, 0x1b, 0x26, 0xa8
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
static SemaphoreHandle_t fifo_data_ready_sem;   // Signals complete FIFO block received
static uint8_t fifo_rx_buffer[EXPECTED_RX_BYTES]; // Buffer to accumulate FIFO data
static volatile size_t current_rx_count = 0;      // Bytes received for current FIFO read
static volatile cdc_acm_dev_hdl_t current_cdc_dev = NULL; // Store current device handle (use carefully)

// BLE related
static uint16_t gatt_chr_handle;            // Characteristic handle for notifications
static volatile uint16_t current_conn_handle = BLE_HS_CONN_HANDLE_NONE; // Store current connection handle
static char ble_notify_buffer[BLE_NOTIFY_BUF_SIZE]; // Buffer for formatting BLE notification string

// Synchronization between BLE and NanoVNA Task
static SemaphoreHandle_t trigger_nanovna_read_sem; // Signaled by BLE write to trigger USB read

// --- S11 Calculation Storage ---
// Made static to avoid large stack allocation in processing function
static double s11Magnitudes[NUM_VALUES];
static double s11Phases[NUM_VALUES];

// --- Forward Declarations ---
static void nimble_host_task(void *param);
static void usb_lib_task(void *param);
static void nanovna_control_task(void *param);
static int gatt_chr_access_cb(uint16_t conn_handle_, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static int gap_event_handler(struct ble_gap_event *event, void *arg);
static void ble_app_on_sync(void);
static void ble_app_on_reset(int reason);

// =========================================================================
// == USB Host Callbacks and Processing Logic                             ==
// =========================================================================

/**
 * @brief USB Data received callback - Accumulates FIFO data
 */
static bool handle_usb_rx(const uint8_t *data, size_t data_len, void *user_arg)
{
    // Check if we are expecting FIFO data
    if (current_rx_count < EXPECTED_RX_BYTES) {
        size_t bytes_to_copy = data_len;
        if (current_rx_count + bytes_to_copy > EXPECTED_RX_BYTES) {
            ESP_LOGW(TAG_NANO, "RX Overflow: Received %d, already have %d, expected %d total. Truncating.",
                     data_len, current_rx_count, EXPECTED_RX_BYTES);
            bytes_to_copy = EXPECTED_RX_BYTES - current_rx_count;
        }

        if (bytes_to_copy > 0) {
            memcpy(fifo_rx_buffer + current_rx_count, data, bytes_to_copy);
            current_rx_count += bytes_to_copy;
        }

        // Check if we have received the complete block
        if (current_rx_count >= EXPECTED_RX_BYTES) {
            ESP_LOGI(TAG_NANO, "Complete FIFO block (%d bytes) received from USB.", EXPECTED_RX_BYTES);
            BaseType_t higher_task_woken = pdFALSE;
            xSemaphoreGiveFromISR(fifo_data_ready_sem, &higher_task_woken);
            // No need to yield from ISR if giving to a normal task
        }
    } else {
         ESP_LOGW(TAG_NANO, "Unexpected USB RX data (%d bytes) received.", data_len);
         ESP_LOG_BUFFER_HEXDUMP(TAG_NANO, data, data_len, ESP_LOG_WARN);
    }
    return true;
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
             current_rx_count = 0;
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
         // Maybe signal disconnect here too?
         if (current_cdc_dev == event->data.cdc_hdl) {
            current_cdc_dev = NULL;
            current_rx_count = 0;
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
 * @brief Processes the received FIFO data and calculates S11 parameters
 * @return true if processing was successful (found min), false otherwise
 */
static bool process_fifo_data_and_prepare_notify(void)
{
    ESP_LOGI(TAG_NANO, "Processing %d bytes of FIFO data (%d points)...", EXPECTED_RX_BYTES, NUM_VALUES);
    bool success = false;
    double frequencies[NUM_VALUES]; // Array to store calculated frequencies for each point

    for (int i = 0; i < NUM_VALUES; ++i) {
        size_t offset = i * VALUE_SIZE;
        // Basic bounds check already assumes EXPECTED_RX_BYTES is correct
        // if (offset + VALUE_SIZE > EXPECTED_RX_BYTES) { ... } // This check is technically redundant if loop condition is correct

        int32_t fwd0Re, fwd0Im, rev0Re, rev0Im;
        uint16_t freqIndex; // Variable to hold the frequency index

        // Parse data using memcpy (assumes correct endianness - usually little-endian for STM32/ESP32)
        memcpy(&fwd0Re, fifo_rx_buffer + offset + 0, 4);
        memcpy(&fwd0Im, fifo_rx_buffer + offset + 4, 4);
        memcpy(&rev0Re, fifo_rx_buffer + offset + 8, 4);
        memcpy(&rev0Im, fifo_rx_buffer + offset + 12, 4);
        memcpy(&freqIndex, fifo_rx_buffer + offset + 24, 2); // <<< Parse freqIndex

        // --- Calculate Frequency from Index ---
        // Ensure index is within expected bounds (optional sanity check)
        if (freqIndex >= SWEEP_NUM_POINTS) {
             ESP_LOGW(TAG_NANO, "Warning: freqIndex %u out of bounds (0-%d) at loop index %d",
                      freqIndex, SWEEP_NUM_POINTS - 1, i);
             // Decide how to handle: use loop index 'i', clamp, or skip point? Using 'i' for now.
             freqIndex = i;
        }

        double currentFreqHz = 0;
        if (SWEEP_NUM_POINTS <= 1) {
             currentFreqHz = SWEEP_START_HZ; // Handle single point sweep
        } else {
             // Linear sweep calculation: Freq = Start + Index * (Stop - Start) / (TotalPoints - 1)
             currentFreqHz = SWEEP_START_HZ + (double)freqIndex * (SWEEP_STOP_HZ - SWEEP_START_HZ) / (double)(SWEEP_NUM_POINTS - 1);
        }
        frequencies[i] = currentFreqHz; // Store the calculated frequency

        // --- Calculate S11 ---
        double a = (double)rev0Re; double b = (double)rev0Im;
        double c = (double)fwd0Re; double d = (double)fwd0Im;
        double denom = c * c + d * d;
        double s11_re = 0.0, s11_im = 0.0;

        if (denom > 1e-12) { // Check for non-zero denominator (increased threshold slightly)
            s11_re = (a * c + b * d) / denom;
            s11_im = (b * c - a * d) / denom;
        } else {
             ESP_LOGW(TAG_NANO,"S11 calculation: Near-zero denominator at index %d (freqIndex %u)", i, freqIndex);
             // Maybe set S11 to 0 or a very high magnitude? Setting mag to +INF for now.
        }

        // --- Calculate Magnitude (dB) and Phase (degrees) ---
        double mag_sq = s11_re * s11_re + s11_im * s11_im;
        if (denom <= 1e-12) { // If denominator was zero, force magnitude high
            s11Magnitudes[i] = INFINITY;
        } else if (mag_sq > 1e-18) { // Avoid log10(0) for valid points
             s11Magnitudes[i] = 10.0 * log10(mag_sq); // Use 10*log10(mag_sq) = 20*log10(mag)
        } else {
             s11Magnitudes[i] = -INFINITY; // Treat as perfect match or below noise floor
        }
        s11Phases[i] = atan2(s11_im, s11_re) * 180.0 / M_PI;

        // Optional detailed logging per point:
        // ESP_LOGD(TAG_NANO, "Idx %d (FqIdx %u, %.2f MHz): S11: %.2f dB, %.2f deg",
        //          i, freqIndex, currentFreqHz / 1e6, s11Magnitudes[i], s11Phases[i]);

    } // End for loop

    // --- Find the resonant block (minimum S11 magnitude) ---
    double minS11 = INFINITY; // Initialize with positive infinity
    int minIndex = -1;
    for (int i = 0; i < NUM_VALUES; i++) {
        // Find the minimum *finite* S11 magnitude
        if (isfinite(s11Magnitudes[i]) && s11Magnitudes[i] < minS11) {
            minS11 = s11Magnitudes[i];
            minIndex = i;
        }
    }

    // --- Prepare notification string ---
    memset(ble_notify_buffer, 0, BLE_NOTIFY_BUF_SIZE);
    if (minIndex >= 0) {
        // We found a valid minimum S11 point
        double resonantFreqHz = frequencies[minIndex]; // Get the frequency at the minimum index

        // Log the result
        ESP_LOGI(TAG_NANO, "Resonant Point Found:");
        ESP_LOGI(TAG_NANO, "  Index: %d", minIndex);
        ESP_LOGI(TAG_NANO, "  Frequency: %.3f MHz", resonantFreqHz / 1e6);
        ESP_LOGI(TAG_NANO, "  Min S11 Mag: %.2f dB", s11Magnitudes[minIndex]);
        ESP_LOGI(TAG_NANO, "  Phase @ Min Mag: %.2f deg", s11Phases[minIndex]);

        // Format notification string: "FreqMHz: MagdB @ PhaseDeg"
        // Adjust precision (%.xf) as needed to fit BLE_NOTIFY_BUF_SIZE
        snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "%.1f,%.1f",
                 resonantFreqHz / 1e9,      // Freq in GHz with 1 decimal place
                 s11Magnitudes[minIndex]);  // Phase in degrees with 1 decimal place
        success = true;
    } else {
        // No valid minimum S11 point was found (e.g., all were infinite or NaN)
        ESP_LOGW(TAG_NANO, "No valid S11 minimum found across %d points.", NUM_VALUES);
        snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "Error: No resonance found");
        success = false;
    }
    return success;
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
             // Optionally return status or last result. For now, just return empty/success.
             // Could potentially read 'ble_notify_buffer' here if needed.
             // Example: Respond with "Ready" or the last result
             const char* resp = "Status: Ready";
             int rc = os_mbuf_append(ctxt->om, resp, strlen(resp));
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
    // This makes sure the controller has an address ready
    rc = ble_hs_util_ensure_addr(0);
    assert(rc == 0);

    // Start advertising
    struct ble_gap_adv_params adv_params;
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND; // Undirected Connectable
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN; // General Discoverable

    // *** FIX IS HERE ***
    // Replace ble_hs_cfg.addr_type with a constant like BLE_OWN_ADDR_PUBLIC
    rc = ble_gap_adv_start(BLE_OWN_ADDR_PUBLIC,      // Specify Public Address type
                           NULL,                     // No specific peer address
                           BLE_HS_FOREVER,           // Advertise indefinitely
                           &adv_params,
                           gap_event_handler,        // Callback for GAP events
                           NULL);
    if (rc != 0) {
        ESP_LOGE(TAG_BLE, "Error starting advertising; rc=%d", rc);
        // Consider adding a retry mechanism or delay here if startup fails repeatedly
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

        // Check if all clients are gone (e.g., device disconnected and closed by nanovna_task/event_handler)
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
 * @brief Task managing NanoVNA connection and triggered reads
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
             .in_buffer_size = RX_BUFFER_SIZE,
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

         // --- Inner loop: Wait for BLE trigger and perform read ---
         while (current_cdc_dev != NULL) {
             ESP_LOGI(TAG_NANO, "Waiting for BLE trigger to read FIFO...");
             // Wait indefinitely for the trigger semaphore from BLE callback
             if (xSemaphoreTake(trigger_nanovna_read_sem, portMAX_DELAY) == pdTRUE) {
                 ESP_LOGI(TAG_NANO, "BLE trigger received!");

                 // Check again if device is still valid before proceeding
                 if (current_cdc_dev == NULL) {
                     ESP_LOGW(TAG_NANO,"Device disconnected before read could start.");
                     break; // Exit inner loop, outer loop will handle reconnect
                 }

                 // Prepare the READFIFO command
                 uint8_t fifoCmd[3] = {DFU_CMD_READFIFO, FIFO_ADDR_VALUES, NUM_VALUES & 0xFF};
                 ESP_LOGI(TAG_NANO, "Sending READFIFO command (0x%02X, 0x%02X, 0x%02X) for %d values",
                          fifoCmd[0], fifoCmd[1], fifoCmd[2], NUM_VALUES);

                 // Reset receive state
                 current_rx_count = 0;
                 xSemaphoreTake(fifo_data_ready_sem, 0); // Clear stale signal

                 // Send the command
                 err = cdc_acm_host_data_tx_blocking(current_cdc_dev, fifoCmd, sizeof(fifoCmd), TX_TIMEOUT_MS);

                 if (err != ESP_OK) {
                     ESP_LOGE(TAG_NANO, "Failed to send READFIFO command: %s", esp_err_to_name(err));
                     // Assume disconnection or serious error, break inner loop
                     // handle_usb_event should signal device_disconnected_sem if applicable
                     break;
                 }

                 // Wait for the complete response data
                 ESP_LOGI(TAG_NANO, "Command sent. Waiting for %d bytes of FIFO data...", EXPECTED_RX_BYTES);
                 BaseType_t got_semaphore = xSemaphoreTake(fifo_data_ready_sem, pdMS_TO_TICKS(RX_TIMEOUT_MS));

                 if (got_semaphore == pdTRUE && current_rx_count >= EXPECTED_RX_BYTES) {
                      ESP_LOGI(TAG_NANO, "FIFO data received successfully via USB.");
                      // Process the received data and prepare notification string
                      bool processing_ok = process_fifo_data_and_prepare_notify();

                      // Send notification via BLE if client connected
                      if (current_conn_handle != BLE_HS_CONN_HANDLE_NONE) {
                          ESP_LOGI(TAG_NANO,"Sending BLE Notification: \"%s\"", ble_notify_buffer);
                          struct os_mbuf *om = ble_hs_mbuf_from_flat(ble_notify_buffer, strlen(ble_notify_buffer));
                           if (om) {
                               // Use the global characteristic handle 'gatt_chr_handle'
                               int rc = ble_gatts_notify_custom(current_conn_handle, gatt_chr_handle, om);
                               if (rc != 0) {
                                   ESP_LOGE(TAG_NANO, "BLE notify failed; rc=%d", rc);
                                    // If notify fails (e.g., client disconnected just now), handle might become invalid soon.
                                }
                           } else {
                                ESP_LOGE(TAG_NANO,"Failed to allocate mbuf for BLE notification");
                           }
                      } else {
                           ESP_LOGW(TAG_NANO,"No BLE client connected, cannot send notification.");
                      }
                 } else {
                      ESP_LOGE(TAG_NANO, "TIMEOUT or incomplete data: Failed to receive complete FIFO data within %d ms. Got %d bytes.", RX_TIMEOUT_MS, current_rx_count);
                      // Handle timeout - maybe send error notification? Break inner loop.
                       if (current_conn_handle != BLE_HS_CONN_HANDLE_NONE) {
                            snprintf(ble_notify_buffer, BLE_NOTIFY_BUF_SIZE, "Error: USB Timeout (%d/%d bytes)", current_rx_count, EXPECTED_RX_BYTES);
                            struct os_mbuf *om = ble_hs_mbuf_from_flat(ble_notify_buffer, strlen(ble_notify_buffer));
                            if (om) ble_gatts_notify_custom(current_conn_handle, gatt_chr_handle, om);
                       }
                      break; // Exit inner loop on timeout/incomplete data
                 }
             } // End if(xSemaphoreTake trigger)
         } // --- End of inner communication loop ---

         ESP_LOGI(TAG_NANO, "NanoVNA disconnected or error occurred. Waiting for USB disconnect event to be fully processed...");
         // Wait until the disconnect event is processed by handle_usb_event
         // or if we broke out early, this ensures state is clean before retry.
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
    task_created = xTaskCreate(nanovna_control_task, "nanovna_task", 6144, NULL, NANOVNA_TASK_PRIORITY, NULL); // Increased stack for processing
    assert(task_created == pdTRUE);
    ESP_LOGI(TAG_MAIN, "NanoVNA Control Task Started.");

    ESP_LOGI(TAG_MAIN, "Initialization Complete. System Running.");
    // app_main can exit now, background tasks will run.
}
