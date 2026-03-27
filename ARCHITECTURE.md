# Password Recovery - Architecture & Code Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LoginPage                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ "Forgot Password?" button                            │  │
│  └────────────────────┬─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│               ForgotPasswordPage                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Step 1: Enter Email Address                          │  │
│  │ Step 2: Click "Send Reset Link"                      │  │
│  │ Step 3: Check Email (or enter code manually)         │  │
│  └────────────────────┬─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        ↓
              ┌─────────┴─────────┐
              ↓                   ↓
    ┌──────────────────┐   ┌──────────────────┐
    │  Email Link      │   │  Manual Code     │
    │  Button Click    │   │  Entry           │
    └──────┬───────────┘   └────────┬─────────┘
           ↓                        ↓
    Firebase Handling         Code Verification
           ↓                        ↓
    Browser/Deep Link         (Validates code)
           ↓                        ↓
           └────────┬───────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│             PasswordResetPage                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Enter New Password                                   │  │
│  │ Confirm Password                                     │  │
│  │ Click "Set New Password & Recover Account"          │  │
│  └────────────────────┬─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        ↓
              ┌─────────────────────┐
              │Firebase confirms:   │
              │confirmPasswordReset │
              │(code, newPassword)  │
              └──────────┬──────────┘
                        ↓
              ┌─────────────────────┐
              │  Success Alert      │
              │  Redirect to Login  │
              └─────────────────────┘
```

## Code Flow - Forgot Password → Reset

### 1. User Requests Reset (ForgotPasswordPage)

```dart
// User Action: Clicks "Send Reset Link"
Future<void> _sendResetLink() async {
  final email = _emailController.text.trim();
  
  // Calls AuthService
  await AuthService.resetPassword(email: email);
  
  // Email sent by Firebase
  // User sees success message
  setState(() => _linkSent = true);
}
```

### 2. Firebase Sends Email

```
Firebase Email Service:
├─ Sends to: user@example.com
├─ Subject: "Firebase - Password Reset Request"
├─ Button: "Click here to set new password and recover your account"
├─ Link: https://project.firebaseapp.com/__/auth/action?
│          mode=resetPassword&
│          oobCode=RESET_CODE_HERE&
│          apiKey=...&
│          continueUrl=...
└─ Expires: 1 hour after send
```

### 3. User Opens Password Reset Page

#### Path A: Email Link Click
```
Browser/App → Email Link Click
           ↓
Firebase handles action=resetPassword
           ↓
Opens PasswordResetPage with resetCode parameter
```

#### Path B: Manual Code Entry (Fallback)
```dart
// User Action: Clicks "Already have a code?"
Future<void> _verifyAndNavigateToReset() async {
  final code = _resetCodeController.text.trim();
  
  // Verify code is valid
  await AuthService.verifyPasswordResetCode(code: code);
  
  // Navigate to password reset page
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => PasswordResetPage(
        resetCode: code,
        isDarkMode: widget.isDarkMode,
        onToggleDarkMode: widget.onToggleDarkMode,
      ),
    ),
  );
}
```

### 4. User Sets New Password (PasswordResetPage)

```dart
Future<void> _resetPassword() async {
  // Validation
  final newPass = _newPasswordController.text;
  final confirmPass = _confirmPasswordController.text;
  
  if (newPass != confirmPass) {
    setState(() => _errorMessage = 'Passwords do not match');
    return;
  }
  
  // Call Firebase
  await AuthService.confirmPasswordResetWithCode(
    code: widget.resetCode,
    newPassword: newPass,
  );
  
  // Show success & redirect
  await _showAlert(
    title: 'Password Reset Successful',
    message: 'Sign in with your new password.',
    success: true,
  );
  
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => LoginPage(...)),
    (route) => false,
  );
}
```

## Auth Service Methods

### Method 1: Send Reset Email
```dart
// lib/auth_service.dart
static Future<void> resetPassword({required String email}) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
    // Email with reset link is sent to user
  } catch (e) {
    print('Password reset error: $e');
    rethrow;
  }
}
```

### Method 2: Verify Code
```dart
// Validates the reset code hasn't expired or been used
static Future<void> verifyPasswordResetCode({required String code}) async {
  try {
    await _auth.checkActionCode(code);
    // Code is valid, can proceed to reset
  } catch (e) {
    print('Reset code verification error: $e');
    rethrow;
  }
}
```

### Method 3: Confirm Reset
```dart
// Actually sets the new password
static Future<void> confirmPasswordResetWithCode({
  required String code,
  required String newPassword,
}) async {
  try {
    await _auth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
    // Password successfully reset
  } catch (e) {
    print('Confirm password reset error: $e');
    rethrow;
  }
}
```

## Data Flow

### State Management

#### ForgotPasswordPage State
```dart
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late TextEditingController _emailController;
  late TextEditingController _resetCodeController;
  
  bool _isSendingLink = false;      // Loading state
  bool _linkSent = false;            // Email sent success
  bool _showResetCodeInput = false;  // Show code input option
  String _sentEmail = '';            // Email that link was sent to
}
```

#### PasswordResetPage State
```dart
class _PasswordResetPageState extends State<PasswordResetPage> {
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  
  bool _showNewPassword = false;      // Password visibility
  bool _showConfirmPassword = false;  // Confirm visibility
  bool _isResetting = false;          // Loading state
  String _errorMessage = '';          // Error display
  bool _resetSuccess = false;         // Success flag
}
```

## Error Handling

### Password Reset Error Cases

```dart
// Error: Invalid code
if (raw.contains('invalid-action-code')) {
  return 'Reset link is invalid or has expired. Request a new one.';
}

