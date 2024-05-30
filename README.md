# KeySense App

KeySense App is a simple Flutter application that allows users to log keyboard inputs along with sensor data from the device's gyroscope, accelerometer, and magnetometer.

## Features

- **Logging Keyboard Inputs**: Users can start and stop logging keyboard inputs.
- **Sensor Data Capture**: The app captures sensor data (gyroscope, accelerometer, magnetometer) before, during, and after each keyboard input.
- **Storage Permission**: Users are prompted to grant storage permission to log data effectively.
- **External Storage**: Data is logged to a text file in external storage (Android) or temporary directory (iOS).

## Usage

1. **Start Logging**: Press the "Start" button to begin logging keyboard inputs and sensor data.
2. **Stop Logging**: Press the "Stop" button to stop logging.
3. **Update Log File**: Press the "Update" button to update the log file with the logged data.

## Permissions

- **Storage Permission**: The app requires storage permission to log data effectively. If permission is not granted, the app will prompt the user to grant it.

## Dependencies

The app utilizes the following dependencies:

- `flutter/material.dart`: Flutter UI framework.
- `path_provider`: Provides platform-specific locations for storing app data.
- `sensors_plus`: Flutter plugin for accessing various sensors on the device.
- `permission_handler`: Plugin for handling permissions in Flutter apps.

## Installation

To install the Key Logger App, follow these steps:

1. Clone the repository: `git clone <repository_url>`
2. Navigate to the project directory: `cd keysense`
3. Run the app on your preferred device: `flutter run`

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvement, please feel free to open an issue or create a pull request.
