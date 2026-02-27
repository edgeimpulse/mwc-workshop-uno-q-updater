# UNO Q Updater Quick Start for MWC Workshops

This package contains scripts and configuration for setting up and updating your UNO Q devices en-masse. Tested on MacOS.

## Included Files
- `.env`: Environment variables for device setup (WiFi credentials and optional password change from default "arduino").
- `UNO Q-update.sh`: Script to push files and run setup on the UNO Q device via ADB.
- `unoq-setup.sh`: Script executed on the device to configure network, hostname, user password, and install/update the app brick.
- `properties.msgpack`: Optional Arduino app CLI properties file that, when present, is pushed to connected devices to stop App Lab asking for device setup.

## Usage
1. Edit `.env` to set your desired WiFi credentials and optional password change from default "arduino".
2. Connect one or more UNO Q devices via USB.
3. Run `./UNO Q-update.sh` from your host machine.

The updater now detects all connected devices and runs updates on them in parallel on the host side. It will also pull down this demo repo and copy it across to your UNO Qs then set the permissions for the models https://github.com/edgeimpulse/example-arduino-app-lab-object-detection-using-flask.

Feel free to adapt these scripts to install other repos/dependencies.

## Notes
- The scripts require ADB and bash.
- `UNO Q-update.sh` executes per-device updates concurrently and prints a success/failure summary.
- If `properties.msgpack` exists in the updater folder, it is pushed to `/var/lib/arduino-app-cli/properties.msgpack` on each connected device.
- WiFi credentials are required for network setup.

## Sharing
To share, distribute the provided zip file containing `.env`, `UNO Q-update.sh`, and `unoq-setup.sh`.
