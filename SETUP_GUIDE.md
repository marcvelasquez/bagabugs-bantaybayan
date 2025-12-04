# BantayBayan - Setup Guide

A Flutter-based flood monitoring and safety application for the Philippines, featuring real-time weather data, AI-powered safety recommendations, and flood risk assessment.

## 📱 Features

- **Interactive Map** - View flood-prone areas with OpenStreetMap integration
- **Real-time Weather** - Current conditions and 7-day forecasts
- **AI Safety Handbook** - Context-aware safety tips powered by Google Gemini AI
- **Flood Risk Assessment** - ML-based flood probability predictions
- **Situation Reports** - View and submit flood incident reports
- **Offline Support** - Cached tiles and fallback content when offline
- **Dark Mode** - Full dark mode support throughout the app

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

| Software | Version | Download Link |
|----------|---------|---------------|
| Flutter SDK | ^3.10.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ^3.0.0 | Included with Flutter |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| Git | Latest | [git-scm.com](https://git-scm.com/) |

### For Android Development
- Android SDK (API level 21 or higher)
- Android Emulator or physical device

### For iOS Development (macOS only)
- Xcode 14+
- CocoaPods

## 📥 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/marcvelasquez/baga-bugs-bantaybayan-client.git
cd baga-bugs-bantaybayan-client
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Create or edit the `.env` file in the project root:

```env
# Appwrite Backend Configuration
APPWRITE_ENDPOINT=https://sgp.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=baga-bugs
APPWRITE_DATABASE_ID=692fe40600109e7d2fd3
APPWRITE_USERS_COLLECTION_ID=users

# Google Gemini API Key (required for AI-powered safety handbook)
GEMINI_API_KEY=your_gemini_api_key_here
```

### 4. Get Your Gemini API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the key and paste it in your `.env` file

> **Note:** The app will work without a Gemini API key, but will use static safety tips instead of AI-generated ones.

## 🚀 Running the App

### Check Flutter Setup

```bash
flutter doctor
```

Ensure all required components show a green checkmark (✓).

### Run on Android Emulator/Device

```bash
flutter run
```

### Run on iOS Simulator (macOS only)

```bash
flutter run -d ios
```

### Run on Web (for testing)

```bash
flutter run -d chrome
```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── core/                  # Core utilities and theme
│   └── theme/
│       └── colors.dart    # App color definitions
├── models/                # Data models
│   └── api_models.dart    # API response models
├── screens/               # UI screens
│   ├── home_page.dart     # Main navigation
│   ├── map_screen.dart    # Interactive flood map
│   ├── handbook_screen.dart   # Safety handbook
│   ├── situation_screen.dart  # Incident reports
│   ├── checklist_screen.dart  # Emergency checklist
│   └── login_screen.dart      # Authentication
├── services/              # Business logic
│   ├── api_service.dart       # Weather & backend API
│   ├── gemini_service.dart    # Google Gemini AI
│   ├── auth_service.dart      # Appwrite auth
│   ├── flood_risk_service.dart    # Risk calculations
│   └── routing_service.dart       # Map routing
└── widgets/               # Reusable UI components
```

## 🔧 Configuration

### Appwrite Backend

The app uses Appwrite as its backend for:
- User authentication
- Database storage
- Incident report submissions

To use your own Appwrite instance:
1. Create an Appwrite project at [appwrite.io](https://appwrite.io)
2. Create a database with the required collections
3. Update the `.env` file with your credentials

### Weather API

The app uses [Open-Meteo](https://open-meteo.com/) for weather data, which is free and requires no API key.

## 🐛 Troubleshooting

### Common Issues

#### 1. "SocketException: Connection timed out"
- Check your internet connection
- The app will automatically fall back to offline/static content

#### 2. "Gemini API key not found"
- Ensure your `.env` file contains `GEMINI_API_KEY`
- Run `flutter clean && flutter pub get` after editing `.env`

#### 3. Flutter doctor shows issues
```bash
flutter doctor -v  # Verbose output for debugging
```

#### 4. Gradle build fails (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 5. Pod install fails (iOS)
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter run
```

### Debug Mode

Enable verbose logging:
```bash
flutter run --verbose
```

## 📋 Environment Requirements

| Platform | Minimum Version |
|----------|-----------------|
| Android | API 21 (Android 5.0) |
| iOS | iOS 12.0 |
| Web | Modern browsers |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

## 📄 License

This project is developed for educational and research purposes.

## 📞 Support

For questions or issues, please open a GitHub issue or contact the repository maintainer.

---

**BantayBayan** - Keeping communities safe through technology 🇵🇭
