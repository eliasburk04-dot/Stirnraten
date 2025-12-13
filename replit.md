# Lügner - The Liar Game

A multiplayer social deception game built with Flutter and Firebase.

## Overview

This is a party game where:
- All players receive the same question... except one!
- The "Liar" gets a different question but must blend in with their answer
- After everyone answers, players vote on who they think had a different question

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── data/
│   └── questions.dart        # Questions database
├── models/
│   ├── models.dart           # Exports all models
│   ├── player.dart           # Player model
│   ├── room.dart             # Room model
│   └── game_state.dart       # Game state enum
├── services/
│   └── game_service.dart     # Firebase & game logic
├── screens/
│   ├── screens.dart          # Exports all screens
│   ├── home_screen.dart      # Create/Join room (redesigned)
│   ├── join_room_screen.dart # Enter room code (redesigned)
│   ├── lobby_screen.dart     # Wait for players (redesigned)
│   └── game_screen.dart      # All game phases (redesigned)
├── utils/
│   ├── constants.dart        # App constants
│   └── theme.dart            # App theme with gradients & dark mode
└── widgets/
    └── animated_widgets.dart # Reusable animated widgets
```

## Firebase Configuration

The app requires Firebase Realtime Database. To configure:

1. Create a Firebase project at https://console.firebase.google.com/
2. Enable Realtime Database
3. Update `lib/firebase_options.dart` with your Firebase configuration values:
   - apiKey
   - appId
   - messagingSenderId
   - projectId
   - authDomain
   - databaseURL
   - storageBucket

## Development

The app runs on Flutter web at port 5000.

### Commands

- `flutter pub get` - Install dependencies
- `flutter run -d web-server --web-port=5000 --web-hostname=0.0.0.0` - Run web server

## Dependencies

| Package | Purpose |
|---------|---------|
| firebase_core | Firebase initialization |
| firebase_database | Realtime Database for multiplayer |
| qr_flutter | QR code generation |
| provider | State management |
| uuid | Unique ID generation |
| google_fonts | Custom typography |

## Notes

- QR code scanning was removed for web compatibility
- The app requires valid Firebase credentials to function properly
