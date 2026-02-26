
#!/bin/bash

log() {
    echo "[UNOQ-SETUP] $1"
}

# Load environment variables from .env
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
    log "UNOQ_WIFI_SSID and UNOQ_WIFI_PASSWORD environment variables must be set."
    exit 1
fi

log "Current user: $(whoami)"

log "Updating PATH..."
export PATH=$PATH:/usr/bin:/bin:/usr/local/bin

# log "Enabling network mode for ssh..."
# arduino-app-cli system network-mode enable
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

log "Setting DNS to Google DNS (updates weren't working without this)..."
CON_NAME=$(nmcli -t -f NAME connection show --active | head -n 1)
nmcli connection modify "$CON_NAME" ipv4.dns "8.8.8.8"
nmcli connection up "$CON_NAME"

log "Testing DNS resolution..."
nslookup downloads.arduino.cc || log "DNS resolution failed, please check network settings."

log "Installing app brick (setting permissions for models)..."
chmod +x home/arduino/ArduinoApps/example-arduino-app-lab-object-detection-using-flask/models/rubber-ducky-linux-aarch64.eim 
chmod +x home/arduino/ArduinoApps/example-arduino-app-lab-object-detection-using-flask/models/rubber-ducky-fomo-linux-aarch64.eim


log "Running arduino-app-cli system update..."
arduino-app-cli system update --yes


