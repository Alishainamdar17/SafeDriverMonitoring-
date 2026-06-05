# 🚗 Safe Driver Monitoring App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
  <img src="https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge"/>
</p>

<p align="center">
  <b>A Flutter-based mobile application that promotes road safety by monitoring driver behavior in real time — detecting drowsiness, overspeeding, and unsafe driving patterns.</b>
</p>

---

## 📋 Table of Contents

- [About the Project](#-about-the-project)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Screenshots](#-screenshots)
- [Getting Started](#-getting-started)
- [Installation](#-installation)
- [How It Works](#-how-it-works)
- [Project Structure](#-project-structure)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

---

## 📌 About the Project

The **Safe Driver Monitoring App** is a cross-platform mobile application built with Flutter that helps reduce road accidents by continuously monitoring driver behavior using device sensors, camera input, and GPS data.

It provides real-time alerts for:
- Driver **drowsiness or fatigue**
- **Overspeeding** beyond defined limits
- **Harsh braking or acceleration**
- **Route deviation** from the planned path

This app is suitable for personal use, fleet management, and enterprise driver safety programs.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🥱 Drowsiness Detection | Detects eye closure and fatigue using camera & ML |
| 🚀 Speed Monitoring | Tracks real-time speed via GPS and alerts on overspeed |
| 📍 Live Location Tracking | Real-time GPS tracking with Google Maps integration |
| 🔔 Instant Alerts | Audio & vibration alerts for unsafe driving events |
| 📊 Trip Reports | Detailed trip history with safety score and stats |
| 🛡️ Emergency SOS | One-tap SOS with location sharing to emergency contacts |
| 🌙 Night Mode | Auto dark theme for low-light driving conditions |
| 📱 Offline Support | Core features work without internet connectivity |

---

## 🛠️ Tech Stack

**Frontend (Mobile App)**
- [Flutter](https://flutter.dev/) — Cross-platform UI framework
- [Dart](https://dart.dev/) — Programming language
- Provider / Riverpod — State management

**Backend & Services**
- [Firebase](https://firebase.google.com/) — Auth, Firestore, Cloud Messaging
- [Google Maps SDK](https://developers.google.com/maps) — Live GPS & maps
- REST APIs — Trip data sync & reporting

**Device Sensors & ML**
- Camera API — Facial & eye detection
- Accelerometer / Gyroscope — Harsh movement detection
- GPS — Speed & location monitoring
- TensorFlow Lite — On-device ML model for drowsiness

---

## 📸 Screenshots

> *(Add your app screenshots here)*

| Home Screen | Live Monitoring | Trip Report | Alert Screen |
|---|---|---|---|
| ![home](screenshots/home.png) | ![monitor](screenshots/monitor.png) | ![report](screenshots/report.png) | ![alert](screenshots/alert.png) |

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or above)
- [Dart SDK](https://dart.dev/get-dart) (comes with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- A physical Android/iOS device or emulator
- [Firebase account](https://firebase.google.com/) for backend setup
- Google Maps API Key

---

## 🔧 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Alishainamdar17/SafeDriverMonitoring-.git
cd SafeDriverMonitoring-/mobile-app/safe_drive_monitor
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

- Go to [Firebase Console](https://console.firebase.google.com/)
- Create a new project
- Add Android/iOS app and download:
  - `google-services.json` → place in `android/app/`
  - `GoogleService-Info.plist` → place in `ios/Runner/`

### 4. Add Google Maps API Key

**Android** — in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

**iOS** — in `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

### 5. Run the App

```bash
flutter run
```

For a specific device:
```bash
flutter run -d <device_id>
```

---

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────┐
│              Safe Driver Monitoring              │
│                                                 │
│  📷 Camera Feed                                 │
│       └──► ML Model (TFLite)                   │
│               └──► Drowsiness Detected?         │
│                       └──► 🔔 Alert Triggered  │
│                                                 │
│  📡 GPS Sensor                                  │
│       └──► Speed Calculation                   │
│               └──► Over Speed Limit?            │
│                       └──► 🔔 Alert Triggered  │
│                                                 │
│  📲 Accelerometer                               │
│       └──► Motion Analysis                     │
│               └──► Harsh Brake/Acceleration?    │
│                       └──► 🔔 Alert Triggered  │
│                                                 │
│  All events → Firebase → Trip Report Dashboard │
└─────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
safe_drive_monitor/
│
├── lib/
│   ├── main.dart                  # App entry point
│   ├── core/
│   │   ├── constants/             # App-wide constants
│   │   ├── themes/                # Light & dark theme
│   │   └── utils/                 # Helper functions
│   │
│   ├── features/
│   │   ├── auth/                  # Login & registration
│   │   ├── dashboard/             # Home & overview screen
│   │   ├── monitoring/            # Live driver monitoring
│   │   ├── alerts/                # Alert logic & notifications
│   │   ├── trip_history/          # Past trip reports
│   │   └── emergency/             # SOS feature
│   │
│   ├── models/                    # Data models
│   ├── services/                  # Firebase, GPS, Camera services
│   └── widgets/                   # Reusable UI components
│
├── android/                       # Android native config
├── ios/                           # iOS native config
├── assets/                        # Images, icons, ML models
├── test/                          # Unit & widget tests
├── pubspec.yaml                   # Dependencies
└── README.md
```

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m "Add: your feature description"`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

Please make sure your code follows Flutter's best practices and is properly tested.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 📬 Contact

**Alisha Inamdar**
- 💼 [LinkedIn](https://www.linkedin.com/in/alishainamdar17/)
- 📧 inamdaralisha17@gmail.com
- 🐙 [GitHub](https://github.com/Alishainamdar17)

---

<p align="center">
  Made with ❤️ by Alisha Inamdar &nbsp;|&nbsp; Drive Safe, Stay Safe 🚗
</p>
