# Firebase Android Setup - Quick Reference

## ✅ Completed Steps

1. **Added Firebase dependencies** to `pubspec.yaml`:
   - firebase_core
   - firebase_auth
   - cloud_firestore
   - firebase_storage
   - firebase_realtime_database

2. **Updated Android build files**:
   - Added Google Services plugin to `android/build.gradle.kts`
   - Added Google Services plugin to `android/app/build.gradle.kts`

3. **Created Firebase Service** (`lib/firebase_service.dart`):
   - Authentication methods (Sign up, Sign in, Sign out, Reset password)
   - Firestore methods (Save/Get user profile, transactions, categories)
   - Cloud Storage methods (Upload/Delete files)

4. **Initialized Firebase** in `main.dart`:
   - Added async initialization
   - Firebase will load before app starts

## 📋 Next Steps

### Step 1: Get google-services.json
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project or select existing one
3. Add Android app with package name: `com.example.allowance_budget_dashboard`
4. Download `google-services.json`
5. Place it in: `android/app/google-services.json`

### Step 2: Enable Firebase Services
In Firebase Console, enable:
- ✅ Authentication → Email/Password
- ✅ Cloud Firestore (Test Mode for development)
- ✅ Cloud Storage
- ✅ Realtime Database (optional)

### Step 3: Install Dependencies
```bash
flutter pub get
```

### Step 4: Build & Test on Android
```bash
flutter run
```

## 📚 Using Firebase in Your App

### Authentication
```dart
// Sign up
await FirebaseService.signUp(
  email: 'user@example.com',
  password: 'password123',
);

// Sign in
await FirebaseService.signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Get current user
final user = FirebaseService.currentUser;
```

### Save Data to Firestore
```dart
// Save user profile
await FirebaseService.saveUserProfile(
  userId: userId,
  userData: {
    'name': 'John Doe',
    'email': 'john@example.com',
    'role': 'Parent',
  },
);

// Save transaction
await FirebaseService.saveTransaction(
  userId: userId,
  transactionData: {
    'amount': 50.0,
    'category': 'Groceries',
    'date': DateTime.now(),
  },
);
```

### Read Data from Firestore
```dart
// Get transactions (real-time updates)
FirebaseService.getTransactions(userId).listen((snapshot) {
  final transactions = snapshot.docs;
  // Update UI
});

// Get categories
FirebaseService.getCategories(userId).listen((snapshot) {
  final categories = snapshot.docs;
  // Update UI
});
```

### Upload Profile Image
```dart
final imageUrl = await FirebaseService.uploadProfileImage(
  userId: userId,
  filePath: imagePath,
);
```

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| "google-services not found" | Make sure file is at `android/app/google-services.json` |
| Build fails | Run `flutter clean` then `flutter pub get` |
| FirebaseCore error | Ensure `google-services.json` is present |
| Permission denied | Check Firestore rules → Use Test Mode |

## 📖 Files Created/Modified

- `pubspec.yaml` - Added Firebase packages
- `android/build.gradle.kts` - Added Google Services plugin
- `android/app/build.gradle.kts` - Added Google Services plugin ID
- `lib/firebase_service.dart` - **NEW** Firebase helper class
- `lib/main.dart` - Added Firebase initialization
- `FIREBASE_SETUP_GUIDE.md` - **NEW** Detailed setup guide

## 🚀 What's Next?

1. Download and add `google-services.json`
2. Run `flutter pub get`
3. Test on Android device/emulator
4. Integrate Firebase features into your app (authentication, data storage, etc.)
5. Update Firestore rules for production security