// Error: Code expired (1 hour passed)
if (raw.contains('expired-action-code')) {
  return 'This reset link has expired. Please request a new one.';
}

// Error: Weak password
if (raw.contains('weak-password')) {
  return 'Password is too weak. Use a stronger password.';
}

// Error: User not found
if (raw.contains('user-not-found')) {
  return 'User account not found.';
}
```

## Validation Flow

### Password Reset Validation
```
User Input
    ↓
1. Check both fields filled
    ├─ NO → Show "Please fill in all fields"
    └─ YES ↓
2. Check new password length ≥ 6
    ├─ NO → Show "Password must be at least 6 characters"
    └─ YES ↓
3. Check passwords match
    ├─ NO → Show "Passwords do not match"
    └─ YES ↓
4. Send to Firebase
    ├─ Error → Show error message
    └─ Success ↓
5. Show success alert
    ↓
6. Redirect to login
```

## UI Navigation Stack

```
LoginPage
    ↓
ForgotPasswordPage
    ├─ Back button → LoginPage
    ├─ Back button → LoginPage
    └─ Code verified → PasswordResetPage
         ├─ Back button → ForgotPasswordPage
         ├─ Cancel button → LoginPage
         └─ Success → LoginPage (and remove all above)
```

## Firebase Integration Points

```
FirebaseAuth._auth
├─ sendPasswordResetEmail(email) // Send reset email
├─ checkActionCode(code)         // Verify code valid
└─ confirmPasswordReset(code, pw) // Set new password

FlutterError Handling
├─ Invalid/Expired codes
├─ User not found
├─ Weak passwords
└─ Network errors
```

## Testing Checklist

### Unit Testing Points
- [ ] Email validation
- [ ] Password matching logic
- [ ] Error message generation
- [ ] Form validation

### Integration Testing Points
- [ ] Firebase auth methods called correctly
- [ ] Navigation after success
- [ ] Error handling and retry
- [ ] State management correct

### End-to-End Testing
- [ ] Send reset email flow works
- [ ] Email arrives in inbox
- [ ] Email link redirects correctly
- [ ] Manual code input works
- [ ] Password reset succeeds
- [ ] Can login with new password
- [ ] Old password doesn't work

## Performance Considerations

### Code Length
- Password reset methods: ~30 lines each
- UI code: ~300 lines total
- Auth service methods: Already optimized

### Network Calls
1. `sendPasswordResetEmail()` - 1 call
2. `verifyPasswordResetCode()` - 1 call (optional)
3. `confirmPasswordReset()` - 1 call
Total: 2-3 network calls for complete flow

### Loading States
- Show progress indicator while sending
- Disable form during API calls
- Show clear success/error messages

## Security Summary

```
Email Link → Reset Code (256-bit random)
      ↓
   Valid for 1 hour
      ↓
   Single use only
      ↓
   Tied to user account
      ↓
   Confirms new password
      ↓
   Password salted & hashed by Firebase
      ↓
   User logs in with new password
```

---

**Related Files:**
- `lib/pages/password_reset_page.dart` - Password reset UI
- `lib/pages/forgot_password_page.dart` - Email request UI  
- `lib/auth_service.dart` - Firebase auth methods
- `lib/pages/login_page.dart` - Entry point
