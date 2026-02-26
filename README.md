# UNO-Q Updater Quick Start

This package contains scripts and configuration for setting up and updating your UNO-Q device.

## Included Files
- `.env`: Environment variables for device setup (hostname, username, password, WiFi credentials).
- `uno-q-update.sh`: Script to push files and run setup on the UNO-Q device via ADB.
- `unoq-setup.sh`: Script executed on the device to configure network, hostname, user password, and install/update the app brick.

## Usage
1. Edit `.env` to set your desired WiFi credentials.
2. Connect one or more UNO-Q devices via USB.
3. Run `./uno-q-update.sh` from your host machine.

The updater now detects all connected devices and runs updates on them in parallel on the host side.

## Notes
- The scripts require ADB and bash.
- `uno-q-update.sh` executes per-device updates concurrently and prints a success/failure summary.
- Hostname is set using `arduino-app-cli system set-name`.
- Username and password are set using `passwd`.
- WiFi credentials are required for network setup.

## Sharing
To share, distribute the provided zip file containing `.env`, `uno-q-update.sh`, and `unoq-setup.sh`.
