const crypto = require('crypto');
const admin = require('firebase-admin');
const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

admin.initializeApp();

const db = admin.firestore();

const OTP_TTL_MINUTES = 10;
const TOKEN_TTL_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 5;

function hash(input) {
  const secret = process.env.OTP_SECRET || 'change-me-in-prod';
  return crypto.createHash('sha256').update(`${input}|${secret}`).digest('hex');
}

function randomDigits(length) {
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += Math.floor(Math.random() * 10).toString();
  }
  return out;
}

function randomToken() {
  return crypto.randomBytes(32).toString('hex');
}

function emailKey(email) {
  return hash(email.trim().toLowerCase());
}

function getTransporter() {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'SMTP credentials are not configured on Cloud Functions.'
    );
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
}

exports.sendPasswordResetOtp = functions.https.onCall(async (request) => {
  const email = (request.data?.email || '').toString().trim().toLowerCase();
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required.');
  }

  const user = await admin.auth().getUserByEmail(email).catch(() => null);
  if (!user) {
    throw new functions.https.HttpsError('not-found', 'Email account does not exist.');
  }

  const otp = randomDigits(6);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + OTP_TTL_MINUTES * 60 * 1000);
  const key = emailKey(email);

  await db.collection('password_reset_otps').doc(key).set({
    uid: user.uid,
    email,
    otpHash: hash(otp),
    attempts: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  const transporter = getTransporter();
  await transporter.sendMail({
    from,
    to: email,
    subject: 'Your password reset code',
    text: `Your verification code is: ${otp}\nThis code expires in ${OTP_TTL_MINUTES} minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2>Password Reset Code</h2>
        <p>Your verification code is:</p>
        <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px;">${otp}</p>
        <p>This code expires in ${OTP_TTL_MINUTES} minutes.</p>
      </div>
    `,
  });

  return { success: true };
});

exports.checkAccountExistsByEmail = functions.https.onCall(async (request) => {
  const email = (request.data?.email || '').toString().trim().toLowerCase();
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required.');
  }

  const authUser = await admin.auth().getUserByEmail(email).catch(() => null);
  if (authUser) {
    return { exists: true };
  }

  const byLower = await db
    .collection('users')
    .where('emailLower', '==', email)
    .limit(1)
    .get();
  if (!byLower.empty) {
    return { exists: true };
  }

  const byEmail = await db
    .collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();
  if (!byEmail.empty) {
    return { exists: true };
  }

  return { exists: false };
});

exports.verifyPasswordResetOtp = functions.https.onCall(async (request) => {
  const email = (request.data?.email || '').toString().trim().toLowerCase();
  const otp = (request.data?.otp || '').toString().trim();

  if (!email || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and OTP are required.');
  }

  const key = emailKey(email);
  const otpRef = db.collection('password_reset_otps').doc(key);
  const otpSnap = await otpRef.get();
  if (!otpSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Invalid or expired code.');
  }

  const data = otpSnap.data();
  const expiresAt = data.expiresAt?.toDate ? data.expiresAt.toDate() : null;
  const attempts = Number(data.attempts || 0);

  if (!expiresAt || expiresAt.getTime() < Date.now()) {
    await otpRef.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'Code expired.');
  }

  if (attempts >= MAX_OTP_ATTEMPTS) {
    await otpRef.delete();
    throw new functions.https.HttpsError('permission-denied', 'Too many attempts. Request a new code.');
  }

  if (hash(otp) !== data.otpHash) {
    await otpRef.update({ attempts: attempts + 1 });
    throw new functions.https.HttpsError('invalid-argument', 'Invalid code.');
  }

  const resetToken = randomToken();
  const resetTokenHash = hash(resetToken);
  const tokenExpiry = new Date(Date.now() + TOKEN_TTL_MINUTES * 60 * 1000);

  await db.collection('password_reset_tokens').doc(resetTokenHash).set({
    uid: data.uid,
    email,
    used: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(tokenExpiry),
  });

  // OTP is single-use.
  await otpRef.delete();

  return { resetToken };
});

exports.confirmPasswordResetWithOtp = functions.https.onCall(async (request) => {
  const resetToken = (request.data?.resetToken || '').toString().trim();
  const newPassword = (request.data?.newPassword || '').toString();

  if (!resetToken || !newPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'Reset token and new password are required.');
  }

  if (newPassword.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters.');
  }

  const tokenHash = hash(resetToken);
  const tokenRef = db.collection('password_reset_tokens').doc(tokenHash);
  const tokenSnap = await tokenRef.get();

  if (!tokenSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Reset session not found or expired.');
  }

  const data = tokenSnap.data();
  const expiresAt = data.expiresAt?.toDate ? data.expiresAt.toDate() : null;

  if (data.used === true || !expiresAt || expiresAt.getTime() < Date.now()) {
    await tokenRef.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'Reset session expired.');
  }

  await admin.auth().updateUser(data.uid, { password: newPassword });
  await tokenRef.update({ used: true, usedAt: admin.firestore.FieldValue.serverTimestamp() });

  return { success: true };
});
