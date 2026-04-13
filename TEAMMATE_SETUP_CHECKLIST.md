# Teammate Setup Checklist (Flutter + Firebase)

Use this after cloning/pulling the repository.

## 1. Install Required Tools

- Install Flutter SDK from the official site: [flutter.dev/install](https://docs.flutter.dev/get-started/install)
- Install Android Studio from Google: [developer.android.com/studio](https://developer.android.com/studio)
- Install VS Code from Microsoft: [code.visualstudio.com](https://code.visualstudio.com/)
- Install the Flutter extension in VS Code: [marketplace.visualstudio.com/items?itemName=Dart-Code.flutter](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
- Install the Dart extension in VS Code: [marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code)
- On Windows desktop builds, install Visual Studio Build Tools with C++ workload: [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/)
- If Git is not installed yet, use the official download page: [git-scm.com/downloads](https://git-scm.com/downloads)

## 2. Verify Environment

Run:

```bash
flutter --version
flutter doctor
```

Fix any issues reported by `flutter doctor` before continuing.

## 3. Clone / Pull the Project

```bash
git clone <your-repo-url>
cd Budget-Tracker-Allowance
```

If already cloned:

```bash
git pull
```

## 4. Get Flutter Dependencies

```bash
flutter pub get
```

## 5. Firebase Files and Project Setup

Make sure Firebase configuration is available for your local build:

- Android file: `android/app/google-services.json`
- iOS file: `ios/Runner/GoogleService-Info.plist` (if iOS is used)

If missing, follow:

- Firebase official setup docs: [firebase.google.com/docs/flutter/setup](https://firebase.google.com/docs/flutter/setup)
- `FIREBASE_QUICK_START.md`
- `FIREBASE_SETUP_GUIDE.md`
- `FIREBASE_EMAIL_SETUP.md`
- `PASSWORD_RECOVERY_SETUP.md`

## 6. Build + Run

### Android

```bash
flutter run
```

### Web (optional)

```bash
flutter run -d chrome
```

### Windows (optional)

```bash
flutter run -d windows
```

## 7. Verify Core App Flows

- App launches to auth flow.
- Sign up and sign in works.
- Google sign-in works (if configured for your Firebase project).
- Forgot password email flow works.
- Categories and History pages render full-screen correctly.

## 8. Common Fixes

- If dependencies break:

```bash
flutter clean
flutter pub get
```

- If Gradle issues occur (Android), run from `android/`:

```bash
./gradlew clean
```

- If Firebase auth fails, re-check SHA keys and Firebase console settings in setup docs.

## 9. Team Rule of Thumb

Pulling from GitHub does **not** include your installed SDKs/tools.
Each teammate must install Flutter/Android toolchain locally, then run `flutter pub get`.
