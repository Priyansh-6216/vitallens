# VitalLens Mobile

A Flutter mobile application for heart rate monitoring and HRV analysis.

## Getting Started

This project is a Flutter application for monitoring heart rate and heart rate variability (HRV) using Bluetooth Low Energy (BLE) devices.

### Prerequisites

- Flutter SDK (compatible with your platform)
- Android Studio / Xcode (for mobile development)
- A BLE heart rate monitor (for testing)

### Installation

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Connect your device or start an emulator
5. Run `flutter run` to launch the application

### Project Structure

- `lib/` - Contains Dart code for the application
- `android/` - Android-specific project files
- `ios/` - iOS-specific project files
- `pubspec.yaml` - Flutter project configuration and dependencies

### Features

- BLE device scanning and connection
- Real-time heart rate monitoring
- Heart Rate Variability (HRV) analysis (SDNN, RMSSD, pNN50)
- Local data storage using SQLite (via sqflite)
- Data export to CSV and JSON formats

### Dependencies

- `flutter_blue_plus`: For BLE communication
- `sqflite`: For local SQLite database
- `path`: For file system path handling
- `provider`: For state management

### Configuration

Update the `android/app/build.gradle` and `ios/Runner/Info.plist` files as needed for your specific deployment requirements.

### Testing

To run tests:
```bash
flutter test
```

### Building for Release

Android:
```bash
flutter build apk --release
```

iOS:
```bash
flutter build ios --release
```

## License

This project is open source and available under the MIT License.
