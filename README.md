# 🎭 Lügner - The Liar Game

A multiplayer social deception game built with Flutter and Firebase. One player receives a different question and must blend in with the group!

## 🎮 Game Overview

**Lügner** (German for "Liar") is a fun party game where:
- All players receive the same question... **except one!**
- The "Liar" gets a different question but must blend in with their answer
- After everyone answers, players vote on who they think had a different question
- Catch the Liar to win, or survive as the Liar!

## 📱 Screenshots

*(Add screenshots here after running the app)*

## ✨ Features

- **Real-time Multiplayer**: 3-10 players can join and play together
- **Room Codes & QR Codes**: Easy room joining with 6-character codes or QR scanning
- **30+ Pre-made Questions**: Categories include money, lifestyle, food, social, work, and entertainment
- **Easy to Add Questions**: Simple question format in a dedicated file
- **Clean Dark UI**: Modern Material Design 3 with beautiful gradients
- **Cross-platform**: Works on Android, iOS, Web, and Desktop

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Download from [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Add Flutter to your PATH

2. **Firebase Project**
   - Create a project at [Firebase Console](https://console.firebase.google.com/)
   - Enable **Realtime Database**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/eliasburk04-dot/Luegner_Spiel.git
   cd Luegner_Spiel
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   Option A: Using FlutterFire CLI (Recommended)
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   
   Option B: Manual Configuration
   - Go to Firebase Console → Project Settings
   - Add your platform (Android/iOS/Web)
   - Copy the configuration values to `lib/firebase_options.dart`

4. **Set up Firebase Realtime Database Rules**
   
   In Firebase Console → Realtime Database → Rules:
   ```json
   {
     "rules": {
       "rooms": {
         "$roomId": {
           ".read": true,
           ".write": true
         }
       }
     }
   }
   ```
   
   ⚠️ For production, use more restrictive rules!

5. **Run the app**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── data/
│   └── questions.dart        # ⭐ Questions database (easy to edit!)
├── models/
│   ├── models.dart           # Exports all models
│   ├── player.dart           # Player model
│   ├── room.dart             # Room model
│   └── game_state.dart       # Game state enum
├── services/
│   └── game_service.dart     # Firebase & game logic
├── screens/
│   ├── screens.dart          # Exports all screens
│   ├── home_screen.dart      # Create/Join room
│   ├── join_room_screen.dart # Enter code or scan QR
│   ├── lobby_screen.dart     # Wait for players
│   └── game_screen.dart      # All game phases
└── utils/
    └── constants.dart        # App constants
```

## ➕ Adding New Questions

Open `lib/data/questions.dart` and add questions to the list:

```dart
const Question(
  id: 31,  // Use next available ID
  question: "How many hours do you spend gaming per week?",
  category: QuestionCategory.entertainment,
),
```

### Question Categories
- `QuestionCategory.money` - Money and spending habits
- `QuestionCategory.lifestyle` - Daily routines and habits
- `QuestionCategory.food` - Food preferences
- `QuestionCategory.social` - Social situations
- `QuestionCategory.work` - Work/school related
- `QuestionCategory.entertainment` - Hobbies and entertainment

### Tips for Good Questions
- Questions should have **numerical answers** (amounts, hours, times, etc.)
- Keep questions casual and fun
- Make sure questions have a wide range of valid answers
- Avoid questions that are too personal or offensive

## 🎯 Game Flow

1. **Home Screen** → Enter name and create/join room
2. **Lobby** → Share room code, wait for players (3-10)
3. **Question Phase** → Everyone reads their question
4. **Answer Phase** → Submit answers privately
5. **Voting Phase** → See all answers, vote for suspected liar
6. **Results** → See voting results
7. **Reveal** → The liar is revealed! Play again or exit

## 🛠️ Development

### Running on Different Platforms

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows
```

### Building for Release

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| firebase_core | Firebase initialization |
| firebase_database | Realtime Database for multiplayer |
| qr_flutter | QR code generation |
| qr_code_scanner | QR code scanning |
| provider | State management |
| uuid | Unique ID generation |
| google_fonts | Custom typography |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- Inspired by classic party games like Spyfall
- Built with Flutter ❤️
- Real-time sync powered by Firebase

---

**Have fun playing Lügner! 🎭**
