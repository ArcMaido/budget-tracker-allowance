# Firebase Setup Guide for Android

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"**
3. Enter project name: `allowance-budget-tracker`
4. Click **"Continue"**
5. Enable Google Analytics (optional) → Click **"Create project"**
6. Wait for project creation to complete

## Step 2: Register Android App

1. In Firebase Console, click the **Android icon** to add Android app
2. Fill in the registration form:
   - **Android package name**: `com.example.allowance_budget_dashboard`
   - **App nickname** (optional): `Allowance Budget Dashboard`
   - Click **"Register app"**

## Step 3: Download google-services.json

1. After registration, click **"Download google-services.json"**
2. Move the downloaded file to: `android/app/google-services.json`
3. This file contains your Firebase configuration

## Step 4: Enable Firebase Services

In Firebase Console, go to **Build** section:

### Authentication
1. Click **"Authentication"**
2. Click **"Get started"**
3. Enable **"Email/Password"** provider
4. Save

### Cloud Firestore
1. Click **"Cloud Firestore"**
2. Click **"Create database"**
3. Select **"Start in test mode"** (for development)
4. Choose region closest to you
5. Click **"Create"**

### Cloud Storage
1. Click **"Storage"**
2. Click **"Get started"**
3. Use your project's default bucket
4. Click **"Done"**

### Realtime Database
1. Click **"Realtime Database"**
2. Click **"Create database"**
3. Select **"Start in test mode"**
4. Choose region → Click **"Enable"**

## Step 5: Install Dependencies

Run in terminal:
```bash
flutter pub get
```

## Step 6: Build and Test

Run the app on an Android device/emulator:
```bash
flutter run
```

## Next Steps

- Check `lib/firebase_service.dart` for Firebase helper class
- Update `main.dart` to initialize Firebase on app startup
- Implement authentication and database operations

## Troubleshooting

**Build Error: "google-services not found"**
- Make sure `google-services.json` is in `android/app/` directory
- Run `flutter clean` then `flutter pub get` again

**Error: "FirebaseCore not initialized"**
- Ensure Firebase is initialized in main.dart before using other services

**Gradle sync fails**
- Check Android Studio → Tools → SDK Manager → Install required SDKs
- Ensure Gradle version compatibility
