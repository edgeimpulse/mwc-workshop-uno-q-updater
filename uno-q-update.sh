#!/bin/bash

# Load .env file if present
if [ -f .env ]; then
    echo "Loading .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found."
fi

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo "ADB not found. Installing via Homebrew..."
    brew install android-platform-tools
else
    echo "ADB is already installed."
fi

# Check for connected UNO-Q devices
DEVICE=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [ -z "$DEVICE" ]; then
    echo "No UNO-Q device found. Please connect your device."
    exit 1
else
    echo "Connected device: $DEVICE"
fi

# Path to script for UNO-Q
UNOQ_SCRIPT="unoq-setup.sh"

# Clone app brick repo on Mac side if not already present
APP_BRICK_DIR="example-arduino-app-lab-object-detection-using-flask"
if [ ! -d "$APP_BRICK_DIR" ]; then
    echo "Cloning app brick repository on Mac..."
    git clone https://github.com/edgeimpulse/example-arduino-app-lab-object-detection-using-flask.git
else
    echo "App brick repository already present on Mac."
fi

# Push app brick and setup files to UNO-Q
adb -s "$DEVICE" push "$APP_BRICK_DIR" /home/arduino/ArduinoApps/
adb -s "$DEVICE" push $UNOQ_SCRIPT /home/arduino/.$UNOQ_SCRIPT
adb -s "$DEVICE" push .env /home/arduino/.env

# Make setup script executable

adb shell "chmod +x /home/arduino/.$UNOQ_SCRIPT"

# Change password on UNO-Q using environment variable
if [ -z "$UNOQ_DEFAULT_PASSWORD" ]; then
    echo "UNOQ_DEFAULT_PASSWORD is not set. Skipping password change."
else
    echo "Changing password on UNO-Q..."
    # Some devices prompt only for new password (no current password set),
    # others prompt for current password first.
    echo "Attempting password change without current password..."
    CHANGE_PASSWD_CMD_NO_CURRENT="printf '%s\n%s\n' '$UNOQ_DEFAULT_PASSWORD' '$UNOQ_DEFAULT_PASSWORD' | passwd arduino"
    PASSWD_OUTPUT=$(adb -s "$DEVICE" shell "$CHANGE_PASSWD_CMD_NO_CURRENT" 2>&1)

    if echo "$PASSWD_OUTPUT" | grep -Eqi "password updated successfully|all authentication tokens updated successfully|passwd: password changed"; then
        echo "Password changed successfully (no current password required)."
    elif echo "$PASSWD_OUTPUT" | grep -Eqi "current password|authentication failure|password unchanged"; then
        echo "Device appears to require current password. Retrying with current password 'arduino'..."
        CHANGE_PASSWD_CMD_WITH_CURRENT="printf '%s\n%s\n%s\n' 'arduino' '$UNOQ_DEFAULT_PASSWORD' '$UNOQ_DEFAULT_PASSWORD' | passwd arduino"
        PASSWD_OUTPUT=$(adb -s "$DEVICE" shell "$CHANGE_PASSWD_CMD_WITH_CURRENT" 2>&1)

        if echo "$PASSWD_OUTPUT" | grep -Eqi "password updated successfully|all authentication tokens updated successfully|passwd: password changed"; then
            echo "Password changed successfully using current password."
        elif echo "$PASSWD_OUTPUT" | grep -qi "authentication token manipulation error"; then
            echo "Password change failed due to token manipulation error. Password may have already been changed."
        elif echo "$PASSWD_OUTPUT" | grep -qi "password unchanged"; then
            echo "Password was not changed. It may already be set to something other than the flashed default arduino."
        else
            echo "Password change failed. Output: $PASSWD_OUTPUT"
        fi
    elif echo "$PASSWD_OUTPUT" | grep -qi "authentication token manipulation error"; then
        echo "Password change failed due to token manipulation error. Password may have already been changed."
    else
        echo "Password may have already been changed or another error occurred. Output: $PASSWD_OUTPUT"
    fi
fi

# Run script on UNO-Q in interactive mode to see output
adb shell "source /etc/profile; bash /home/arduino/.unoq-setup.sh"

echo "Script completed."
