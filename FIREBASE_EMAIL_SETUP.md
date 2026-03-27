# Firebase Email Template Configuration

## What Users Will See in Their Email

### Email Subject
```
Firebase - Password Reset Request
```

### Email Button Text
```
Click here to set new password and recover your account
```

### Sample Email Link
The email will contain a link like:
```
https://YOUR_PROJECT.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=ABC123LONG_RANDOM_CODE&apiKey=YOUR_API_KEY&continueUrl=https%3A%2F%2Fyourapp.com
```

## Firebase Email Template Setup

### How to Configure Custom Email Text

1. **Go to Firebase Console**
   - Navigate to: Project Settings → Authentication → Templates

2. **Edit Password Reset Template**
   - Select "Password Reset" email template
   - Customize subject line
   - Customize email body
   - Set CTA button text to:
     ```
     Click here to set new password and recover your account
     ```

3. **Sender Settings**
   - Set "From" to your app name
   - Example: "Allowance Budget Dashboard <noreply@YOUR_PROJECT.firebaseapp.com>"

4. **Email Language Support**
   - Templates can be set per language
   - Default is English

## Password Reset Flow Diagram

```
User clicks "Forgot Password"
          ↓
Enters email address
          ↓
Firebase sends reset email
          ↓
User receives email with link button
          ↓
Two Options:
          ├─→ Click Email Link → Firebase handles
          │   └─→ Redirects to app or web
          │
          └─→ Copy Reset Code from URL
              └─→ Paste in app's code input field
                  └─→ Shows password reset page
                      ↓
                  Enter new password twice
                      ↓
                  Firebase confirms reset
                      ↓
                  Success! Redirect to login
```

## Sample Reset Code Extraction

### Where to Find the Code in Email Link

```
https://YOUR_PROJECT.firebaseapp.com/__/auth/action?
  mode=resetPassword&
  oobCode=THIS_IS_THE_CODE_TO_COPY&
  apiKey=YOUR_API_KEY&
  continueUrl=...
```

The **oobCode** value is what users can copy if the email link doesn't work directly.

## Firebase Email Security

### Automatic Protections
- ✅ Codes expire after 1 hour
- ✅ Single-use only
- ✅ Tied to specific user account
- ✅ Rate-limited to prevent abuse
- ✅ HTTPS-only links
- ✅ No passwords transmitted in email

### What Firebase Checks
1. Email exists in your project
2. Account hasn't been deleted
3. Code is still valid
4. Code hasn't been used already
5. Password meets requirements

## Customizing Your Email Template

### Sample Custom Template HTML

```html
<p>Hello {{email}},</p>

<p>We received a request to reset your password. 
Click the button below to set a new password for your Allowance Budget Dashboard account.</p>

<p>
  <a href="{{link}}" style="background-color: #18634B; 
     color: white; padding: 12px 24px; 
     text-decoration: none; border-radius: 6px;">
    Click here to set new password and recover your account
  </a>
</p>

<p>This link expires in 1 hour for security.</p>

<p>If you didn't request this, you can safely ignore this email.</p>

<p>Questions? Contact support@yourapp.com</p>
```

### Available Variables
- `{{email}}` - User's email address
- `{{link}}` - Full password reset link
- `{{projectName}}` - Your Firebase project name

## Testing the Email Template

### Test Steps
1. Go to Firebase Console → Authentication → Templates
2. Click "Send Preview Email"
3. Enter your test email address
4. Check your inbox (may take 1-2 minutes)
5. Verify layout, button text, and links work

### What to Look For
- ✓ Email arrives in inbox (not spam)
- ✓ Button is clickable and styled well
- ✓ Link contains the oobCode
- ✓ Message is clear and professional
- ✓ Works on mobile and desktop

## Troubleshooting Email Issues

### Issue: Users Not Receiving Password Reset Email
**Solutions:**
1. Check spam/junk folder
2. Verify authorized domain in Firebase Console
3. Check email address has Firebase account
4. Wait 2-3 minutes for delivery
5. Check Firebase Auth→Logs for errors

### Issue: Link Doesn't Work
**Solutions:**
1. Code may have expired (1 hour limit)
2. User may have already used the code
3. Deep link configuration may be needed
4. Fallback: Use manual code input option

### Issue: Email Template Shows Bracketed Variables
**Example:** "Hello {{email}} instead of actual email"

**Solution:**
- Save the template first
- Check Firebase Console shows variables replaced
- Preview email should show real values

## Email Deliverability Best Practices

1. **Set Reply-To Address**
   - Use: support@yourdomain.com
   - Helps users respond if needed

2. **Add Branding**
   - Your app logo
   - Company colors (use your green #18634B)
   - Professional footer

3. **Include Support Info**
   - Contact email or help link
   - FAQs for common issues

4. **Mobile Optimization**
   - Test on phone display
   - Make button large enough to tap
   - Use responsive HTML

5. **Security Messaging**
   - "If you didn't request this, ignore it"
   - Code expires in X hours
   - Link is single-use only

## Firebase Limits & Quotas

### Email Sending
- ✓ Unlimited password reset emails
- No daily quota
- Rate-limited per user (not per email)

### Code Validity
- Codes expire: 1 hour
- Can generate multiple codes
- Only needs to verify one

### Security Enforced
- Codes are single-use
- Codes are random (256-bit)
- No code reuse across users
- Server-side validation only

## Additional Features Available

### Optional: Link to App
- Configure custom domain
- Users click email link → App opens
- App shows password reset form

### Optional: Branding
- Custom email header/footer
- Company logo
- Custom colors and fonts

### Future: Phone Verification
- Add SMS option for code
- Phone-based password recovery
- Backup authentication method

---

**Firebase Auth Documentation:**
https://firebase.google.com/docs/auth/custom-email-handler
