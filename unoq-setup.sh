#!/bin/bash

# ── Timer & error tracking ────────────────────────────────────────────────────
START_TIME=$(date +%s)
ERRORS=()

log() {
    echo "[UNOQ-SETUP] $1"
}

add_error() {
    ERRORS+=("$1")
    log "ERROR: $1"
}

print_summary() {
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINS=$((ELAPSED / 60))
    SECS=$((ELAPSED % 60))
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║              UNOQ-SETUP SUMMARY                  ║"
    echo "╠══════════════════════════════════════════════════╣"
    printf "║  Total time : %02dm %02ds%-32s║\n" "$MINS" "$SECS" ""
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "║  Status     : SUCCESS                            ║"
    else
        printf "║  Status     : FAILED (%d error(s))%-17s║\n" "${#ERRORS[@]}" ""
        echo "╠══════════════════════════════════════════════════╣"
        echo "║  Errors:                                         ║"
        for ERR in "${ERRORS[@]}"; do
            printf "║    • %-44s║\n" "$ERR"
        done
    fi
    echo "╚══════════════════════════════════════════════════╝"
}

# Always print summary on exit (normal or error)
trap print_summary EXIT

# ── Load environment variables ────────────────────────────────────────────────
if [ -f /home/arduino/.env ]; then
    log "Loading /home/arduino/.env file..."
    set -a
    . /home/arduino/.env
    set +a
    env | grep UNOQ_
else
    log "/home/arduino/.env file not found."
fi

log "Checking WiFi credentials..."
if [ -z "$UNOQ_WIFI_SSID" ] || [ -z "$UNOQ_WIFI_PASSWORD" ]; then
    add_error "UNOQ_WIFI_SSID and UNOQ_WIFI_PASSWORD environment variables must be set."
    exit 1
fi

log "Current user: $(whoami)"

log "Updating PATH..."
export PATH=$PATH:/usr/bin:/bin:/usr/local/bin

# ── WiFi ──────────────────────────────────────────────────────────────────────
log "Checking if WiFi is already connected..."
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d':' -f2)
if [ "$CURRENT_SSID" = "$UNOQ_WIFI_SSID" ]; then
    log "Already connected to WiFi SSID: $UNOQ_WIFI_SSID"
else
    log "Connecting to WiFi..."
    wifi_command="nmcli dev wifi connect $UNOQ_WIFI_SSID password $UNOQ_WIFI_PASSWORD"
    log "WiFi command: $wifi_command"
    eval $wifi_command
fi

# ── DNS ───────────────────────────────────────────────────────────────────────
log "Setting DNS to Google DNS (updates weren't working without this)..."
CON_NAME=$(nmcli -t -f NAME connection show --active | head -n 1)
nmcli connection modify "$CON_NAME" ipv4.dns "8.8.8.8"
nmcli connection up "$CON_NAME"

log "Testing DNS resolution..."
nslookup downloads.arduino.cc || log "DNS resolution failed, please check network settings."

# ── Wait for internet ─────────────────────────────────────────────────────────
log "Waiting for internet connectivity (HTTP check)..."
MAX_WAIT=60
COUNT=0
until curl -s --max-time 5 --head https://downloads.arduino.cc > /dev/null 2>&1; do
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_WAIT" ]; then
        add_error "Internet connectivity timeout after ${MAX_WAIT}s"
        exit 1
    fi
    log "Not reachable yet, retrying... (${COUNT}/${MAX_WAIT})"
    sleep 1
done
log "Internet connectivity confirmed."

# ── System update ─────────────────────────────────────────────────────────────
log "Running arduino-app-cli system update..."
if ! arduino-app-cli system update --yes; then
    add_error "arduino-app-cli system update failed"
fi

# ── App brick permissions ─────────────────────────────────────────────────────
log "Installing app brick (setting permissions for models)..."
chmod +x /home/arduino/ArduinoApps/example-arduino-app-lab-object-detection-using-flask/models/rubber-ducky-linux-aarch64.eim \
    || add_error "chmod failed: rubber-ducky-linux-aarch64.eim"
chmod +x /home/arduino/ArduinoApps/example-arduino-app-lab-object-detection-using-flask/models/rubber-ducky-fomo-linux-aarch64.eim \
    || add_error "chmod failed: rubber-ducky-fomo-linux-aarch64.eim"

# ── Arduino CLI properties status file ───────────────────────────────────────
PROPERTIES_TARGET_PATH="/var/lib/arduino-app-cli/properties.msgpack"
PROPERTIES_TEXT=$'\uFFFD\uFFFDsetup-keyboard-name\uFFFD\x04done\uFFFDsetup-board-name\uFFFD\x04done\uFFFDsetup-credentials\uFFFD\x04done'
PROPERTIES_B64=$(printf '%s' "$PROPERTIES_TEXT" | base64 | tr -d '\n')
TEMP_PROPERTIES_PATH="/tmp/properties.msgpack"

log "Writing Arduino app CLI properties state..."
if printf '%s' "$PROPERTIES_B64" | base64 -d > "$PROPERTIES_TARGET_PATH" 2>/dev/null; then
    log "Wrote properties payload directly to $PROPERTIES_TARGET_PATH."
else
    add_error "Failed to write $PROPERTIES_TARGET_PATH (permission denied). Set UNOQ_DEFAULT_PASSWORD or configure passwordless sudo."
    rm -f "$TEMP_PROPERTIES_PATH" || true
fi
